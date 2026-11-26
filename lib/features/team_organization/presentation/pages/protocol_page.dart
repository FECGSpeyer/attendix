import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart' show DeepCollectionEquality;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../redesign/presentation/widgets/today/rd_today_common.dart' show RdInfoCard;
import '../../../../core/services/pdf_branding.dart';
import '../../../../core/providers/plan_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../data/repositories/agenda_item_repository.dart';
import '../../../../data/repositories/protocol_repository.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../protocol_pdf.dart';
import '../../team_org_utils.dart';
import '../../tiptap_delta.dart';
import '../../protocol_layout.dart';
import '../widgets/protocol_beta_widgets.dart';
import '../widgets/protocol_editor.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, outcomeColor;
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/services/native/native_file_service.dart';

const _saveDebounce = Duration(milliseconds: 800);
const _avatarColors = [
  Color(0xFF3B7D84), Color(0xFF7B5EA7), Color(0xFFC0703A), Color(0xFF2F7D4F),
  Color(0xFFA6475F), Color(0xFF4A6FA5), Color(0xFF8A7A2F),
];

/// SOL_FIX13: runs [save] for section [id] after the save of the same
/// section that is still running in [inFlight] (one chain per section, so
/// an older document can never be written after a newer one). The returned
/// future completes with false when [save] failed; it never throws.
Future<bool> chainProtocolSectionSave(
  Map<String, Future<bool>> inFlight,
  String id,
  Future<bool> Function() save,
) {
  final previous = inFlight[id] ?? Future<bool>.value(true);
  final next = previous
      .catchError((Object _) => false)
      .then((_) => save())
      .catchError((Object _) => false);
  inFlight[id] = next;
  next.whenComplete(() {
    if (identical(inFlight[id], next)) inFlight.remove(id);
  });
  return next;
}

/// One protocol section = one field of the Ablaufplan.
class _Section {
  _Section({
    required this.id,
    required this.field,
    required this.title,
    required this.name,
    this.topNumber,
    this.start,
    required this.duration,
    this.conductor,
  });
  final String id;
  final PlanField field;
  final String title;
  final String name;
  final int? topNumber;
  final String? start;
  final int duration;
  final String? conductor;
  bool get isTop => fieldAgendaItemId(field) != null;
  String? get agendaItemId => fieldAgendaItemId(field);
}

class _Leftover {
  _Leftover(this.key, this.title, this.doc);
  final String key;
  final String title;
  final Map<String, dynamic> doc;
}

/// Protokoll eines Termins. Leadership writes notes per Ablaufplan point
/// (autosave per section via `save_protocol_section`), sets results, creates
/// tasks and publishes; members read published protocols of their circle.
///
/// The Ionic version uses a Tiptap editor; here flutter_quill is used and the
/// content is converted from/to the stored Tiptap JSON (see tiptap_delta.dart).
class ProtocolPage extends ConsumerStatefulWidget {
  const ProtocolPage({super.key, required this.attendanceId});
  final int attendanceId;

  @override
  ConsumerState<ProtocolPage> createState() => _ProtocolPageState();
}

class _ProtocolPageState extends ConsumerState<ProtocolPage> {
  late final ProtocolRepository _repo;
  // UI_TENANT_HOIST: bound together with _repo in initState so every write
  // of this page stays in the tenant the protocol was opened in.
  late final TaskRepository _taskRepo;
  late final AgendaItemRepository _agendaRepo;
  bool _isLeader = false;
  bool _loading = true;
  bool _loadFailed = false;
  bool _notAvailable = false;

  ProtocolAttendance? _attendance;
  ProtocolType? _type;
  Protocol? _protocol;
  List<TeamTask> _tasks = [];

  Map<String, Map<String, dynamic>> _docs = {};
  Map<String, String> _outcomes = {};
  List<_Section> _sections = [];
  List<_Leftover> _leftovers = [];

  final Map<String, QuillController> _controllers = {};
  final Map<String, StreamSubscription<DocChange>> _subscriptions = {};

  /// Local edits per section; lets a server merge skip sections edited
  /// while it was loading.
  final Map<String, int> _editCount = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _pending = {};

  /// SOL_FIX2: saves currently running, per section (chained so a section's
  /// saves never overlap). Completes with false when the save failed.
  final Map<String, Future<bool>> _inFlight = {};

  /// SOL_FIX13: set in dispose; documents are then read from [_docs].
  bool _disposed = false;

  String? _activeId;

  /// Beta, wide: the right pane shows 'general' (Allgemeine Notizen) or
  /// 'tasks' (all tasks) instead of the active point.
  String? _sidePane;
  int _savingCount = 0;
  DateTime? _lastSavedAt;
  DateTime _lastErrorToast = DateTime(2000);
  Timer? _liveTimer;
  ({String fieldId, int remainingMinutes})? _live;

  // Wide layout (Tagesordnung | Notizen zum Punkt | Allgemeine Notizen)
  final Map<String, FocusNode> _focusNodes = {};
  final FocusNode _pageFocus = FocusNode(debugLabel: 'protocol-page');

  @override
  void initState() {
    super.initState();
    _repo = ref.read(protocolRepositoryWithTenantProvider);
    _taskRepo = ref.read(taskRepositoryWithTenantProvider);
    _agendaRepo = ref.read(agendaItemRepositoryWithTenantProvider);
    _isLeader = ref.read(isTeamLeaderProvider);
    _load();
  }

