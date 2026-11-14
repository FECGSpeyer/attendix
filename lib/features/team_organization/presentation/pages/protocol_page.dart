import 'dart:async';

import 'package:flutter/material.dart';
import 'package:attendix/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart' show DeepCollectionEquality;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/branding_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
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
import '../../../planning/presentation/widgets/ion_items.dart';
import '../../../../l10n/l10n.dart';
import '../../protocol_pdf.dart';
import '../../team_org_utils.dart';
import '../../tiptap_delta.dart';
import '../../protocol_layout.dart';
import '../widgets/protocol_editor.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, outcomeColor;
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/services/native/native_file_service.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart';
import '../../../../shared/widgets/dialogs/ion_sheet.dart' show showIonSheet, IonSheetScaffold;
import '../../../../shared/widgets/layout/ionic_ios.dart' as ios27 show IonItem;
import '../../../../shared/widgets/layout/ionic_ios.dart' show ionItemBackground;

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
  int _savingCount = 0;
  DateTime? _lastSavedAt;
  DateTime _lastErrorToast = DateTime(2000);
  Timer? _liveTimer;
  ({String fieldId, int remainingMinutes})? _live;

  // Wide layout (Tagesordnung | Notizen zum Punkt | Allgemeine Notizen)
  ColumnWidths _widths = defaultColumnWidths;
  String? _resizing;
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
    _loadWidths();
  }

  Future<void> _loadWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widths = parseColumnWidths(prefs.getString(protocolColumnWidthsKey));
      if (mounted) setState(() => _widths = widths);
    } catch (_) {}
  }

  Future<void> _storeWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(protocolColumnWidthsKey, encodeColumnWidths(_widths));
    } catch (_) {}
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

  String get _shortDate {
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    return d == null ? '' : DateFormat(dateFmt(DateFmtKind.dayMonth)).format(d);
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
    final bool? confirmed;
    if (context.rdSkin == null) {
      // DAS-01/DAS-24: Ionic sheet modal `[initialBreakpoint]="1"
      // [breakpoints]="[0, 1]"`, "Abbrechen" in `slot="start"`,
      // `ion-content color="light"` with three inset lists.
      confirmed = await showIonSheet<bool>(
        context,
        breakpoints: const [0, 1],
        initialBreakpoint: 1,
        builder: (ctx, controller) => StatefulBuilder(
          builder: (ctx, setLocal) => IonSheetScaffold(
            title: ctx.l10n.protocolPublish,
            start: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: IonButtonLabel(ctx.l10n.commonCancel)),
            ],
            backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
            body: _publishSheetBody(ctx, controller, summary, closures, sendPdf, (v) => setLocal(() => sendPdf = v),
                () => setLocal(() {})),
          ),
        ),
      );
    } else {
    confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
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
                            AppColors.medium,
                            ctx.l10n.protocolTaskCount(summary.taskCount),
                            summary.taskOwners.isNotEmpty ? ctx.l10n.protocolForNames(joinNames(summary.taskOwners)) : null),
                        if (summary.withoutOutcome.isNotEmpty)
                          _summaryTile(AppIcons.helpOutline, AppColors.medium,
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
                          AppColors.medium,
                          ctx.l10n.protocolMayRead,
                          (_type?.relevantGroups?.isNotEmpty ?? false)
                              ? ctx.l10n.protocolReadGroups(_type?.name ?? '')
                              : ctx.l10n.protocolReadAll(_type?.name ?? ''),
                        ),
                        _summaryTile(
                          AppIcons.notificationsOutlined,
                          AppColors.medium,
                          ctx.l10n.protocolNotified,
                          '${ctx.l10n.protocolRecipients(summary.recipientCount)}${summary.taskOwners.isNotEmpty ? ctx.l10n.protocolTaskOwners(summary.taskOwners.length) : ''}',
                        ),
                        SwitchListTile.adaptive(
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
    }
    if (confirmed == true) await _publish(closures, sendPdf);
  }

  /// Classic "Freigeben" sheet content (Ionic `protocol.page.html` publish
  /// modal): Zusammenfassung / Themen abschließen / Sichtbarkeit as inset
  /// lists with list headers, grey hint, block buttons.
  Widget _publishSheetBody(
    BuildContext ctx,
    ScrollController controller,
    PublishSummary summary,
    List<TopicClosure> closures,
    bool sendPdf,
    ValueChanged<bool> onSendPdf,
    VoidCallback onClosureChanged,
  ) {
    final l10n = ctx.l10n;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        IonInsetList(
          header: l10n.protocolSummary,
          children: [
            if (summary.decided.isNotEmpty)
              _ionSummaryItem(AppIcons.checkCircle, AppColors.success,
                  l10n.protocolDecidedCount(summary.decided.length), summary.decided.join(', ')),
            if (summary.discussed.isNotEmpty)
              _ionSummaryItem(AppIcons.forumOutlined, AppColors.primary,
                  l10n.protocolDiscussedCount(summary.discussed.length), summary.discussed.join(', ')),
            if (summary.postponed.isNotEmpty)
              _ionSummaryItem(
                  AppIcons.accessTime,
                  AppColors.warning,
                  l10n.protocolPostponedCount(summary.postponed.length),
                  '${summary.postponed.join(', ')}${_type?.suggestPostponed == true ? l10n.protocolSuggestNext : ''}'),
            _ionSummaryItem(AppIcons.checkBoxOutlined, AppColors.medium, l10n.protocolTaskCount(summary.taskCount),
                summary.taskOwners.isNotEmpty ? l10n.protocolForNames(joinNames(summary.taskOwners)) : null),
            if (summary.withoutOutcome.isNotEmpty)
              _ionSummaryItem(AppIcons.helpOutline, AppColors.medium,
                  l10n.protocolWithoutOutcome(summary.withoutOutcome.length), summary.withoutOutcome.join(', ')),
            if (summary.withoutNotes.isNotEmpty)
              _ionSummaryItem(AppIcons.errorOutline, AppColors.warning,
                  l10n.protocolWithoutNotes(summary.withoutNotes.length), summary.withoutNotes.join(', ')),
          ],
        ),
        if (closures.isNotEmpty)
          IonInsetList(
            header: l10n.protocolCloseTopics,
            children: [
              // Ionic `ion-checkbox justify="space-between"`: label first,
              // checkbox at the end.
              for (final c in closures)
                ios27.IonItem(
                  title: Text(c.title),
                  subtitle: Text(outcomeLabels[c.outcome] ?? ''),
                  trailing: Checkbox.adaptive(
                    value: c.close,
                    onChanged: (v) {
                      c.close = v ?? false;
                      onClosureChanged();
                    },
                  ),
                  onTap: () {
                    c.close = !c.close;
                    onClosureChanged();
                  },
                ),
            ],
          ),
        IonInsetList(
          header: l10n.protocolVisibility,
          children: [
            _ionSummaryItem(
              AppIcons.visibilityOutlined,
              AppColors.medium,
              l10n.protocolMayRead,
              (_type?.relevantGroups?.isNotEmpty ?? false)
                  ? l10n.protocolReadGroups(_type?.name ?? '')
                  : l10n.protocolReadAll(_type?.name ?? ''),
            ),
            _ionSummaryItem(
              AppIcons.notificationsOutlined,
              AppColors.medium,
              l10n.protocolNotified,
              '${l10n.protocolRecipients(summary.recipientCount)}${summary.taskOwners.isNotEmpty ? l10n.protocolTaskOwners(summary.taskOwners.length) : ''}',
            ),
            ios27.IonItem(
              title: Text(l10n.protocolSendPdf),
              subtitle: Text(l10n.protocolViaTelegram),
              trailing: Switch.adaptive(value: sendPdf, onChanged: onSendPdf),
              onTap: () => onSendPdf(!sendPdf),
            ),
          ],
        ),
        // Ionic `.hint-text ion-padding-horizontal`: 13px grey.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(l10n.protocolEditAfterPublish, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
        ),
        // Ionic `.ion-padding`: two block buttons, the first in the accent
        // colour with `paper-plane-outline`.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _protocolAccent, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: Icon(AppIcons.paperPlaneOutline),
                label: IonButtonLabel(
                    _isPublished ? l10n.protocolFlutterRepublishNotify : l10n.protocolFlutterPublishNotify),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: IonButtonLabel(_isPublished ? l10n.commonCancel : l10n.protocolFlutterKeepDraft),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Ionic summary `ion-item`: icon in `slot="start"`, h3 + p.
  Widget _ionSummaryItem(IconData icon, Color color, String title, String? subtitle) => ios27.IonItem(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
      );

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
    if (ref.watch(redesignEnabledProvider)) return _buildBeta(context, wide, showFooter);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_flushAll());
      },
      child: Scaffold(
        appBar: AppBar(
          // Ionic `.title-stack`: centered title with a small grey second line.
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.protocolTitle),
              if (_attendance != null && !_notAvailable)
                Text(
                  '$_title · $_shortDate · ${_isPublished ? context.l10n.teamOrgPublished : context.l10n.teamOrgDraft}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.medium),
                ),
            ],
          ),
          // DAS-02: Ionic `ion-buttons slot="end"` (iOS glass capsule).
          actions: [
            if (_attendance != null && !_notAvailable && !_loadFailed)
              ToolbarButtonGroup(children: [
                IconButton(tooltip: context.l10n.protocolSharePdf, icon: Icon(AppIcons.iosShare), onPressed: _sharePdf),
              ]),
          ],
        ),
        // Ionic `.protocol-footer`: centered save state above two equal buttons.
        bottomNavigationBar: showFooter
            ? Material(
                color: Theme.of(context).appBarTheme.backgroundColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 4, AppDimensions.paddingM, 8),
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
                            Text(_saveLabel, style: const TextStyle(fontSize: 12, color: AppColors.medium)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              // Ionic: the `.notes-dot` follows the label.
                              child: OutlinedButton.icon(
                                onPressed: _openGeneralNotes,
                                icon: Icon(AppIcons.descriptionOutlined),
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(child: IonButtonLabel(context.l10n.protocolNotes)),
                                    if (_hasNotes(protocolGeneralSectionId))
                                      Semantics(
                                        label: context.l10n.protocolHasNotes,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          margin: const EdgeInsets.only(left: 6),
                                          decoration: const BoxDecoration(
                                              color: AppColors.primary, shape: BoxShape.circle),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingS),
                            Expanded(
                              child: FilledButton(
                                // Ionic `.publish-button`: accent #3b7d84.
                                style: FilledButton.styleFrom(backgroundColor: _protocolAccent),
                                onPressed: _openPublish,
                                child: IonButtonLabel(
                                    _isPublished ? context.l10n.protocolRepublish : context.l10n.protocolPublishShort),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        body: _loading
            ? const Center(child: AppSpinner())
            : _notAvailable
                ? _centerState(AppIcons.lockOutline, context.l10n.protocolNotPublished, context.l10n.protocolNotPublishedHint)
                : _loadFailed || _attendance == null
                    ? IonEmptyState(
                        icon: context.rdSkin == null ? AppIcons.cloudOffOutlined : AppIcons.cloudOff,
                        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                        title: context.l10n.protocolLoadFailed,
                        text: '',
                        action: OutlinedButton(onPressed: _load, child: IonButtonLabel(context.l10n.protocolRetry)),
                      )
                    : _isLeader
                        ? (wide ? _buildWideLayout(context) : _buildEditLayout(context))
                        : _buildReadLayout(context),
      ),
    );
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
      body = _isLeader ? (wide ? _buildWideLayout(context) : _buildEditLayout(context)) : _buildReadLayout(context);
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

  /// Beta footer: save state above "Notizen" and "Veröffentlichen".
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
                  Text(_saveLabel, style: RdType.meta(p, size: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: RdOutlineButton(
                      label: _hasNotes(protocolGeneralSectionId) ? '${l10n.protocolNotes} •' : l10n.protocolNotes,
                      icon: Icons.description_outlined,
                      onPressed: _openGeneralNotes,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RdPrimaryButton(
                      label: _isPublished ? l10n.protocolRepublish : l10n.rdTeamFinishMeeting,
                      onPressed: _openPublish,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ionic `.center-state`: 44px icon, 17px/600 title, grey text.
  Widget _centerState(IconData icon, String title, String text) => IonEmptyState(
        icon: icon,
        padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
        title: title,
        text: text,
      );

  Widget _attendeeRow() {
    final att = _attendees;
    final preview = att.present.take(4).toList();
    final more = att.present.length - preview.length;
    if (context.rdSkin == null) return _classicAttendeeRow(preview, more);
    return Card(
      child: ListTile(
        onTap: _openAttendees,
        leading: SizedBox(
          width: 28.0 * (preview.length + (more > 0 ? 1 : 0)).clamp(1, 5) + 8,
          child: Stack(
            children: [
              for (var i = 0; i < preview.length; i++)
                Positioned(
                  left: i * 22.0,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: _avatarColors[(preview[i].personId ?? i) % _avatarColors.length],
                    child: Text(_initials(preview[i]), style: const TextStyle(fontSize: 11, color: Colors.white)),
                  ),
                ),
              if (more > 0)
                Positioned(
                  left: preview.length * 22.0,
                  child: CircleAvatar(radius: 15, child: Text('+$more', style: const TextStyle(fontSize: 11))),
                ),
            ],
          ),
        ),
        title: Text(context.l10n.protocolPresentCount(att.present.length)),
        subtitle: Text(
            '${att.excused.isNotEmpty ? context.l10n.protocolExcusedCount(att.excused.length) : ''}${context.l10n.protocolFromAttendance}'),
        trailing: const IonDetailIcon(),
      ),
    );
  }

  /// DAS-23: Ionic `.attendee-row` in a `.card`: overlapping 28px initials
  /// with a 2px card-coloured border, 16px title, 13px grey line, chevron.
  Widget _classicAttendeeRow(List<ProtocolAttendee> preview, int more) {
    final att = _attendees;
    final bg = ionItemBackground(context);
    Widget ini(String text, Color color) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: bg, width: 2)),
          child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        );
    final count = preview.length + (more > 0 ? 1 : 0);
    return _ProtocolCard(
      child: InkWell(
        onTap: _openAttendees,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (count > 0) ...[
                SizedBox(
                  width: 28 + 20.0 * (count - 1),
                  height: 28,
                  child: Stack(children: [
                    for (var i = 0; i < preview.length; i++)
                      Positioned(
                        left: i * 20.0,
                        child: ini(_initials(preview[i]),
                            _avatarColors[(preview[i].personId ?? i) % _avatarColors.length]),
                      ),
                    if (more > 0)
                      Positioned(left: preview.length * 20.0, child: ini('+$more', const Color(0xFF8E8E93))),
                  ]),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.protocolPresentCount(att.present.length),
                        style: const TextStyle(fontSize: 16, height: 1.25)),
                    const SizedBox(height: 2),
                    Text(
                      '${att.excused.isNotEmpty ? context.l10n.protocolExcusedCount(att.excused.length) : ''}${context.l10n.protocolFromAttendance}',
                      style: const TextStyle(fontSize: 13, color: AppColors.medium),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 16, color: const Color(0xFFC4C4C7)),
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
    if (context.rdSkin == null) {
      // DAS-01/DAS-25: Ionic `[initialBreakpoint]="0.6" [breakpoints]="[0, 0.6, 1]"`,
      // "Fertig" in `slot="end"`, `ion-content color="light"`, one inset list
      // with list header per group, 32px initials (excused grey).
      Widget ini(ProtocolAttendee a, Color color) => Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(_initials(a),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          );
      await showIonSheet<void>(
        context,
        breakpoints: const [0, 0.6, 1],
        initialBreakpoint: 0.6,
        builder: (ctx, controller) => IonSheetScaffold(
          title: ctx.l10n.protocolParticipants,
          end: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: IonButtonLabel(ctx.l10n.personDone))],
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          body: ListView(
            controller: controller,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              IonInsetList(
                header: ctx.l10n.protocolPresentList(att.present.length),
                children: [
                  for (final a in att.present)
                    ios27.IonItem(
                      leading: ini(a, _avatarColors[(a.personId ?? 0) % _avatarColors.length]),
                      title: Text(a.name),
                    ),
                  if (att.present.isEmpty)
                    ios27.IonItem(title: Text(ctx.l10n.protocolNobodyPresent), titleColor: AppColors.medium),
                ],
              ),
              if (att.excused.isNotEmpty)
                IonInsetList(
                  header: ctx.l10n.protocolExcusedList(att.excused.length),
                  children: [
                    for (final a in att.excused)
                      ios27.IonItem(
                        leading: ini(a, const Color(0xFF8E8E93)),
                        title: Text(a.name),
                        subtitle: a.notes?.isNotEmpty == true ? Text(a.notes!) : null,
                      ),
                  ],
                ),
              if (att.others.isNotEmpty)
                IonInsetList(
                  header: ctx.l10n.protocolOthersList(att.others.length),
                  children: [
                    for (final a in att.others) ios27.IonItem(title: Text(a.name), titleColor: AppColors.medium),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(ctx.l10n.protocolListFromAttendance,
                    style: const TextStyle(fontSize: 13, color: AppColors.medium)),
              ),
            ],
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              toolbarHeight: ionModalToolbarHeight(context),
              automaticallyImplyLeading: false,
              title: Text(ctx.l10n.protocolParticipants),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: IonButtonLabel(ctx.l10n.personDone))],
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(title: Text(ctx.l10n.protocolPresentList(att.present.length), style: Theme.of(ctx).textTheme.titleSmall)),
                  for (final a in att.present)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _avatarColors[(a.personId ?? 0) % _avatarColors.length],
                        child: Text(_initials(a), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(a.name),
                    ),
                  if (att.present.isEmpty)
                    ListTile(
                        title: Text(ctx.l10n.protocolNobodyPresent, style: const TextStyle(color: AppColors.medium))),
                  if (att.excused.isNotEmpty) ...[
                    ListTile(
                        title: Text(ctx.l10n.protocolExcusedList(att.excused.length), style: Theme.of(ctx).textTheme.titleSmall)),
                    for (final a in att.excused)
                      ListTile(
                        leading: CircleAvatar(child: Text(_initials(a))),
                        title: Text(a.name),
                        subtitle: a.notes?.isNotEmpty == true ? Text(a.notes!) : null,
                      ),
                  ],
                  if (att.others.isNotEmpty) ...[
                    ListTile(
                        title: Text(ctx.l10n.protocolOthersList(att.others.length),
                            style: Theme.of(ctx).textTheme.titleSmall)),
                    for (final a in att.others)
                      ListTile(title: Text(a.name, style: const TextStyle(color: AppColors.medium))),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    child: Text(ctx.l10n.protocolListFromAttendance),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGeneralNotes() async {
    final controller = _controllerFor(protocolGeneralSectionId);
    if (context.rdSkin == null) {
      // DAS-01: Ionic `[initialBreakpoint]="0.75" [breakpoints]="[0, 0.75, 1]"`,
      // "Fertig" in `slot="end"`, `ion-content color="light" class="ion-padding"`.
      await showIonSheet<void>(
        context,
        breakpoints: const [0, 0.75, 1],
        initialBreakpoint: 0.75,
        builder: (ctx, scroll) => IonSheetScaffold(
          title: ctx.l10n.protocolGeneralNotes,
          end: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: IonButtonLabel(ctx.l10n.personDone))],
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          body: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text(ctx.l10n.protocolWholeMeeting, style: const TextStyle(fontSize: 13, color: AppColors.medium)),
              const SizedBox(height: 10),
              _editor(controller),
              StatefulBuilder(
                builder: (sheetCtx, setSheet) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _taskList(_tasksFor(protocolGeneralSectionId, _taskSectionMap)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await _createTask(protocolGeneralSectionId);
                          if (sheetCtx.mounted) setSheet(() {});
                        },
                        icon: Icon(AppIcons.addCircleOutline),
                        label: IonButtonLabel(ctx.l10n.tasksTask),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await _flush(protocolGeneralSectionId);
      if (mounted) setState(() {});
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              toolbarHeight: ionModalToolbarHeight(context),
              automaticallyImplyLeading: false,
              title: Text(ctx.l10n.protocolGeneralNotes),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: IonButtonLabel(ctx.l10n.personDone))],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                children: [
                  Text(ctx.l10n.protocolWholeMeeting),
                  const SizedBox(height: AppDimensions.paddingS),
                  _editor(controller),
                  // Ionic: the task form opens above the notes sheet; back in
                  // the sheet the reference and the task are shown and
                  // writing continues.
                  StatefulBuilder(
                    builder: (sheetCtx, setSheet) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _taskList(_tasksFor(protocolGeneralSectionId, _taskSectionMap)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              await _createTask(protocolGeneralSectionId);
                              if (sheetCtx.mounted) setSheet(() {});
                            },
                            icon: Icon(AppIcons.addCircleOutline),
                            label: IonButtonLabel(ctx.l10n.tasksTask),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    if (context.rdSkin == null) {
      // Ionic `.task-row`: 20px icon, 15px title, 13px grey line, hairline
      // separators between the rows.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++)
            InkWell(
              onTap: () => context.push('/settings/tasks/${list[i].id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: i == 0
                    ? null
                    : BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
                child: Row(
                  children: [
                    Icon(
                      list[i].status == 'completed' ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
                      size: 20,
                      color: list[i].status == 'completed' ? AppColors.success : AppColors.medium,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list[i].title,
                            style: list[i].status == 'completed'
                                ? const TextStyle(
                                    fontSize: 15, decoration: TextDecoration.lineThrough, color: AppColors.medium)
                                : const TextStyle(fontSize: 15),
                          ),
                          if (_taskLine(list[i]).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(_taskLine(list[i]),
                                  style: const TextStyle(fontSize: 13, color: AppColors.medium)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Column(
      children: [
        for (final t in list)
          ListTile(
            dense: true,
            leading: Icon(
              t.status == 'completed' ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
              color: t.status == 'completed' ? AppColors.success : AppColors.medium,
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

  Widget _outcomeSelector(String sectionId) {
    final current = _outcomes[sectionId];
    if (context.rdSkin == null) {
      return _OutcomeSegment(value: current, onChanged: (o) => _setOutcome(sectionId, o));
    }
    return Wrap(
      spacing: 8,
      children: [
        for (final o in const ['discussed', 'decided', 'postponed'])
          ChoiceChip(
            label: Text(outcomeLabels[o]!),
            selected: current == o,
            selectedColor: outcomeColor(o).withValues(alpha: 0.25),
            // Classic: the selection is shown by colour only (no Material
            // checkmark); Beta keeps the chip as it was.
            showCheckmark: context.rdSkin != null,
            onSelected: (_) => _setOutcome(sectionId, o),
          ),
      ],
    );
  }

  Widget _buildEditLayout(BuildContext context) {
    final map = _taskSectionMap;
    final unassigned = _unassignedTasks(map);
    _Section? liveSec;
    for (final s in _sections) {
      if (s.id == _live?.fieldId) liveSec = s;
    }
    final activeIndex = _sections.indexWhere((s) => s.id == _activeId);
    final hasNext = activeIndex >= 0 && activeIndex + 1 < _sections.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        _attendeeRow(),
        if (_live != null && liveSec != null && context.rdSkin == null)
          _LiveBar(
            label: context.l10n.protocolRunning(
                liveSec.topNumber != null ? context.l10n.protocolTop(liveSec.topNumber!) : liveSec.name,
                _live!.remainingMinutes),
            nextLabel: hasNext ? context.l10n.protocolNextPoint : null,
            onNext: hasNext ? () => setState(() => _activeId = _sections[activeIndex + 1].id) : null,
          )
        else if (_live != null && liveSec != null)
          Card(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: ListTile(
              leading: Icon(AppIcons.circle, color: AppColors.danger, size: 12),
              title: Text(context.l10n.protocolRunning(
                  liveSec.topNumber != null ? context.l10n.protocolTop(liveSec.topNumber!) : liveSec.name,
                  _live!.remainingMinutes)),
              trailing: hasNext
                  ? TextButton(
                      onPressed: () => setState(() => _activeId = _sections[activeIndex + 1].id),
                      child: IonButtonLabel(context.l10n.protocolNextPoint),
                    )
                  : null,
            ),
          ),
        if (_isPublished)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
            child: Row(children: [
              Icon(AppIcons.checkCircle, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusLine)),
            ]),
          ),
        if (_sections.isEmpty && context.rdSkin == null)
          _ProtocolCard(
            padding: const EdgeInsets.all(16),
            child: Text(context.l10n.protocolPlanEmpty, style: const TextStyle(color: AppColors.medium)),
          )
        else if (_sections.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Text(context.l10n.protocolPlanEmpty),
            ),
          ),
        for (final s in _sections) _sectionCard(s, map),
        // Ionic `.add-point`: clear block button in the accent colour.
        TextButton.icon(
          style: context.rdSkin == null ? TextButton.styleFrom(foregroundColor: _protocolAccent) : null,
          onPressed: _addSpontaneousTopic,
          icon: Icon(AppIcons.add),
          label: IonButtonLabel(context.l10n.protocolPoint),
        ),
        if (unassigned.isNotEmpty && context.rdSkin == null) ...[
          // Ionic `.group-label`: 13px / 600 uppercase grey.
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
            child: Text(context.l10n.protocolMoreTasks.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.26, color: AppColors.medium)),
          ),
          _ProtocolCard(padding: const EdgeInsets.symmetric(horizontal: 16), child: _taskList(unassigned)),
        ] else if (unassigned.isNotEmpty) ...[
          Text(context.l10n.protocolMoreTasks, style: Theme.of(context).textTheme.titleSmall),
          Card(child: _taskList(unassigned)),
        ],
        ..._leftoverWidgets(),
      ],
    );
  }

  Widget _sectionCard(_Section s, Map<String, String> map) {
    final active = _activeId == s.id;
    final isLive = _live?.fieldId == s.id;
    final tasks = _tasksFor(s.id, map);
    final outcome = _outcomes[s.id];
    final theme = Theme.of(context);
    if (context.rdSkin == null) return _classicSectionCard(s, map, active, isLive, tasks, outcome);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        side: BorderSide(
          // Ionic: live TOP = green ring, active = accent ring.
          color: isLive
              ? (context.rdSkin == null ? AppColors.success : AppColors.danger)
              : (active ? (context.rdSkin == null ? _protocolAccent : AppColors.primary) : Colors.transparent),
          width: context.rdSkin == null ? 2 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: () => setState(() => _activeId = active ? null : s.id),
            leading: !active && _hasNotes(s.id) && outcome == null
                ? Icon(AppIcons.checkCircleOutline, color: AppColors.success)
                : null,
            title: s.isTop
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${context.l10n.protocolTop(s.topNumber!)}${s.start != null ? ' · ${s.start}' : ''}',
                          style: theme.textTheme.labelSmall),
                      Text(s.name),
                    ],
                  )
                : Text('${s.start != null ? '${s.start} · ' : ''}${s.name}'),
            subtitle: !active && _hasNotes(s.id)
                ? Text(_previewOf(s.id), maxLines: 2, overflow: TextOverflow.ellipsis)
                : (s.isTop && s.conductor != null ? Text(s.conductor!) : null),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!active && outcome != null)
                  TeamOrgBadge(label: outcomeLabels[outcome] ?? outcome, color: outcomeColor(outcome)),
                if (s.duration > 0)
                  Padding(padding: const EdgeInsets.only(left: 6), child: Text(context.l10n.planningMinShort(s.duration))),
                Icon(active ? AppIcons.expandLess : AppIcons.expandMore),
              ],
            ),
          ),
          if (active)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.isTop) _outcomeSelector(s.id),
                  const SizedBox(height: AppDimensions.paddingS),
                  _editor(_controllerFor(s.id)),
                  _taskList(tasks),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _createTask(s.id),
                      icon: Icon(AppIcons.addCircleOutline),
                      label: IonButtonLabel(context.l10n.tasksTask),
                    ),
                  ),
                ],
              ),
            )
          else if (tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingS),
              child: Text(context.l10n.protocolTaskCount(tasks.length),
                  style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  /// DAS-23: Ionic `.card.section-card` – flat card (radius 20), head row
  /// padding 12 / 16 with the uppercase accent kicker, 16px title, grey
  /// conductor / preview line, outcome badge, `.dur` pill and a 16px grey
  /// chevron; 2px inset ring when active (accent) or live (green).
  Widget _classicSectionCard(
      _Section s, Map<String, String> map, bool active, bool isLive, List<TeamTask> tasks, String? outcome) {
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = const TextStyle(fontSize: 13, color: AppColors.medium);
    return _ProtocolCard(
      ring: active ? _protocolAccent : (isLive ? AppColors.success.withValues(alpha: 0.6) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: active,
            child: InkWell(
              onTap: () => setState(() => _activeId = active ? null : s.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (!active && _hasNotes(s.id) && outcome == null) ...[
                      Icon(AppIcons.checkCircleOutline, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s.isTop) ...[
                            Text(
                                '${l10n.protocolTop(s.topNumber!)}${s.start != null ? ' · ${s.start}' : ''}'
                                    .toUpperCase(),
                                style: _kickerStyle),
                            Text(s.name, style: const TextStyle(fontSize: 16, height: 1.25)),
                            if (s.conductor != null)
                              Padding(padding: const EdgeInsets.only(top: 2), child: Text(s.conductor!, style: muted)),
                          ] else
                            Text('${s.start != null ? '${s.start} · ' : ''}${s.name}',
                                style: const TextStyle(fontSize: 16, height: 1.25)),
                          if (!active && _hasNotes(s.id))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(_previewOf(s.id), maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
                            ),
                        ],
                      ),
                    ),
                    if (!active && outcome != null) ...[
                      const SizedBox(width: 10),
                      TeamOrgBadge(label: outcomeLabels[outcome] ?? outcome, color: outcomeColor(outcome)),
                    ],
                    if (s.duration > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(l10n.planningMinShort(s.duration), style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Icon(active ? AppIcons.expandLess : AppIcons.expandMore, size: 16, color: const Color(0xFFC4C4C7)),
                  ],
                ),
              ),
            ),
          ),
          if (active) ...[
            if (s.isTop)
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: _outcomeSelector(s.id)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: _editor(_controllerFor(s.id))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _taskList(tasks)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _createTask(s.id),
                  icon: Icon(AppIcons.addCircleOutline),
                  label: IonButtonLabel(l10n.tasksTask),
                ),
              ),
            ),
          ] else if (tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(l10n.protocolTaskCount(tasks.length), style: muted),
            ),
        ],
      ),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.medium),
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
    setState(() => _activeId = id);
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

  void _setWidth(String side, double width, double container) {
    setState(() {
      _widths = side == 'left'
          ? (left: clampSideWidth(width, _widths.right, container), right: _widths.right)
          : (left: _widths.left, right: clampSideWidth(width, _widths.left, container));
    });
  }

  void _resetWidth(String side) {
    setState(() {
      _widths = side == 'left'
          ? (left: defaultSideWidth, right: _widths.right)
          : (left: _widths.left, right: defaultSideWidth);
    });
    _storeWidths();
  }

  /// Drag handle between two columns: drag, arrow keys (Shift = bigger
  /// steps), Home or double-click resets.
  Widget _resizer(String side, double container) {
    final active = _resizing == side;
    final current = side == 'left' ? _widths.left : _widths.right;
    return Tooltip(
      message: context.l10n.protocolDragResize,
      waitDuration: const Duration(milliseconds: 800),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
          final step = HardwareKeyboard.instance.isShiftPressed ? 48.0 : 16.0;
          final grow = side == 'left' ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft;
          final shrink = side == 'left' ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight;
          if (event.logicalKey == grow) {
            _setWidth(side, current + step, container);
          } else if (event.logicalKey == shrink) {
            _setWidth(side, current - step, container);
          } else if (event.logicalKey == LogicalKeyboardKey.home) {
            _resetWidth(side);
            return KeyEventResult.handled;
          } else {
            return KeyEventResult.ignored;
          }
          _storeWidths();
          return KeyEventResult.handled;
        },
        child: Builder(builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Focus.of(context).requestFocus(),
              onDoubleTap: () => _resetWidth(side),
              onHorizontalDragStart: (_) => setState(() => _resizing = side),
              onHorizontalDragUpdate: (d) {
                final w = side == 'left' ? _widths.left + d.delta.dx : _widths.right - d.delta.dx;
                _setWidth(side, w, container);
              },
              onHorizontalDragEnd: (_) {
                setState(() => _resizing = null);
                _storeWidths();
              },
              child: SizedBox(
                width: resizerWidth,
                child: Center(
                  child: Container(
                    width: 2,
                    color: active || focused ? AppColors.primary : Theme.of(context).dividerColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Color _dotColor(String id) {
    final o = _outcomes[id];
    if (o != null) return outcomeColor(o);
    return _hasNotes(id) ? AppColors.primary : Colors.transparent;
  }

  String _dotLabel(String id) {
    final o = _outcomes[id];
    if (o != null) return outcomeLabels[o] ?? o;
    return _hasNotes(id) ? context.l10n.protocolNoted : context.l10n.protocolOpen;
  }

  Widget _sideLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, AppDimensions.paddingM, 4, 4),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.medium, letterSpacing: 0.6)),
      );

  Widget _liveBar() {
    _Section? liveSec;
    for (final s in _sections) {
      if (s.id == _live?.fieldId) liveSec = s;
    }
    if (_live == null || liveSec == null) return const SizedBox.shrink();
    final hasNext = nextSectionId(_sectionIds, _activeId) != null;
    final l10n = context.l10n;
    final label = liveSec.topNumber != null ? l10n.protocolTop(liveSec.topNumber!) : liveSec.name;
    if (context.rdSkin == null) {
      return _LiveBar(
        label: l10n.protocolRunning(label, _live!.remainingMinutes),
        nextLabel: hasNext ? l10n.protocolNextPoint : null,
        onNext: hasNext ? _nextSection : null,
      );
    }
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: ListTile(
        dense: true,
        leading: Icon(AppIcons.circle, color: AppColors.danger, size: 12),
        title: Text(l10n.protocolRunning(label, _live!.remainingMinutes)),
        trailing: hasNext ? TextButton(onPressed: _nextSection, child: IonButtonLabel(l10n.protocolNextPoint)) : null,
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final theme = Theme.of(context);
    final classic = context.rdSkin == null;
    final map = _taskSectionMap;
    _Section? active;
    for (final s in _sections) {
      if (s.id == _activeId) active = s;
    }
    _Leftover? activeLeftover;
    for (final l in _leftovers) {
      if (l.key == _activeId) activeLeftover = l;
    }

    final left = ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        // Ionic `.side-title`: 17px / 700.
        Text(_title,
            style: classic ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w700) : theme.textTheme.titleLarge),
        Text([_dateLabel, if (_timeRange.isNotEmpty) _timeRange].join(' · '), style: theme.textTheme.bodySmall),
        Text(_statusLine,
            style: theme.textTheme.bodySmall?.copyWith(color: _isPublished ? AppColors.success : AppColors.medium)),
        const SizedBox(height: AppDimensions.paddingS),
        _liveBar(),
        _sideLabel(context.l10n.protocolRunSheet),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final s in _sections)
                ListTile(
                  dense: true,
                  selected: _activeId == s.id,
                  // Ionic `.agenda-item.sel`: accent tint + 3px accent left
                  // border; `.live`: green bold time (Beta: red border).
                  selectedTileColor: classic
                      ? const Color(0x1F438E96)
                      : AppColors.primary.withValues(alpha: 0.08),
                  selectedColor: classic ? theme.colorScheme.onSurface : null,
                  shape: classic
                      ? Border(
                          left: BorderSide(
                              color: _activeId == s.id ? _protocolAccent : Colors.transparent, width: 3))
                      : (_live?.fieldId == s.id
                          ? const Border(left: BorderSide(color: AppColors.danger, width: 3))
                          : null),
                  leading: SizedBox(
                      width: 40,
                      child: Text(s.start ?? '',
                          style: classic
                              ? TextStyle(
                                  fontSize: 13,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  fontWeight: _live?.fieldId == s.id ? FontWeight.w700 : null,
                                  color: _live?.fieldId == s.id ? const Color(0xFF00815E) : AppColors.medium)
                              : theme.textTheme.bodySmall)),
                  minLeadingWidth: 40,
                  title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: (s.conductor != null || s.duration > 0)
                      ? Text([s.conductor, if (s.duration > 0) context.l10n.planningMinShort(s.duration)]
                          .whereType<String>()
                          .join(' · '))
                      : null,
                  trailing: Tooltip(
                    message: _dotLabel(s.id),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _dotColor(s.id),
                        border: Border.all(color: _outcomes[s.id] != null ? _dotColor(s.id) : AppColors.medium),
                      ),
                    ),
                  ),
                  onTap: () => _activate(s.id, focus: true),
                ),
              for (final l in _leftovers)
                ListTile(
                  dense: true,
                  selected: _activeId == l.key,
                  leading: SizedBox(width: 40, child: Icon(AppIcons.archiveOutlined, size: 18)),
                  minLeadingWidth: 40,
                  title: Text(l.title),
                  subtitle: Text(context.l10n.protocolMoreNotes),
                  onTap: () => _activate(l.key),
                ),
              ListTile(
                dense: true,
                leading: SizedBox(
                    width: 40,
                    child: Icon(AppIcons.add, size: 18, color: classic ? _protocolAccent : AppColors.primary)),
                minLeadingWidth: 40,
                // Ionic `.agenda-item.add`: accent / 600.
                title: Text(context.l10n.protocolPoint,
                    style: classic
                        ? const TextStyle(color: _protocolAccent, fontWeight: FontWeight.w600)
                        : const TextStyle(color: AppColors.primary)),
                onTap: _addSpontaneousTopic,
              ),
            ],
          ),
        ),
        _sideLabel(context.l10n.protocolPresent),
        _attendeeRow(),
        const SizedBox(height: AppDimensions.paddingM),
        FilledButton(
          onPressed: _openPublish,
          child: IonButtonLabel(_isPublished
              ? context.l10n.protocolRepublish
              : (ref.watch(redesignEnabledProvider) ? context.l10n.rdTeamFinishMeeting : context.l10n.protocolPublish)),
        ),
      ],
    );

    Widget main;
    if (active != null) {
      final s = active;
      final kicker = [
        if (s.topNumber != null) context.l10n.protocolTop(s.topNumber!),
        if (s.start != null) s.start!,
        if (s.duration > 0) context.l10n.planningMinShort(s.duration),
      ].join(' · ');
      main = Padding(
        // Ionic `.main`: padding 24 28 16 on the card colour.
        padding: classic ? const EdgeInsets.fromLTRB(28, 24, 28, 16) : const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kicker.isNotEmpty)
              Text(kicker,
                  style: classic
                      ? const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.44, color: _protocolAccent)
                      : theme.textTheme.labelMedium?.copyWith(color: AppColors.medium)),
            // Ionic `.main-head h1`: 26px / 700, margin 4 0 12.
            if (classic)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(s.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              )
            else
              Text(s.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppDimensions.paddingS),
            Wrap(
              spacing: AppDimensions.paddingM,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Ionic `.main-head .outcome-seg { min-width: 320px }`.
                if (s.isTop && classic) SizedBox(width: 320, child: _outcomeSelector(s.id))
                else if (s.isTop) _outcomeSelector(s.id),
                if (s.conductor != null)
                  Text(context.l10n.protocolResponsible(s.conductor!), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Expanded(
              child: ListView(
                children: [
                  ProtocolEditor(
                    key: ValueKey('wide-editor-${s.id}'),
                    controller: _controllerFor(s.id),
                    focusNode: _focusFor(s.id),
                    minHeight: 260,
                    onNextPoint: _nextSection,
                    onPreviousPoint: _previousSection,
                    taskStatuses: _taskStatuses,
                    agendaItems: _openTopics,
                    onCreateTask: () => _createTask(s.id),
                    onOpenTask: (id) => context.push('/settings/tasks/$id'),
                    onOpenTopic: (id) => context.push('/settings/agenda-items/$id'),
                  ),
                  _taskList(_tasksFor(s.id, map)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.paddingS),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _createTask(s.id),
                    icon: Icon(AppIcons.addCircleOutline),
                    label: IonButtonLabel(context.l10n.tasksTask),
                  ),
                  const SizedBox(width: AppDimensions.paddingM),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(context.l10n.protocolShortcutNext, style: theme.textTheme.labelSmall),
                  ),
                  const SizedBox(width: 6),
                  Text(context.l10n.protocolNextPoint, style: theme.textTheme.bodySmall),
                  const Spacer(),
                  if (_savingCount > 0)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(width: 12, height: 12, child: AppSpinner(strokeWidth: 2)),
                    ),
                  Flexible(child: Text(_saveLabel, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (activeLeftover != null) {
      final l = activeLeftover;
      main = ListView(
        padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
        children: [
          Text(context.l10n.protocolMoreNotes, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.medium)),
          Text(l.title, style: theme.textTheme.headlineSmall),
          Text(context.l10n.protocolNotInPlan,
              style: theme.textTheme.bodySmall),
          const SizedBox(height: AppDimensions.paddingS),
          _editor(_controllerFor('leftover:${l.key}', readOnly: true, initialDoc: l.doc), editable: false),
          _taskList(_tasksFor(l.key, map)),
        ],
      );
    } else {
      main = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.list, size: 56, color: AppColors.medium),
            const SizedBox(height: AppDimensions.paddingS),
            Text(_sections.isNotEmpty ? context.l10n.protocolFlutterChooseLeft : context.l10n.protocolFlutterPlanEmptyShort,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDimensions.paddingS),
            OutlinedButton(onPressed: _addSpontaneousTopic, child: IonButtonLabel(context.l10n.protocolAddPoint)),
          ],
        ),
      );
    }

    final right = ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        Row(
          children: [
            Expanded(child: Text(context.l10n.protocolGeneralNotes, style: theme.textTheme.titleMedium)),
            IconButton(
              tooltip: context.l10n.protocolGeneralTask,
              icon: Icon(AppIcons.addCircleOutline, color: AppColors.primary),
              onPressed: () => _createTask(protocolGeneralSectionId),
            ),
          ],
        ),
        Text(context.l10n.protocolAlwaysVisible, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppDimensions.paddingS),
        ProtocolEditor(
          key: const ValueKey('wide-editor-general'),
          controller: _controllerFor(protocolGeneralSectionId),
          focusNode: _focusFor(protocolGeneralSectionId),
          onNextPoint: _nextSection,
          onPreviousPoint: _previousSection,
          taskStatuses: _taskStatuses,
          agendaItems: _openTopics,
          onCreateTask: () => _createTask(protocolGeneralSectionId),
          onOpenTask: (id) => context.push('/settings/tasks/$id'),
          onOpenTopic: (id) => context.push('/settings/agenda-items/$id'),
        ),
        _sideLabel(context.l10n.protocolSessionTasks(_tasks.length)),
        if (_tasks.isEmpty)
          Text(context.l10n.protocolNoTasksYet, style: theme.textTheme.bodySmall)
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final t in _tasks)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      t.status == 'completed' ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
                      color: t.status == 'completed' ? AppColors.success : AppColors.medium,
                    ),
                    title: Text(
                      t.title,
                      style: t.status == 'completed' ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                    ),
                    subtitle: Text([
                      _sectionLabelOfTask(t, map),
                      t.responsiblePerson?.firstName,
                    ].whereType<String>().where((x) => x.isNotEmpty).join(' · ')),
                    onTap: () => context.push('/settings/tasks/${t.id}'),
                  ),
              ],
            ),
          ),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      final container = constraints.maxWidth;
      final leftW = clampSideWidth(_widths.left, _widths.right, container);
      final rightW = clampSideWidth(_widths.right, leftW, container);
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
              SizedBox(width: leftW, child: left),
              _resizer('left', container),
              // Ionic `.main`: white `--protocol-card` surface.
              Expanded(child: classic ? ColoredBox(color: ionItemBackground(context), child: main) : main),
              _resizer('right', container),
              SizedBox(width: rightW, child: right),
            ],
          ),
        ),
      );
    });
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
    final classic = context.rdSkin == null;
    // Ionic `.card.padded` (radius 20, no shadow) / Beta: the theme card.
    Widget card(Widget child) => classic
        ? _ProtocolCard(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), child: child)
        : Card(child: Padding(padding: const EdgeInsets.all(AppDimensions.paddingM), child: child));
    // Ionic `.card-label` 13px / 600 grey, `.read-title` 17px / 600.
    final cardLabel = classic
        ? const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.medium)
        : theme.textTheme.titleSmall;
    final readTitle = classic ? const TextStyle(fontSize: 17, fontWeight: FontWeight.w600) : theme.textTheme.titleMedium;
    Widget pill(String name, {bool muted = false}) => classic
        ? _NamePill(name, muted: muted)
        : Chip(label: Text(name, style: muted ? const TextStyle(color: AppColors.medium) : null));
    final list = ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        if (context.rdSkin == null) ...[
          // Ionic `.read-head h1`: 26px / 700.
          Text(_title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text([_dateLabel, if (_timeRange.isNotEmpty) context.l10n.attendanceTimeOClock(_timeRange)].join(' · '),
              style: const TextStyle(fontSize: 13, color: AppColors.medium)),
        ],
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
                  if (classic) const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: classic ? 6 : 4, children: [
                    for (final a in att.present) pill(a.name),
                  ]),
                  if (att.excused.isNotEmpty) ...[
                    SizedBox(height: classic ? 12 : AppDimensions.paddingS),
                    Text(context.l10n.protocolExcusedList(att.excused.length), style: cardLabel),
                    if (classic) const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: classic ? 6 : 4, children: [
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
                          style: classic ? _kickerStyle : theme.textTheme.labelSmall),
                    Row(children: [
                      Expanded(child: Text(s.name, style: readTitle)),
                      if (_outcomes[s.id] != null)
                        TeamOrgBadge(
                            label: outcomeLabels[_outcomes[s.id]] ?? '', color: outcomeColor(_outcomes[s.id])),
                    ]),
                    if (_hasNotes(s.id))
                      _editor(_controllerFor(s.id, readOnly: true), editable: false)
                    else if (_tasksFor(s.id, map).isEmpty)
                      Text(context.l10n.protocolNoNotes, style: const TextStyle(color: AppColors.medium)),
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
    if (!classic) return list;
    // Ionic `.read { max-width: 760px; margin: 0 auto }`.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: list),
    );
  }
}


