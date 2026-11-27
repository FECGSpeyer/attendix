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

part 'protocol_page_beta.dart';
part 'protocol_page_layouts.dart';
part 'protocol_page_panes.dart';
part 'protocol_page_publish.dart';

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
  void _update(VoidCallback fn) => setState(fn);

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
}