  FocusNode _focusFor(String id) => _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'protocol-$id'));

  @override
  void dispose() {
    _liveTimer?.cancel();
    // Last chance: send what is still waiting in the debounce.
    // SOL_FIX13: the latest document is captured now (before the
    // controllers are disposed) and saved through the section's save chain,
    // i.e. after a save of the same section that is still running — an
    // older note can never win over the newer one.
    for (final id in _pending.toList()) {
      _timers.remove(id)?.cancel();
      final doc = _currentDoc(id);
      // A save already queued in the chain finds nothing pending (no-op).
      _pending.remove(id);
      if (doc == null) continue;
      _docs[id] = doc;
      final attendanceId = widget.attendanceId;
      unawaited(chainProtocolSectionSave(_inFlight, id, () async {
        await _repo.saveSection(attendanceId, id, doc: doc);
        return true;
      }));
    }
    _disposed = true;
    for (final s in _subscriptions.values) {
      s.cancel();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _pageFocus.dispose();
    super.dispose();
  }

  // ── Loading ────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final types = await ref.read(protocolTypesProvider.future);
      final results = await Future.wait([
        _repo.getAttendance(widget.attendanceId),
        _repo.getProtocolForAttendance(widget.attendanceId),
        _taskRepo.getTasksForAttendance(widget.attendanceId).catchError((_) => <TeamTask>[]),
      ]);
      final attendance = results[0] as ProtocolAttendance?;
      final protocol = results[1] as Protocol?;
      _attendance = attendance;
      _protocol = protocol;
      _tasks = results[2] as List<TeamTask>;
      _type = null;
      for (final t in types) {
        if (t.id == attendance?.typeId) _type = t;
      }
      if (!_isLeader && protocol == null) {
        _notAvailable = true;
        return;
      }
      if (attendance == null) {
        _loadFailed = true;
        return;
      }
      _docs = {
        for (final e in (protocol?.content ?? const <String, dynamic>{}).entries)
          if (e.value is Map) e.key: Map<String, dynamic>.from(e.value as Map),
      };
      _outcomes = {for (final e in (protocol?.outcomes ?? const {}).entries) e.key: e.value.toString()};
      _buildSections();
      await _buildLeftovers();
      _updateLive();
      _activeId = _live?.fieldId ?? (_sections.isNotEmpty ? _sections.first.id : null);
      _startLiveTimer();
    } catch (_) {
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? get _planStart {
    final t = _attendance?.plan?['time']?.toString();
    if (t != null && t.isNotEmpty) return t;
    if (_attendance?.startTime?.isNotEmpty == true) return _attendance!.startTime;
    return _type?.startTime;
  }

  DateTime? get _planStartDateTime {
    final start = _planStart;
    final day = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    if (start == null) return null;
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(start) && !start.contains('T')) {
      if (day == null) return null;
      return parsePlanTime(start, day: day);
    }
    return DateTime.tryParse(start)?.toLocal();
  }

  void _buildSections() {
    final fields = protocolSections(_attendance?.fields);
    final numbers = topNumbers(fields);
    final times = fieldStartTimes(_planStart, fields);
    _sections = [
      for (final f in fields)
        _Section(
          id: fieldId(f),
          field: f,
          title: fieldDisplayName(f, numbers),
          name: fieldName(f),
          topNumber: numbers[fieldId(f)],
          start: times[fieldId(f)],
          duration: fieldMinutes(f),
          conductor: fieldConductor(f),
        ),
    ];
  }

  Future<void> _buildLeftovers() async {
    final known = {..._sections.map((s) => s.id), protocolGeneralSectionId, agendaItemsPlaceholderId};
    final entries = _docs.entries.where((e) => !known.contains(e.key) && !isDocEmpty(e.value)).toList();
    const legacy = '__agenda__';
    final ids = entries.where((e) => e.key.startsWith(legacy)).map((e) => e.key.substring(legacy.length)).toList();
    var items = <AgendaItem>[];
    if (ids.isNotEmpty) {
      try {
        items = await _agendaRepo.getAgendaItemsByIds(ids);
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'protocol_page');
      }
    }
    _leftovers = entries.map((e) {
      String title = l10nWithoutContext.protocolEarlierItem;
      if (e.key.startsWith(legacy)) {
        final id = e.key.substring(legacy.length);
        title = l10nWithoutContext.protocolAgendaItem;
        for (final i in items) {
          if (i.id == id) title = i.title;
        }
      }
      return _Leftover(e.key, title, e.value);
    }).toList();
  }

  // ── Live mode ──────────────────────────────────────────────

  void _updateLive() {
    _live = liveSection(_sections.map((s) => s.field).toList(), _planStartDateTime, DateTime.now());
  }

  void _startLiveTimer() {
    _liveTimer?.cancel();
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    final now = DateTime.now();
    if (!_isLeader || d == null || d.year != now.year || d.month != now.month || d.day != now.day) return;
    _liveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(_updateLive);
    });
  }

  // ── Editors & saving ───────────────────────────────────────

  /// [initialDoc]: content to show instead of `_docs[id]` (read-only
  /// leftovers are cached under `leftover:<key>` but their notes are stored
  /// under the original section key — SOL_FIX12, Ionic `[content]="l.doc"`).
  QuillController _controllerFor(String id, {bool readOnly = false, Map<String, dynamic>? initialDoc}) {
    final existing = _controllers[id];
    if (existing != null) return existing;
    final parts = tiptapToDelta(initialDoc ?? _docs[id]);
    Document document;
    try {
      document = Document.fromJson(parts.ops);
    } catch (_) {
      document = Document();
    }
    final controller = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: readOnly || !_isLeader,
    );
    if (_isLeader && !readOnly) {
      _subscriptions[id] = _listenLocalChanges(id, document);
    }
    _controllers[id] = controller;
    return controller;
  }

  StreamSubscription<DocChange> _listenLocalChanges(String id, Document document) {
    return document.changes.listen((change) {
      if (change.source != ChangeSource.local) return;
      _editCount[id] = (_editCount[id] ?? 0) + 1;
      _queueSave(id);
    });
  }

  /// Shows [doc] (saved by another leader) in the open editor of [id]
  /// without queueing a save.
  void _replaceEditorDoc(String id, QuillController controller, Map<String, dynamic> doc) {
    Document document;
    try {
      document = Document.fromJson(tiptapToDelta(doc).ops);
    } catch (_) {
      return;
    }
    _subscriptions.remove(id)?.cancel();
    controller.document = document;
    if (_isLeader && !controller.readOnly) {
      _subscriptions[id] = _listenLocalChanges(id, document);
    }
  }

  Map<String, dynamic>? _currentDoc(String id) {
    final c = _controllers[id];
    if (c == null || _disposed) return _docs[id];
    return deltaToTiptap(c.document.toDelta().toJson());
  }

  void _queueSave(String id) {
    _pending.add(id);
    _timers[id]?.cancel();
    _timers[id] = Timer(_saveDebounce, () => _flush(id));
  }

  /// Saves section [id] now (after a save of the same section that is still
  /// running). Returns false when the save failed (the section stays pending).
  Future<bool> _flush(String id) {
    _timers.remove(id)?.cancel();
    return chainProtocolSectionSave(_inFlight, id, () => _saveSectionNow(id));
  }

  Future<bool> _saveSectionNow(String id) async {
    if (!_pending.remove(id)) return true;
    final doc = _currentDoc(id);
    if (doc == null) return true;
    if (mounted) {
      setState(() {
        _docs[id] = doc;
        _savingCount++;
      });
    } else {
      _docs[id] = doc;
      _savingCount++;
    }
    try {
      final row = await _repo.saveSection(widget.attendanceId, id, doc: doc);
      _applyRow(row);
      _lastSavedAt = DateTime.now();
      return true;
    } catch (_) {
      _pending.add(id);
      if (mounted && DateTime.now().difference(_lastErrorToast).inSeconds > 10) {
        _lastErrorToast = DateTime.now();
        ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _savingCount--);
      } else {
        _savingCount--;
      }
    }
  }

  /// Saves everything that is still waiting and awaits saves already running
  /// (SOL_FIX2). Returns false when any section could not be saved.
  Future<bool> _flushAll() async {
    if (!_isLeader) return true;
    // Running saves first: a failure puts the section back into _pending,
    // the retry below decides the result.
    await Future.wait(_inFlight.values.toList());
    final ids = {..._pending, ..._inFlight.keys};
    final results = await Future.wait(ids.map(_flush));
    return results.every((ok) => ok);
  }

  /// Takes over meta data of the saved row; local notes and results stay.
  void _applyRow(Protocol? row) {
    if (row == null) return;
    _protocol = (_protocol ?? row).copyWith(
      id: row.id,
      status: row.status,
      publishedAt: row.publishedAt,
      publishedBy: row.publishedBy,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> _setOutcome(String id, String outcome) async {
    final previous = _outcomes[id];
    final next = previous == outcome ? null : outcome;
    setState(() {
      if (next == null) {
        _outcomes.remove(id);
      } else {
        _outcomes[id] = next;
      }
      _savingCount++;
    });
    try {
      final row = await _repo.saveSection(widget.attendanceId, id, outcome: next, clearOutcome: next == null);
      _applyRow(row);
      _lastSavedAt = DateTime.now();
    } catch (_) {
      setState(() {
        if (previous == null) {
          _outcomes.remove(id);
        } else {
          _outcomes[id] = previous;
        }
      });
      if (mounted) ToastHelper.showError(context, context.l10n.protocolOutcomeSaveFailed);
    } finally {
      if (mounted) setState(() => _savingCount--);
    }
  }

  /// Tasks need the protocol id; saving an empty change creates the protocol row.
  Future<String?> _ensureProtocol() async {
    if (_protocol?.id != null) return _protocol!.id;
    final row = await _repo.saveSection(widget.attendanceId, protocolGeneralSectionId);
    _applyRow(row);
    return row?.id;
  }

  // ── Tasks ──────────────────────────────────────────────────

  Map<String, String> get _taskSectionMap {
    final result = <String, String>{};
    final ids = {..._docs.keys, ..._controllers.keys};
    for (final id in ids) {
      if (id.startsWith('leftover:')) continue;
      for (final tid in taskRefIds(_currentDoc(id))) {
        result.putIfAbsent(tid, () => id);
      }
    }
    for (final t in _tasks) {
      if (t.id == null || result.containsKey(t.id) || t.agendaItemId == null) continue;
      for (final s in _sections) {
        if (s.agendaItemId == t.agendaItemId) {
          result[t.id!] = s.id;
          break;
        }
      }
    }
    return result;
  }

  List<TeamTask> _tasksFor(String sectionId, Map<String, String> map) =>
      _tasks.where((t) => t.id != null && map[t.id] == sectionId).toList();

  List<TeamTask> _unassignedTasks(Map<String, String> map) {
    final ids = _sections.map((s) => s.id).toSet();
    return _tasks.where((t) => t.id == null || !ids.contains(map[t.id])).toList();
  }

  Future<void> _createTask(String sectionId) async {
    _Section? section;
    for (final s in _sections) {
      if (s.id == sectionId) section = s;
    }
    String? protocolId;
    try {
      protocolId = await _ensureProtocol();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolCreateFailed);
      return;
    }
    if (!mounted) return;
    final task = await showTaskFormSheet(
      context,
      attendanceId: widget.attendanceId,
      protocolId: protocolId,
      agendaItemId: section?.agendaItemId,
      contextLabel: section?.title ?? context.l10n.protocolGeneralNotes,
    );
    if (task?.id == null || !mounted) return;
    // Put a task reference into the section's notes (at the cursor) so it maps to the section.
    final node = taskRefNode(id: task!.id!, title: task.title, status: task.status);
    insertRefEmbed(_controllerFor(sectionId), taskRefEmbedType, Map<String, dynamic>.from(node['attrs'] as Map));
    setState(() => _tasks = [..._tasks.where((t) => t.id != task.id), task]);
    _pending.add(sectionId);
    await _flush(sectionId);
    try {
      final tasks = await _taskRepo.getTasksForAttendance(widget.attendanceId);
      if (mounted) setState(() => _tasks = tasks);
    } catch (_) {
      // P10_SONGS_ORG: Ionic keeps the local list (the task is already in
      // it – adding it again duplicated the row).
    }
  }

  // ── Spontaneous topic ──────────────────────────────────────

  Future<void> _addSpontaneousTopic() async {
    final defaultDuration = _type?.agendaDefaultDuration ?? 10;
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '$defaultDuration');
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(ctx.l10n.protocolSpontaneous),
        // Ionic alert: message + two placeholder inputs (protocol.page.ts).
        content: AppAlertInputGroup(
          message: Text(ctx.l10n.protocolSpontaneousHint),
          children: [
            AppAlertInput(
              controller: titleCtrl,
              placeholder: ctx.l10n.tasksTitle,
              betaDecoration: InputDecoration(labelText: ctx.l10n.tasksTitle),
              autofocus: true,
            ),
            AppAlertInput(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              placeholder: ctx.l10n.protocolDurationMinutes,
              betaDecoration: InputDecoration(labelText: ctx.l10n.protocolDurationMinutes),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(ctx.l10n.protocolAdd)),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    // Ionic: Math.max(1, parseInt(duration) || defaultDuration) – 0 or an
    // empty field falls back to the type's default.
    final parsed = int.tryParse(durationCtrl.text.trim());
    final duration = (parsed == null || parsed == 0) ? defaultDuration : parsed;
    titleCtrl.dispose();
    durationCtrl.dispose();
    if (ok != true) return;
    if (title.isEmpty) {
      if (mounted) ToastHelper.showWarning(context, context.l10n.agendaEnterTitle);
      return;
    }
    if (!mounted) return;
    // SOL_FIX34: captured before the awaits – the caches are refreshed
    // after a successful write even if the page was closed meanwhile.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      var current = _attendance!;
      // SOL_FIX35: a failed read or a Termin deleted meanwhile aborts
      // before the topic is created, so no unlinked topic is left behind.
      final fresh = await _repo.getAttendance(widget.attendanceId);
      if (fresh == null) {
        throw StateError('attendance ${widget.attendanceId} not found');
      }
      // SOL_FIX33: a plan deleted meanwhile is a conflict – never write
      // the old plan back (`copyWith(plan: null)` keeps it). Checked
      // before the topic is created, so no orphan topic is left behind.
      if (fresh.plan == null && current.plan != null) {
        throw StateError('plan of attendance ${widget.attendanceId} was deleted');
      }
      current = current.copyWith(plan: fresh.plan);
      // SOL_FIX35: the repository bound to this Termin's tenant, never the
      // global notifier – a tenant switch meanwhile must not create the
      // topic in another tenant than the plan it is linked into.
      final item = await _agendaRepo.createAgendaItem(AgendaItem(
        title: title,
        status: 'open',
        priority: 'medium',
        defaultDuration: duration < 1 ? 1 : duration,
      ));
      container.invalidate(agendaItemsProvider);
      // Ionic insertSpontaneousTopic keeps the plan's `end` as it is.
      final plan = current.plan ??
          {'time': _planStart ?? DateFormat('HH:mm').format(DateTime.now()), 'end': current.endTime ?? '', 'fields': []};
      final field = buildAgendaField(item, duration < 1 ? 1 : duration);
      final fields = insertAgendaFields(current.fields, [field]);
      final stored = await _repo.updateAttendancePlan(widget.attendanceId, {...plan, 'fields': fields});
      container.invalidate(upcomingProtocolAttendancesProvider);
      // SOL_FIX33: the planning editor reloads the plan with the new topic.
      container.invalidate(planAttendancesProvider);
      container.invalidate(orgPlansProvider);
      if (!mounted) return;
      setState(() {
        _attendance = _attendance!.copyWith(plan: stored ?? {...plan, 'fields': fields});
        _buildSections();
        _updateLive();
        _activeId = fieldId(field);
        _sidePane = null;
      });
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolPointFailed);
    }
  }

  // ── Display helpers ────────────────────────────────────────

  String get _title => attendanceTitle(_attendance?.typeInfo, _type) == l10nWithoutContext.attendanceEventFallback
      ? l10nWithoutContext.protocolTitle
      : attendanceTitle(_attendance?.typeInfo, _type);

  String get _dateLabel {
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    return d == null ? '' : '${weekdayShort(d)}, ${DateFormat(dateFmt()).format(d)}';
  }

  String get _timeRange {
    final start = _planStartDateTime;
    if (start == null) return '';
    final total = _sections.fold<int>(0, (s, x) => s + x.duration);
    final fmt = DateFormat('HH:mm');
    return total > 0 ? '${fmt.format(start)}–${fmt.format(start.add(Duration(minutes: total)))}' : fmt.format(start);
  }

  bool get _isPublished => _protocol?.status == 'published';

  String get _statusLine {
    final l10n = l10nWithoutContext;
    if (!_isPublished) return l10n.teamOrgDraft;
    final fmt = DateFormat(dateFmt());
    final pub = DateTime.tryParse(_protocol?.publishedAt ?? '')?.toLocal();
    var line = l10n.teamOrgPublishedOn(pub != null ? fmt.format(pub) : '');
    if (isEditedAfterPublish(_protocol)) {
      final upd = DateTime.tryParse(_protocol!.updatedAt!)?.toLocal();
      line = l10n.teamOrgEditedOn(line, upd != null ? fmt.format(upd) : '');
    }
    return line;
  }

  String get _saveLabel {
    final l10n = l10nWithoutContext;
    if (_savingCount > 0) return l10n.protocolSaving;
    if (_lastSavedAt != null) return l10n.protocolAutoSavedAt(DateFormat('HH:mm').format(_lastSavedAt!));
    return _isPublished ? l10n.protocolChangesAutoSaved : l10n.protocolAutoSaved;
  }

  bool _hasNotes(String id) {
    final c = _controllers[id];
    if (c != null && c.document.toPlainText().trim().isNotEmpty) return true;
    return !isDocEmpty(_docs[id]);
  }

  String _sectionMeta(_Section s) =>
      [s.start, if (s.duration > 0) l10nWithoutContext.planningMinShort(s.duration), s.conductor]
          .whereType<String>()
          .where((x) => x.isNotEmpty)
          .join(' · ');

  String _taskLine(TeamTask t) {
    final parts = <String>[];
    if (t.responsiblePerson.fullName.isNotEmpty) parts.add(t.responsiblePerson.fullName);
    final due = DateTime.tryParse(t.dueDate ?? '');
    if (due != null) parts.add(context.l10n.protocolDueShort(DateFormat(dateFmt(DateFmtKind.dayMonth)).format(due)));
    return parts.join(' · ');
  }

  ({List<ProtocolAttendee> present, List<ProtocolAttendee> excused, List<ProtocolAttendee> others}) get _attendees {
    final all = [...?_attendance?.persons]..sort((a, b) => a.name.compareTo(b.name));
    return (
      present: all.where((a) => isPresentStatus(a.status)).toList(),
      excused: all.where((a) => a.status == AttendanceStatus.excused.value).toList(),
      others: all.where((a) => !isPresentStatus(a.status) && a.status != AttendanceStatus.excused.value).toList(),
    );
  }

  // ── PDF ────────────────────────────────────────────────────

  ProtocolPdfData _buildPdfData({PdfBranding? branding}) {
    final map = _taskSectionMap;
    final l10n = l10nWithoutContext;
    final dueFmt = DateFormat(dateFmt());
    String taskText(TeamTask t) {
      final parts = [t.title];
      if (t.responsiblePerson.fullName.isNotEmpty) parts.add(t.responsiblePerson.fullName);
      final due = DateTime.tryParse(t.dueDate ?? '');
      if (due != null) parts.add(l10n.protocolDueShort(dueFmt.format(due)));
      if (t.status == 'completed') parts.add(l10n.protocolFlutterDoneLower);
      return parts.join(' · ');
    }

    final att = _attendees;
    final sections = [
      for (final s in _sections)
        ProtocolPdfSection(
          title: s.title,
          meta: _sectionMeta(s),
          outcome: outcomeLabels[_outcomes[s.id]],
          doc: _currentDoc(s.id),
          tasks: _tasksFor(s.id, map).map(taskText).toList(),
        ),
      for (final l in _leftovers)
        ProtocolPdfSection(title: l10n.protocolMoreNotesTitle(l.title), doc: l.doc, tasks: _tasksFor(l.key, map).map(taskText).toList()),
    ];
    final leftoverKeys = _leftovers.map((l) => l.key).toSet();
    final other = _tasks.where((t) {
      final id = map[t.id];
      return id == null || (!_sections.any((s) => s.id == id) && !leftoverKeys.contains(id));
    }).toList();
    return ProtocolPdfData(
      title: l10n.protocolPdfTitle(_title),
      subtitle: [_dateLabel, if (_timeRange.isNotEmpty) l10n.attendanceTimeOClock(_timeRange)].join(' · '),
      status: _statusLine,
      present: att.present.map((a) => a.name).toList(),
      excused: att.excused.map((a) => a.name).toList(),
      sections: sections,
      generalNotes: _currentDoc(protocolGeneralSectionId),
      otherTasks: other.map(taskText).toList(),
      branding: branding, // P10_SONGS_ORG: Ionic buildTenantBranding
    );
  }

  Future<void> _sharePdf() async {
    try {
      await _flushAll();
      final branding = await resolvePdfBranding(ref);
      final bytes = await createProtocolPdf(_buildPdfData(branding: branding));
      final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
      final name = l10nWithoutContext
          .protocolFileName(_title, d != null ? DateFormat('yyyy-MM-dd').format(d) : '')
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
      await NativeFileService.saveBytes(bytes, '$name.pdf');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolPdfFailed);
    }
  }

  // ── Publish ────────────────────────────────────────────────

  Future<void> _openPublish() async {
    // Taken before the flush: an edit typed while saving (and saved before
    // the row below arrives) must not be overwritten by an older server row.
    final editsBefore = Map<String, int>.of(_editCount);
    // SOL_FIX2: never offer publishing an incompletely saved protocol.
    if (!await _flushAll()) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
      return;
    }
    // Other leaders may have written in other sections meanwhile.
    try {
      final row = await _repo.getProtocolForAttendance(widget.attendanceId);
      if (row != null && mounted) {
        // Ionic mergeServerRow: every section without an unsaved local
        // change takes the server notes, opened editors included. Sections
        // edited while the row loaded keep the newer local text.
        for (final e in row.content.entries) {
          if (_pending.contains(e.key) || _inFlight.containsKey(e.key) || e.value is! Map) continue;
          if ((_editCount[e.key] ?? 0) != (editsBefore[e.key] ?? 0)) continue;
          final doc = Map<String, dynamic>.from(e.value as Map);
          final controller = _controllers[e.key];
          // Compared by content: jsonb returns the keys sorted, a string
          // compare would replace (cursor, undo) nearly every editor.
          if (controller != null && !const DeepCollectionEquality().equals(_docs[e.key], doc)) {
            _replaceEditorDoc(e.key, controller, doc);
          }
          _docs[e.key] = doc;
        }
        _outcomes = {for (final e in row.outcomes.entries) e.key: e.value.toString()};
      }
    } catch (e, st) {
      ErrorReporter.report(e, st, where: 'protocol_page');
    }

    final summary = PublishSummary();
    final att = _attendees;
    summary.taskCount = _tasks.length;
    summary.recipientCount = att.present.length;
    for (final s in _sections) {
      final o = _outcomes[s.id];
      if (o == 'decided') {
        summary.decided.add(s.name);
      } else if (o == 'discussed') {
        summary.discussed.add(s.name);
      } else if (o == 'postponed') {
        summary.postponed.add(s.name);
      } else if (s.isTop) {
        summary.withoutOutcome.add(s.name);
      }
      if (!_hasNotes(s.id)) summary.withoutNotes.add(s.name);
    }
    summary.taskOwners = _tasks
        .map((t) => (t.responsiblePerson?.firstName?.trim().isNotEmpty ?? false)
            ? t.responsiblePerson!.firstName!.trim()
            : (t.responsiblePerson?.lastName?.trim() ?? ''))
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    var closures = <TopicClosure>[];
    final agendaIds = _sections.map((s) => s.agendaItemId).whereType<String>().toList();
    if (agendaIds.isNotEmpty) {
      try {
        final items = await _agendaRepo.getAgendaItemsByIds(agendaIds);
        closures = topicClosureCandidates(
          _sections.map((s) => (id: s.id, name: s.name, agendaItemId: s.agendaItemId)).toList(),
          _outcomes,
          items,
        );
      } catch (e, st) {
        ErrorReporter.report(e, st, where: 'protocol_page');
      }
    }
    if (!mounted) return;
    setState(() {});
    var sendPdf = true;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: Column(
            children: [
              AppBar(
                toolbarHeight: ionModalToolbarHeight(context),
                automaticallyImplyLeading: false,
                leading: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: IonButtonLabel(ctx.l10n.commonCancel)),
                leadingWidth: 100,
                title: Text(ctx.l10n.protocolPublish),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    Text(ctx.l10n.protocolSummary, style: Theme.of(ctx).textTheme.titleSmall),
                    Card(
                      child: Column(children: [
                        if (summary.decided.isNotEmpty)
                          _summaryTile(AppIcons.checkCircle, AppColors.success,
                              ctx.l10n.protocolDecidedCount(summary.decided.length),
                              summary.decided.join(', ')),
                        if (summary.discussed.isNotEmpty)
                          _summaryTile(AppIcons.forumOutlined, AppColors.primary,
                              ctx.l10n.protocolDiscussedCount(summary.discussed.length),
                              summary.discussed.join(', ')),
                        if (summary.postponed.isNotEmpty)
                          _summaryTile(
                              AppIcons.schedule,
                              AppColors.warning,
                              ctx.l10n.protocolPostponedCount(summary.postponed.length),
                              '${summary.postponed.join(', ')}${_type?.suggestPostponed == true ? ctx.l10n.protocolSuggestNext : ''}'),
                        _summaryTile(
                            AppIcons.checkBoxOutlined,
                            AppColors.mediumOf(context),
                            ctx.l10n.protocolTaskCount(summary.taskCount),
                            summary.taskOwners.isNotEmpty ? ctx.l10n.protocolForNames(joinNames(summary.taskOwners)) : null),
                        if (summary.withoutOutcome.isNotEmpty)
                          _summaryTile(AppIcons.helpOutline, AppColors.mediumOf(context),
                              ctx.l10n.protocolWithoutOutcome(summary.withoutOutcome.length), summary.withoutOutcome.join(', ')),
                        if (summary.withoutNotes.isNotEmpty)
                          _summaryTile(AppIcons.errorOutline, AppColors.warning,
                              ctx.l10n.protocolWithoutNotes(summary.withoutNotes.length), summary.withoutNotes.join(', ')),
                      ]),
                    ),
                    if (closures.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      Text(ctx.l10n.protocolCloseTopics, style: Theme.of(ctx).textTheme.titleSmall),
                      Card(
                        child: Column(children: [
                          for (final c in closures)
                            CheckboxListTile(
                              value: c.close,
                              onChanged: (v) => setLocal(() => c.close = v ?? false),
                              title: Text(c.title),
                              subtitle: Text(outcomeLabels[c.outcome] ?? ''),
                            ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(ctx.l10n.protocolVisibility, style: Theme.of(ctx).textTheme.titleSmall),
                    Card(
                      child: Column(children: [
                        _summaryTile(
                          AppIcons.visibilityOutlined,
                          AppColors.mediumOf(context),
                          ctx.l10n.protocolMayRead,
                          (_type?.relevantGroups?.isNotEmpty ?? false)
                              ? ctx.l10n.protocolReadGroups(_type?.name ?? '')
                              : ctx.l10n.protocolReadAll(_type?.name ?? ''),
                        ),
                        _summaryTile(
                          AppIcons.notificationsOutlined,
                          AppColors.mediumOf(context),
                          ctx.l10n.protocolNotified,
                          '${ctx.l10n.protocolRecipients(summary.recipientCount)}${summary.taskOwners.isNotEmpty ? ctx.l10n.protocolTaskOwners(summary.taskOwners.length) : ''}',
                        ),
                        IonSwitchListTile(
                          value: sendPdf,
                          onChanged: (v) => setLocal(() => sendPdf = v),
                          title: Text(ctx.l10n.protocolSendPdf),
                          subtitle: Text(ctx.l10n.protocolViaTelegram),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingS),
                      child: Text(ctx.l10n.protocolEditAfterPublish),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: Icon(AppIcons.send),
                      label: IonButtonLabel(_isPublished ? ctx.l10n.protocolFlutterRepublishNotify : ctx.l10n.protocolFlutterPublishNotify),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: IonButtonLabel(_isPublished ? ctx.l10n.commonCancel : ctx.l10n.protocolFlutterKeepDraft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await _publish(closures, sendPdf);
  }

  Widget _summaryTile(IconData icon, Color color, String title, String? subtitle) => ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
      );

  Future<void> _publish(List<TopicClosure> closures, bool sendPdf) async {
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: AppSpinner()),
    );
    try {
      // SOL_FIX2: abort when a section could not be saved – do not publish
      // or notify the team about an incomplete protocol.
      if (!await _flushAll()) {
        if (mounted) ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
        return;
      }
      final row = await _repo.publish(widget.attendanceId);
      _applyRow(row);

      // Mark the selected topics as done; a failure does not stop the publish.
      var closeFailed = false;
      for (final c in closures.where((c) => c.close)) {
        try {
          await ref.read(agendaItemNotifierProvider.notifier).update(c.agendaItemId, {'status': 'completed'});
        } catch (_) {
          closeFailed = true;
        }
      }
      if (closeFailed && mounted) {
        ToastHelper.showWarning(context, context.l10n.protocolCloseFailed);
      }

      String? pdfUrl;
      String? pdfPath;
      if (sendPdf) {
        try {
          final branding = await resolvePdfBranding(ref);
          final bytes = await createProtocolPdf(_buildPdfData(branding: branding));
          final upload = await _repo.uploadPdf(widget.attendanceId, bytes);
          pdfUrl = upload.url;
          pdfPath = upload.path;
        } catch (_) {
          if (mounted) {
            ToastHelper.showWarning(context, context.l10n.protocolPdfFailedNotify);
          }
        }
      }
      await _repo.notifyTeam({
        'type': 'protocol_published',
        'attendanceId': widget.attendanceId,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
      });
      if (pdfPath != null) {
        final path = pdfPath;
        // The edge function fetches the file right away; remove it afterwards.
        unawaited(Future.delayed(const Duration(seconds: 60), () => _repo.removePdf(path)));
      }
      ref.invalidate(protocolsProvider);
      if (mounted) ToastHelper.showSuccess(context, context.l10n.protocolPublished);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolPublishFailed);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {});
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLeader) ref.watch(agendaItemsProvider); // topics for "/tagesordnung"
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= protocolWideBreakpoint;
      return _buildScaffold(context, wide);
    });
  }

  Widget _buildScaffold(BuildContext context, bool wide) {
    final showFooter = _isLeader && !wide && !_loading && !_loadFailed && !_notAvailable && _attendance != null;
    return _buildBeta(context, wide, showFooter);
  }

  /// Beta: same content, Beta frame (back link, title with date and
  /// status, share as round button, footer with the Beta buttons).
  Widget _buildBeta(BuildContext context, bool wide, bool showFooter) {
    final p = context.rd;
    final l10n = context.l10n;
    final ready = !_loading && !_notAvailable && !_loadFailed && _attendance != null;
    final Widget body;
    if (_loading) {
      body = _betaState(RdInfoCard(text: l10n.redesignTodayLoading, loading: true));
    } else if (_notAvailable) {
      body = _betaState(RdInfoCard(icon: Icons.lock_outline, text: '${l10n.protocolNotPublished}\n${l10n.protocolNotPublishedHint}'));
    } else if (!ready) {
      body = _betaState(RdInfoCard(
        icon: Icons.cloud_off_outlined,
        text: l10n.protocolLoadFailed,
        action: RdOutlineButton(label: l10n.protocolRetry, onPressed: _load),
      ));
    } else {
      body = _isLeader ? (wide ? _buildBetaWide(context) : _buildBetaEditLayout(context)) : _buildReadLayout(context);
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_flushAll());
      },
      child: Scaffold(
        backgroundColor: p.bg,
        bottomNavigationBar: showFooter ? _betaFooter(context) : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: RdBackLink(
                            label: l10n.rdTeamTitle,
                            onTap: () => context.canPop() ? context.pop() : context.go('/settings/team-organization'),
                          ),
                        ),
                        if (ready)
                          RdCircleButton(
                            key: const Key('rd-protocol-share'),
                            icon: Icons.ios_share,
                            label: l10n.protocolSharePdf,
                            onPressed: _sharePdf,
                          ),
                        // Wide: the one main action sits here, always visible.
                        if (ready && wide && _isLeader) ...[
                          const SizedBox(width: 10),
                          RdPrimaryButton(
                            key: const Key('rd-protocol-finish'),
                            label: _isPublished ? l10n.protocolRepublish : l10n.rdTeamFinishMeeting,
                            height: 44,
                            onPressed: _openPublish,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.protocolTitle.toUpperCase(), style: RdType.eyebrow(p.text2)),
                    if (ready) ...[
                      const SizedBox(height: 2),
                      Semantics(header: true, child: Text(_title, style: RdType.title(p))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              [_dateLabel, if (_timeRange.isNotEmpty) l10n.attendanceTimeOClock(_timeRange)].join(' · '),
                              style: RdType.meta(p, size: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RdPill(
                            _isPublished ? l10n.teamOrgPublished : l10n.teamOrgDraft,
                            tone: _isPublished ? RdTone.present : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _betaState(Widget card) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [card]);

  /// Beta footer (phone): save state above the one main action.
  Widget _betaFooter(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    return Material(
      color: p.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_savingCount > 0)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(width: 12, height: 12, child: AppSpinner(strokeWidth: 2)),
                    ),
                  Flexible(
                    child: Text(_saveLabel,
                        style: RdType.meta(p, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: RdPrimaryButton(
                  key: const Key('rd-protocol-finish'),
                  label: _isPublished ? l10n.protocolRepublish : l10n.rdTeamFinishMeeting,
                  onPressed: _openPublish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(ProtocolAttendee a) {
    final f = a.firstName.trim();
    final l = a.lastName.trim();
    final s = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Future<void> _openAttendees() async {
    final att = _attendees;
    final p = context.rd;
    Widget row(ProtocolAttendee a, int i, {Color? color, bool muted = false}) => RdListRow(
          leading: muted ? null : ExcludeSemantics(child: _betaAvatar(a, i, size: 32, color: color)),
          title: a.name,
          subtitle: a.notes?.isNotEmpty == true ? a.notes : null,
          titleColor: muted ? p.text2 : null,
          showChevron: false,
        );
    await showRdSheet<void>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdSheetTitle(ctx.l10n.protocolParticipants),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  RdGroupLabel(ctx.l10n.protocolPresentList(att.present.length)),
                  RdGroupedList(
                    children: [
                      for (var i = 0; i < att.present.length; i++) row(att.present[i], i),
                      if (att.present.isEmpty)
                        RdListRow(title: ctx.l10n.protocolNobodyPresent, titleColor: p.text2, showChevron: false),
                    ],
                  ),
                  if (att.excused.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RdGroupLabel(ctx.l10n.protocolExcusedList(att.excused.length)),
                    RdGroupedList(
                      children: [for (var i = 0; i < att.excused.length; i++) row(att.excused[i], i, color: p.off)],
                    ),
                  ],
                  if (att.others.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RdGroupLabel(ctx.l10n.protocolOthersList(att.others.length)),
                    RdGroupedList(
                      children: [for (var i = 0; i < att.others.length; i++) row(att.others[i], i, muted: true)],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(ctx.l10n.protocolListFromAttendance, style: RdType.meta(p, size: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGeneralNotes() async {
    await showRdSheet<void>(
      context,
      Builder(
        // The keyboard must not cover the notes.
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RdSheetTitle(ctx.l10n.protocolGeneralNotes),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(ctx.l10n.protocolWholeMeeting, style: RdType.meta(ctx.rd, size: 14)),
                    const SizedBox(height: 12),
                    RdCard(
                      padding: EdgeInsets.zero,
                      // The task form opens above the sheet; back in the
                      // sheet the reference and the task are shown and
                      // writing continues.
                      child: StatefulBuilder(
                        builder: (sheetCtx, setSheet) {
                          final tasks = _tasksFor(protocolGeneralSectionId, _taskSectionMap);
                          // The sheet lies above the pages: close it before
                          // a task opens.
                          void openTask(String id) {
                            Navigator.of(ctx).pop();
                            context.push('/settings/tasks/$id');
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _betaEditor(protocolGeneralSectionId, minHeight: 140, onOpenTask: openTask),
                              Divider(height: 1, thickness: 1, color: ctx.rd.line),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tasks.isNotEmpty)
                                      _betaTaskList(tasks, onOpen: (t) {
                                        if (t.id != null) openTask(t.id!);
                                      }),
                                    _betaAddTask(protocolGeneralSectionId, after: () {
                                      if (sheetCtx.mounted) setSheet(() {});
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _flush(protocolGeneralSectionId);
    if (mounted) setState(() {});
  }

  /// Live task statuses for the task chips in the notes.
  Map<String, String> get _taskStatuses => {
        for (final t in _tasks)
          if (t.id != null) t.id!: t.status,
      };

  /// Open topics offered by "/tagesordnung".
  List<AgendaItem> get _openTopics => (ref.read(agendaItemsProvider).valueOrNull ?? const <AgendaItem>[])
      .where((i) => i.status == 'open' && (i.proposalStatus == null || i.proposalStatus == 'accepted'))
      .toList();

  Widget _editor(QuillController controller, {bool editable = true, bool expands = false}) {
    String? sectionId;
    for (final e in _controllers.entries) {
      if (identical(e.value, controller)) sectionId = e.key;
    }
    final canWrite = editable && !controller.readOnly && sectionId != null && !sectionId.startsWith('leftover:');
    return ProtocolEditor(
      key: ValueKey('editor-$sectionId'),
      controller: controller,
      editable: canWrite,
      expands: expands,
      taskStatuses: _taskStatuses,
      agendaItems: canWrite ? _openTopics : const [],
      onCreateTask: canWrite ? () => _createTask(sectionId!) : null,
      onOpenTask: (id) => context.push('/settings/tasks/$id'),
      onOpenTopic: _isLeader ? (id) => context.push('/settings/agenda-items/$id') : null,
    );
  }

  Widget _taskList(List<TeamTask> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final t in list)
          ListTile(
            dense: true,
            leading: Icon(
              t.status == 'completed' ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
              color: t.status == 'completed' ? AppColors.success : AppColors.mediumOf(context),
            ),
            title: Text(
              t.title,
              style: t.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
            ),
            subtitle: _taskLine(t).isNotEmpty ? Text(_taskLine(t)) : null,
            onTap: () => context.push('/settings/tasks/${t.id}'),
          ),
      ],
    );
  }

  String _previewOf(String id) {
    final c = _controllers[id];
    if (c != null) {
      final text = c.document.toPlainText().replaceAll(RegExp(r'\s+'), ' ').trim();
      return text.length > 140 ? '${text.substring(0, 139)}…' : text;
    }
    return docToPlainText(_docs[id], maxLength: 140);
  }

  List<Widget> _leftoverWidgets() {
    if (_leftovers.isEmpty) return const [];
    return [
      const SizedBox(height: AppDimensions.paddingM),
      Text(context.l10n.protocolMoreNotes, style: Theme.of(context).textTheme.titleSmall),
      Text(context.l10n.protocolMoreNotesHint),
      for (final l in _leftovers)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  context.l10n.protocolNotInPlan,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mediumOf(context)),
                ),
                _editor(_controllerFor('leftover:${l.key}', readOnly: true, initialDoc: l.doc), editable: false),
              ],
            ),
          ),
        ),
    ];
  }

  // ── Wide layout (Ionic B4) ─────────────────────────────────

  List<String> get _sectionIds => _sections.map((s) => s.id).toList();

  /// Selects a point (and focuses its editor in the wide layout).
  void _activate(String id, {bool focus = false}) {
    setState(() {
      _activeId = id;
      _sidePane = null;
    });
    if (focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[id]?.requestFocus();
      });
    }
  }

  void _nextSection() {
    final next = nextSectionId(_sectionIds, _activeId);
    if (next != null) _activate(next, focus: true);
  }

  void _previousSection() {
    final prev = previousSectionId(_sectionIds, _activeId);
    if (prev != null) _activate(prev, focus: true);
  }

  // ── Beta: two columns (wide) and phone ─────────────────────

  String _betaKicker(_Section s, {bool withStart = true}) => [
        if (s.topNumber != null) context.l10n.protocolTop(s.topNumber!),
        if (withStart && s.start != null) s.start!,
        if (s.duration > 0) context.l10n.planningMinShort(s.duration),
      ].join(' · ');

  /// Status of a point as a word: the result, else "Notiert" once there
  /// are notes, else nothing.
  Widget? _betaStatusPill(String id) {
    final o = _outcomes[id];
    if (o != null) return RdPill(outcomeLabels[o] ?? o, tone: protocolOutcomeTone(o));
    return _hasNotes(id) ? RdPill(context.l10n.protocolNoted) : null;
  }

  String get _betaAttendeeSummary {
    final att = _attendees;
    final l10n = context.l10n;
    return att.excused.isEmpty
        ? l10n.protocolPresentCount(att.present.length)
        : l10n.rdTeamProtocolAttendeesBoth(att.present.length, att.excused.length);
  }

  String get _betaTaskSummary {
    final l10n = context.l10n;
    if (_tasks.isEmpty) return l10n.rdTeamProtocolTasksNone;
    final open = _tasks.where((t) => t.status != 'completed').length;
    return open > 0 ? l10n.rdTeamProtocolTasksOpen(open) : l10n.rdTeamProtocolTasksDone;
  }

  Widget _betaAvatar(ProtocolAttendee a, int index, {double size = 28, Color? color}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? _avatarColors[(a.personId ?? index) % _avatarColors.length],
          shape: BoxShape.circle,
          border: Border.all(color: context.rd.surface, width: 2),
        ),
        child: Text(
          _initials(a),
          style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );

  /// At most three overlapping initials (the row's text has the numbers).
  Widget? _betaAvatars(List<ProtocolAttendee> present) {
    final shown = present.take(3).toList();
    if (shown.isEmpty) return null;
    return ExcludeSemantics(
      child: SizedBox(
        width: 28 + 18.0 * (shown.length - 1),
        height: 28,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++) Positioned(left: i * 18.0, child: _betaAvatar(shown[i], i)),
          ],
        ),
      ),
    );
  }

  Widget? _betaLiveCard(VoidCallback? onNext) {
    _Section? liveSec;
    for (final s in _sections) {
      if (s.id == _live?.fieldId) liveSec = s;
    }
    if (_live == null || liveSec == null) return null;
    final l10n = context.l10n;
    return ProtocolLiveCard(
      label: l10n.protocolRunning(
          liveSec.topNumber != null ? l10n.protocolTop(liveSec.topNumber!) : liveSec.name, _live!.remainingMinutes),
      nextLabel: onNext != null ? l10n.protocolNextPoint : null,
      onNext: onNext,
    );
  }

  Widget _betaPublishedLine() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(Icons.check_circle, color: context.rd.present, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(_statusLine, style: RdType.meta(context.rd, size: 13))),
        ]),
      );

  Widget _betaEditor(
    String sectionId, {
    bool expands = false,
    bool wide = false,
    double minHeight = 96,
    void Function(String taskId)? onOpenTask,
  }) =>
      ProtocolEditor(
        key: ValueKey('beta-editor-$sectionId'),
        controller: _controllerFor(sectionId),
        focusNode: wide ? _focusFor(sectionId) : null,
        slim: true,
        hint: wide ? context.l10n.rdTeamProtocolSlashHint : null,
        expands: expands,
        minHeight: minHeight,
        onNextPoint: wide ? _nextSection : null,
        onPreviousPoint: wide ? _previousSection : null,
        taskStatuses: _taskStatuses,
        agendaItems: _openTopics,
        onCreateTask: () => _createTask(sectionId),
        onOpenTask: onOpenTask ?? (id) => context.push('/settings/tasks/$id'),
        onOpenTopic: (id) => context.push('/settings/agenda-items/$id'),
      );

  /// Tasks as Beta rows; [labels] adds the point a task belongs to.
  Widget _betaTaskList(List<TeamTask> list, {Map<String, String>? labels, void Function(TeamTask)? onOpen}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in list)
            ProtocolTaskRow(
              title: t.title,
              meta: [if (labels != null) _sectionLabelOfTask(t, labels), _taskLine(t)]
                  .whereType<String>()
                  .where((x) => x.isNotEmpty)
                  .join(' · '),
              done: t.status == 'completed',
              onTap: () => onOpen != null ? onOpen(t) : context.push('/settings/tasks/${t.id}'),
            ),
        ],
      );

  Widget _betaAddTask(String sectionId, {VoidCallback? after}) {
    final p = context.rd;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () async {
            await _createTask(sectionId);
            after?.call();
          },
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 22, color: p.link),
                  const SizedBox(width: 10),
                  Text(context.l10n.tasksTask,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.link)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wide: the writing surface. The notes fill the height; the tasks of the
  /// point and "+ Aufgabe" stay at its lower edge.
  Widget _betaPaneCard(String sectionId, List<TeamTask> tasks) {
    final p = context.rd;
    final radius = BorderRadius.circular(p.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(color: p.surface, borderRadius: radius, boxShadow: p.cardShadow),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _betaEditor(sectionId, expands: true, wide: true)),
            Divider(height: 1, thickness: 1, color: p.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tasks.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 112),
                      child: SingleChildScrollView(child: _betaTaskList(tasks)),
                    ),
                  _betaAddTask(sectionId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wide: a pane whose card fills the height. In a very low window (tablet
  /// with the keyboard open) the pane keeps a minimum height and scrolls.
  Widget _betaFillPane({required List<Widget> head, required Widget card}) {
    final p = context.rd;
    final l10n = context.l10n;
    final hasNext = nextSectionId(_sectionIds, _activeId) != null;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    return LayoutBuilder(builder: (context, constraints) {
      final minHeight = 600 * MediaQuery.textScalerOf(context).scale(1);
      return SingleChildScrollView(
        child: SizedBox(
          height: constraints.maxHeight < minHeight ? minHeight : constraints.maxHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...head,
                Expanded(child: card),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        if (_savingCount > 0)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(width: 12, height: 12, child: AppSpinner(strokeWidth: 2)),
                          ),
                        Expanded(
                          child: Text(_saveLabel,
                              style: RdType.meta(p, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (hasNext)
                          ProtocolNextButton(
                            key: const Key('rd-protocol-next'),
                            label: l10n.protocolNextPoint,
                            shortcut: apple ? '⌘ ↓' : l10n.rdTeamProtocolCtrlDown,
                            onPressed: _nextSection,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _betaPaneTitle(String text) => Semantics(
        header: true,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RdType.cardTitle(context.rd).copyWith(fontSize: 24),
        ),
      );

  Widget _betaPointPane(_Section s, Map<String, String> map) {
    final p = context.rd;
    final kicker = _betaKicker(s);
    return _betaFillPane(
      head: [
        if (kicker.isNotEmpty) Text(kicker.toUpperCase(), style: RdType.eyebrow(p.text2)),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _betaPaneTitle(s.name)),
            if (s.conductor != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    context.l10n.protocolResponsible(s.conductor!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RdType.meta(p, size: 14),
                  ),
                ),
              ),
          ],
        ),
        if (s.isTop) ...[
          const SizedBox(height: 12),
          ProtocolOutcomeChips(value: _outcomes[s.id], onChanged: (o) => _setOutcome(s.id, o)),
        ],
        const SizedBox(height: 12),
      ],
      card: _betaPaneCard(s.id, _tasksFor(s.id, map)),
    );
  }

  Widget _betaGeneralPane(Map<String, String> map) => _betaFillPane(
        head: [
          _betaPaneTitle(context.l10n.protocolGeneralNotes),
          const SizedBox(height: 2),
          Text(context.l10n.protocolWholeMeeting, style: RdType.meta(context.rd, size: 14)),
          const SizedBox(height: 12),
        ],
        card: _betaPaneCard(protocolGeneralSectionId, _tasksFor(protocolGeneralSectionId, map)),
      );

  Widget _betaTasksPane(Map<String, String> map) {
    final l10n = context.l10n;
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        _betaPaneTitle(l10n.teamOrgTabTasks),
        const SizedBox(height: 2),
        Text(l10n.protocolSessionTasks(_tasks.length), style: RdType.meta(context.rd, size: 14)),
        const SizedBox(height: 12),
        RdCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(l10n.protocolNoTasksYet, style: RdType.meta(context.rd, size: 14)),
                )
              else
                _betaTaskList(_tasks, labels: map),
            ],
          ),
        ),
      ],
    );
  }

  Widget _betaLeftoverPane(_Leftover l, Map<String, String> map) {
    final p = context.rd;
    final tasks = _tasksFor(l.key, map);
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Text(context.l10n.protocolMoreNotes.toUpperCase(), style: RdType.eyebrow(p.text2)),
        const SizedBox(height: 2),
        _betaPaneTitle(l.title),
        const SizedBox(height: 2),
        Text(context.l10n.protocolNotInPlan, style: RdType.meta(p, size: 14)),
        const SizedBox(height: 12),
        RdCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _editor(_controllerFor('leftover:${l.key}', readOnly: true, initialDoc: l.doc), editable: false),
              if (tasks.isNotEmpty) _betaTaskList(tasks),
            ],
          ),
        ),
      ],
    );
  }

  /// Wide, left: the Ablaufplan with the status of every point as a word,
  /// below it what belongs to the whole meeting.
  Widget _betaSide(Map<String, String> map) {
    final p = context.rd;
    final l10n = context.l10n;
    final live = _betaLiveCard(nextSectionId(_sectionIds, _activeId) != null ? _nextSection : null);
    final pointSelected = _sidePane == null;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 12, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (_isPublished) _betaPublishedLine(),
        if (live != null) ...[live, const SizedBox(height: 16)],
        RdGroupLabel(l10n.protocolRunSheet),
        RdGroupedList(
          children: [
            for (final s in _sections)
              ProtocolAgendaRow(
                leading: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    s.start ?? '',
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: _live?.fieldId == s.id ? FontWeight.w700 : FontWeight.w400,
                      color: _live?.fieldId == s.id ? p.absent : p.text2,
                    ),
                  ),
                ),
                title: s.name,
                meta: _betaKicker(s, withStart: false),
                status: _betaStatusPill(s.id),
                selected: pointSelected && _activeId == s.id,
                onTap: () => _activate(s.id, focus: true),
              ),
            for (final l in _leftovers)
              ProtocolAgendaRow(
                leading: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.inventory_2_outlined, size: 20, color: p.text2),
                ),
                title: l.title,
                meta: l10n.protocolMoreNotes,
                selected: pointSelected && _activeId == l.key,
                onTap: () => _activate(l.key),
              ),
            ProtocolAgendaRow(
              leading: Align(alignment: Alignment.centerLeft, child: Icon(Icons.add, size: 22, color: p.link)),
              title: l10n.protocolPoint,
              titleColor: p.link,
              onTap: _addSpontaneousTopic,
            ),
          ],
        ),
        const SizedBox(height: 20),
        RdGroupLabel(l10n.rdTeamProtocolAbout),
        RdGroupedList(
          children: [
            RdListRow(
              key: const Key('rd-protocol-general'),
              leading: const RdRowIcon(Icons.notes),
              title: l10n.protocolGeneralNotes,
              subtitle: _hasNotes(protocolGeneralSectionId)
                  ? _betaShortPreview(protocolGeneralSectionId)
                  : l10n.rdTeamProtocolEmpty,
              selected: _sidePane == 'general',
              onTap: () => _openSidePane('general'),
            ),
            RdListRow(
              key: const Key('rd-protocol-tasks'),
              leading: const RdRowIcon(Icons.task_alt),
              title: l10n.teamOrgTabTasks,
              subtitle: _betaTaskSummary,
              selected: _sidePane == 'tasks',
              onTap: () => _openSidePane('tasks'),
            ),
            RdListRow(
              key: const Key('rd-protocol-attendees'),
              leading: const RdRowIcon(Icons.group),
              title: l10n.protocolPresent,
              subtitle: _betaAttendeeSummary,
              trailing: _betaAvatars(_attendees.present),
              onTap: _openAttendees,
            ),
          ],
        ),
      ],
    );
  }

  String _betaShortPreview(String id) {
    final text = _previewOf(id);
    return text.length > 60 ? '${text.substring(0, 59)}…' : text;
  }

  void _openSidePane(String pane) {
    setState(() => _sidePane = pane);
    if (pane == 'general') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[protocolGeneralSectionId]?.requestFocus();
      });
    }
  }

  /// Beta, wide: two columns like the other Beta split views. Left the
  /// overview, right one large writing surface.
  Widget _buildBetaWide(BuildContext context) {
    final map = _taskSectionMap;
    _Section? active;
    for (final s in _sections) {
      if (s.id == _activeId) active = s;
    }
    _Leftover? activeLeftover;
    for (final l in _leftovers) {
      if (l.key == _activeId) activeLeftover = l;
    }
    final Widget pane;
    if (_sidePane == 'general') {
      pane = _betaGeneralPane(map);
    } else if (_sidePane == 'tasks') {
      pane = _betaTasksPane(map);
    } else if (active != null) {
      pane = _betaPointPane(active, map);
    } else if (activeLeftover != null) {
      pane = _betaLeftoverPane(activeLeftover, map);
    } else {
      pane = ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
        children: [
          RdInfoCard(
            icon: Icons.list,
            text: _sections.isNotEmpty
                ? context.l10n.protocolFlutterChooseLeft
                : context.l10n.protocolFlutterPlanEmptyShort,
            action: RdOutlineButton(label: context.l10n.protocolAddPoint, onPressed: _addSpontaneousTopic),
          ),
        ],
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final sideWidth = (constraints.maxWidth * 0.32).clamp(300.0, 380.0);
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): _nextSection,
          const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true): _nextSection,
          const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): _previousSection,
          const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): _previousSection,
        },
        child: Focus(
          focusNode: _pageFocus,
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: sideWidth, child: _betaSide(map)),
              Expanded(child: pane),
            ],
          ),
        ),
      );
    });
  }

  /// Beta, phone: three buttons for what belongs to the whole meeting,
  /// then the points; only "Abschließen" stays in the footer.
  Widget _buildBetaEditLayout(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final map = _taskSectionMap;
    final unassigned = _unassignedTasks(map);
    final activeIndex = _sections.indexWhere((s) => s.id == _activeId);
    final hasNext = activeIndex >= 0 && activeIndex + 1 < _sections.length;
    final live = _betaLiveCard(hasNext ? () => _activate(_sections[activeIndex + 1].id) : null);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Expanded(
              flex: 11,
              child: ProtocolStripButton(
                key: const Key('rd-protocol-attendees'),
                icon: Icons.group,
                label: l10n.protocolPresentCount(_attendees.present.length),
                semanticLabel: _betaAttendeeSummary,
                onTap: _openAttendees,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 9,
              child: ProtocolStripButton(
                key: const Key('rd-protocol-general'),
                icon: Icons.notes,
                label: l10n.protocolNotes,
                dot: _hasNotes(protocolGeneralSectionId),
                semanticLabel: _hasNotes(protocolGeneralSectionId)
                    ? '${l10n.protocolGeneralNotes}, ${l10n.protocolHasNotes}'
                    : l10n.protocolGeneralNotes,
                onTap: _openGeneralNotes,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 11,
              child: ProtocolStripButton(
                key: const Key('rd-protocol-tasks'),
                icon: Icons.task_alt,
                label: _tasks.isEmpty ? l10n.teamOrgTabTasks : l10n.protocolTaskCount(_tasks.length),
                onTap: _openTasksSheet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (live != null) ...[live, const SizedBox(height: 12)],
        if (_isPublished) _betaPublishedLine(),
        if (_sections.isEmpty)
          RdCard(child: Text(l10n.protocolPlanEmpty, style: RdType.meta(p, size: 15))),
        for (final s in _sections)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: _betaSectionCard(s, map)),
        Center(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: _addSpontaneousTopic,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 22, color: p.link),
                      const SizedBox(width: 6),
                      Text(l10n.protocolPoint,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.link)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (unassigned.isNotEmpty) ...[
          const SizedBox(height: 12),
          RdGroupLabel(l10n.protocolMoreTasks),
          RdCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _betaTaskList(unassigned),
          ),
        ],
        ..._leftoverWidgets(),
      ],
    );
  }

  /// Beta, phone: one point. Closed it shows its status as a word; open it
  /// shows the result chips in one row, the notes and its tasks.
  Widget _betaSectionCard(_Section s, Map<String, String> map) {
    final p = context.rd;
    final active = _activeId == s.id;
    final isLive = _live?.fieldId == s.id;
    final tasks = _tasksFor(s.id, map);
    final kicker = _betaKicker(s);
    final status = active ? null : _betaStatusPill(s.id);
    return RdCard(
      padding: EdgeInsets.zero,
      border: isLive
          ? Border.all(color: p.absent, width: 1.5)
          : (active ? Border.all(color: p.primary, width: 1.5) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: active,
            child: InkWell(
              onTap: () => setState(() {
                _activeId = active ? null : s.id;
                _sidePane = null;
              }),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 12, active ? 6 : 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (kicker.isNotEmpty) Text(kicker.toUpperCase(), style: RdType.eyebrow(p.text2)),
                          const SizedBox(height: 2),
                          Text(s.name, style: RdType.section(p)),
                          if (active && s.conductor != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(s.conductor!, style: RdType.meta(p, size: 14)),
                            ),
                          if (!active && _hasNotes(s.id))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(_previewOf(s.id),
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: RdType.meta(p, size: 13)),
                            ),
                          if (!active && tasks.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(context.l10n.protocolTaskCount(tasks.length), style: RdType.meta(p, size: 13)),
                            ),
                        ],
                      ),
                    ),
                    if (status != null) Padding(padding: const EdgeInsets.only(left: 8), child: status),
                    const SizedBox(width: 4),
                    Icon(active ? Icons.expand_less : Icons.expand_more, color: p.text2),
                  ],
                ),
              ),
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.isTop) ...[
                    ProtocolOutcomeChips(
                      value: _outcomes[s.id],
                      onChanged: (o) => _setOutcome(s.id, o),
                      singleLine: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(p.listRadius),
                    child: ColoredBox(color: p.bg, child: _betaEditor(s.id)),
                  ),
                  if (tasks.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _betaTaskList(tasks)),
                  _betaAddTask(s.id),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Beta, phone: all tasks of the meeting with the point they belong to.
  Future<void> _openTasksSheet() async {
    final map = _taskSectionMap;
    await showRdSheet<void>(
      context,
      Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RdSheetTitle(ctx.l10n.teamOrgTabTasks),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  RdCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _tasks.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(ctx.l10n.protocolNoTasksYet, style: RdType.meta(ctx.rd, size: 14)),
                          )
                        : _betaTaskList(_tasks, labels: map, onOpen: (t) {
                            // The sheet lies above the pages: close it first.
                            Navigator.of(ctx).pop();
                            context.push('/settings/tasks/${t.id}');
                          }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "TOP 2" / point name / "Allgemein" of the section a task belongs to.
  String? _sectionLabelOfTask(TeamTask t, Map<String, String> map) {
    final id = map[t.id];
    if (id == null) return null;
    if (id == protocolGeneralSectionId) return context.l10n.protocolGeneral;
    for (final s in _sections) {
      if (s.id == id) return s.topNumber != null ? context.l10n.protocolTop(s.topNumber!) : s.name;
    }
    return null;
  }

  Widget _buildReadLayout(BuildContext context) {
    final theme = Theme.of(context);
    final map = _taskSectionMap;
    final att = _attendees;
    final unassigned = _unassignedTasks(map);
    Widget card(Widget child) =>
        Card(child: Padding(padding: const EdgeInsets.all(AppDimensions.paddingM), child: child));
    final cardLabel = theme.textTheme.titleSmall;
    final readTitle = theme.textTheme.titleMedium;
    Widget pill(String name, {bool muted = false}) =>
        Chip(label: Text(name, style: muted ? TextStyle(color: AppColors.mediumOf(context)) : null));
    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM + MediaQuery.paddingOf(context).bottom),
      children: [
        if (_isPublished)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
            child: Row(children: [
              Icon(AppIcons.checkCircle, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusLine)),
            ]),
          ),
        if (att.present.isNotEmpty || att.excused.isNotEmpty)
          card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.protocolPresentList(att.present.length), style: cardLabel),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final a in att.present) pill(a.name),
                  ]),
                  if (att.excused.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(context.l10n.protocolExcusedList(att.excused.length), style: cardLabel),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final a in att.excused) pill(a.name, muted: true),
                    ]),
                  ],
                ],
              ),
          ),
        for (final s in _sections)
          if (s.isTop || _hasNotes(s.id) || _outcomes[s.id] != null || _tasksFor(s.id, map).isNotEmpty)
            card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.topNumber != null)
                      Text(context.l10n.protocolTop(s.topNumber!),
                          style: theme.textTheme.labelSmall),
                    Row(children: [
                      Expanded(child: Text(s.name, style: readTitle)),
                      if (_outcomes[s.id] != null)
                        TeamOrgBadge(
                            label: outcomeLabels[_outcomes[s.id]] ?? '', color: outcomeColor(_outcomes[s.id])),
                    ]),
                    if (_hasNotes(s.id))
                      _editor(_controllerFor(s.id, readOnly: true), editable: false)
                    else if (_tasksFor(s.id, map).isEmpty)
                      Text(context.l10n.protocolNoNotes, style: TextStyle(color: AppColors.mediumOf(context))),
                    _taskList(_tasksFor(s.id, map)),
                  ],
                ),
            ),
        ..._leftoverWidgets(),
        if (_hasNotes(protocolGeneralSectionId) || unassigned.isNotEmpty)
          card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.protocolGeneralNotes, style: readTitle),
                  if (_hasNotes(protocolGeneralSectionId))
                    _editor(_controllerFor(protocolGeneralSectionId, readOnly: true), editable: false),
                  _taskList(unassigned),
                ],
              ),
          ),
        const SizedBox(height: AppDimensions.paddingM),
        OutlinedButton.icon(
          onPressed: _sharePdf,
          icon: Icon(AppIcons.iosShare),
          label: IonButtonLabel(context.l10n.protocolSharePdf),
        ),
      ],
    );
  }
}


/// Live progress banner showing the currently active plan item.
class _LiveBar extends StatefulWidget {
  const _LiveBar({required this.label});

  final String label;

  @override
  State<_LiveBar> createState() => _LiveBarState();
}

class _LiveBarState extends State<_LiveBar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const _shade = Color(0xFF00815E);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.35).animate(_pulse),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _shade)),
            ),
          ],
        ),
      ),
    );
  }
}