/// Ionic `--protocol-accent`.
const Color _protocolAccent = Color(0xFF3B7D84);

/// DAS-21: Ionic `.outcome-seg` – a full-width pill track
/// (`rgba(118,118,128,.12)`, radius 999, padding 3) with three equal
/// 13px / 600 buttons; the selected one is solid (decided #00815e,
/// discussed accent, postponed #b25d00) with white text.
class _OutcomeSegment extends StatelessWidget {
  const _OutcomeSegment({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _colors = {
    'decided': Color(0xFF00815E),
    'discussed': _protocolAccent,
    'postponed': Color(0xFFB25D00),
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: context.l10n.protocolOutcome,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x1F767680),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (final o in const ['discussed', 'decided', 'postponed'])
              Expanded(
                child: Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: value == o,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(o),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: value == o ? _colors[o] : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        outcomeLabels[o]!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value == o ? Colors.white : text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// DAS-22: Ionic `.live-bar` – green pill (success 12 %, radius 16,
/// padding 6 6 6 14) with the pulsing 8px dot, success-shade 14px / 600
/// text and a small clear "Nächster Punkt" button.
class _LiveBar extends StatefulWidget {
  const _LiveBar({required this.label, this.nextLabel, this.onNext});

  final String label;
  final String? nextLabel;
  final VoidCallback? onNext;

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
            if (widget.onNext != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _shade,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: widget.onNext,
                child: IonButtonLabel(widget.nextLabel ?? ''),
              ),
          ],
        ),
      ),
    );
  }
}


/// Ionic `.kicker`: 11px / 700, uppercase, accent.
const TextStyle _kickerStyle =
    TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.44, color: _protocolAccent);

/// DAS-23/DAS-26: Ionic `.card` of the protocol page – `--protocol-card`
/// (item background), radius 20, no shadow, 10px below.
class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.child, this.padding = EdgeInsets.zero, this.ring});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Ionic `.card.active` / `.card.live`: 2px inset ring.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ionItemBackground(context),
        borderRadius: BorderRadius.circular(20),
        border: ring != null ? Border.all(color: ring!, width: 2) : null,
      ),
      child: Material(type: MaterialType.transparency, child: Padding(padding: padding, child: child)),
    );
  }
}

/// DAS-26: Ionic `.chip` – 13px name pill (padding 4 10, radius 999, light
/// grey, no border); `.muted` greys the text.
class _NamePill extends StatelessWidget {
  const _NamePill(this.name, {this.muted = false});

  final String name;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(name, style: TextStyle(fontSize: 13, color: muted ? AppColors.medium : null)),
    );
  }
}
