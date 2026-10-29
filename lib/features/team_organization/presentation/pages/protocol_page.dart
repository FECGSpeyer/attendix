import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/team_org_providers.dart';
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
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../core/services/native/native_file_service.dart'; // NATIVE_MISC
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2

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
      } catch (_) {}
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
      _subscriptions[id] = document.changes.listen((change) {
        if (change.source == ChangeSource.local) _queueSave(id);
      });
    }
    _controllers[id] = controller;
    return controller;
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
      if (mounted) setState(() => _tasks = [..._tasks, task]);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.l10n.protocolSpontaneousHint),
            TextField(
                controller: titleCtrl, decoration: InputDecoration(labelText: ctx.l10n.tasksTitle), autofocus: true),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ctx.l10n.protocolDurationMinutes),
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
    final duration = int.tryParse(durationCtrl.text.trim()) ?? defaultDuration;
    titleCtrl.dispose();
    durationCtrl.dispose();
    if (ok != true) return;
    if (title.isEmpty) {
      if (mounted) ToastHelper.showWarning(context, context.l10n.agendaEnterTitle);
      return;
    }
    try {
      final item = await ref.read(agendaItemNotifierProvider.notifier).create(AgendaItem(
            title: title,
            status: 'open',
            priority: 'medium',
            defaultDuration: duration < 1 ? 1 : duration,
          ));
      var current = _attendance!;
      try {
        final fresh = await _repo.getAttendance(widget.attendanceId);
        if (fresh != null) current = _attendance!.copyWith(plan: fresh.plan);
      } catch (_) {}
      final plan = current.plan ??
          {'time': _planStart ?? DateFormat('HH:mm').format(DateTime.now()), 'end': current.endTime ?? '', 'fields': []};
      final field = buildAgendaField(item, duration < 1 ? 1 : duration);
      final fields = insertAgendaFields(current.fields, [field]);
      final stored = await _repo.updateAttendancePlan(widget.attendanceId, {...plan, 'fields': fields});
      if (!mounted) return;
      setState(() {
        _attendance = _attendance!.copyWith(plan: stored ?? {...plan, 'fields': fields});
        _buildSections();
        _updateLive();
        _activeId = fieldId(field);
      });
      ref.invalidate(upcomingProtocolAttendancesProvider);
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

  ProtocolPdfData _buildPdfData() {
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
    );
  }

  Future<void> _sharePdf() async {
    try {
      await _flushAll();
      final bytes = await createProtocolPdf(_buildPdfData());
      final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
      final name = l10nWithoutContext
          .protocolFileName(_title, d != null ? DateFormat('yyyy-MM-dd').format(d) : '')
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
      await NativeFileService.saveBytes(bytes, '$name.pdf'); // NATIVE_MISC
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolPdfFailed);
    }
  }

  // ── Publish ────────────────────────────────────────────────

  Future<void> _openPublish() async {
    // SOL_FIX2: never offer publishing an incompletely saved protocol.
    if (!await _flushAll()) {
      if (mounted) ToastHelper.showError(context, context.l10n.protocolNotesSaveFailed);
      return;
    }
    // Other leaders may have written in other sections meanwhile.
    try {
      final row = await _repo.getProtocolForAttendance(widget.attendanceId);
      if (row != null) {
        for (final e in row.content.entries) {
          if (_controllers.containsKey(e.key) || _pending.contains(e.key) || e.value is! Map) continue;
          _docs[e.key] = Map<String, dynamic>.from(e.value as Map);
        }
        _outcomes = {for (final e in row.outcomes.entries) e.key: e.value.toString()};
      }
    } catch (_) {}

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
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
    var sendPdf = true;
    final confirmed = await showModalBottomSheet<bool>(
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
                toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
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
                          _summaryTile(Icons.check_circle, AppColors.success,
                              ctx.l10n.protocolDecidedCount(summary.decided.length),
                              summary.decided.join(', ')),
                        if (summary.discussed.isNotEmpty)
                          _summaryTile(Icons.forum_outlined, AppColors.primary,
                              ctx.l10n.protocolDiscussedCount(summary.discussed.length),
                              summary.discussed.join(', ')),
                        if (summary.postponed.isNotEmpty)
                          _summaryTile(
                              Icons.schedule,
                              AppColors.warning,
                              ctx.l10n.protocolPostponedCount(summary.postponed.length),
                              '${summary.postponed.join(', ')}${_type?.suggestPostponed == true ? ctx.l10n.protocolSuggestNext : ''}'),
                        _summaryTile(
                            Icons.check_box_outlined,
                            AppColors.medium,
                            ctx.l10n.protocolTaskCount(summary.taskCount),
                            summary.taskOwners.isNotEmpty ? ctx.l10n.protocolForNames(joinNames(summary.taskOwners)) : null),
                        if (summary.withoutOutcome.isNotEmpty)
                          _summaryTile(Icons.help_outline, AppColors.medium,
                              ctx.l10n.protocolWithoutOutcome(summary.withoutOutcome.length), summary.withoutOutcome.join(', ')),
                        if (summary.withoutNotes.isNotEmpty)
                          _summaryTile(Icons.error_outline, AppColors.warning,
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
                          Icons.visibility_outlined,
                          AppColors.medium,
                          ctx.l10n.protocolMayRead,
                          (_type?.relevantGroups?.isNotEmpty ?? false)
                              ? ctx.l10n.protocolReadGroups(_type?.name ?? '')
                              : ctx.l10n.protocolReadAll(_type?.name ?? ''),
                        ),
                        _summaryTile(
                          Icons.notifications_outlined,
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
                      icon: const Icon(Icons.send),
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
          final bytes = await createProtocolPdf(_buildPdfData());
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
          actions: [
            if (_attendance != null && !_notAvailable && !_loadFailed)
              IconButton(tooltip: context.l10n.protocolSharePdf, icon: const Icon(Icons.ios_share), onPressed: _sharePdf),
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
                              child: OutlinedButton.icon(
                                onPressed: _openGeneralNotes,
                                icon: Badge(
                                  isLabelVisible: _hasNotes(protocolGeneralSectionId),
                                  smallSize: 7,
                                  backgroundColor: AppColors.primary,
                                  child: const Icon(Icons.description_outlined),
                                ),
                                label: IonButtonLabel(context.l10n.protocolNotes),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingS),
                            Expanded(
                              child: FilledButton(
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
                ? _centerState(Icons.lock_outline, context.l10n.protocolNotPublished, context.l10n.protocolNotPublishedHint)
                : _loadFailed || _attendance == null
                    ? IonEmptyState(
                        icon: Icons.cloud_off,
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

  String _initials(ProtocolAttendee a) {
    final f = a.firstName.trim();
    final l = a.lastName.trim();
    final s = '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Future<void> _openAttendees() async {
    final att = _attendees;
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
              toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
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
              toolbarHeight: ionModalToolbarHeight(context), // PARITY_R5
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
                  StatefulBuilder(
                    builder: (ctx, _) => _taskList(_tasksFor(protocolGeneralSectionId, _taskSectionMap)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _createTask(protocolGeneralSectionId);
                      },
                      icon: const Icon(Icons.add_circle_outline),
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
              t.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
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
    return Wrap(
      spacing: 8,
      children: [
        for (final o in const ['discussed', 'decided', 'postponed'])
          ChoiceChip(
            label: Text(outcomeLabels[o]!),
            selected: current == o,
            selectedColor: outcomeColor(o).withValues(alpha: 0.25),
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
        if (_live != null && liveSec != null)
          Card(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.circle, color: AppColors.danger, size: 12),
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
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusLine)),
            ]),
          ),
        if (_sections.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Text(context.l10n.protocolPlanEmpty),
            ),
          ),
        for (final s in _sections) _sectionCard(s, map),
        TextButton.icon(
          onPressed: _addSpontaneousTopic,
          icon: const Icon(Icons.add),
          label: IonButtonLabel(context.l10n.protocolPoint),
        ),
        if (unassigned.isNotEmpty) ...[
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        side: BorderSide(
          color: isLive ? AppColors.danger : (active ? AppColors.primary : Colors.transparent),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: () => setState(() => _activeId = active ? null : s.id),
            leading: !active && _hasNotes(s.id) && outcome == null
                ? const Icon(Icons.check_circle_outline, color: AppColors.success)
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
                Icon(active ? Icons.expand_less : Icons.expand_more),
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
                      icon: const Icon(Icons.add_circle_outline),
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
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.circle, color: AppColors.danger, size: 12),
        title: Text(l10n.protocolRunning(label, _live!.remainingMinutes)),
        trailing: hasNext ? TextButton(onPressed: _nextSection, child: IonButtonLabel(l10n.protocolNextPoint)) : null,
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final theme = Theme.of(context);
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
        Text(_title, style: theme.textTheme.titleLarge),
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
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                  shape: _live?.fieldId == s.id
                      ? const Border(left: BorderSide(color: AppColors.danger, width: 3))
                      : null,
                  leading: SizedBox(width: 40, child: Text(s.start ?? '', style: theme.textTheme.bodySmall)),
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
                  leading: const SizedBox(width: 40, child: Icon(Icons.archive_outlined, size: 18)),
                  minLeadingWidth: 40,
                  title: Text(l.title),
                  subtitle: Text(context.l10n.protocolMoreNotes),
                  onTap: () => _activate(l.key),
                ),
              ListTile(
                dense: true,
                leading: const SizedBox(width: 40, child: Icon(Icons.add, size: 18, color: AppColors.primary)),
                minLeadingWidth: 40,
                title: Text(context.l10n.protocolPoint, style: const TextStyle(color: AppColors.primary)),
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
          child: IonButtonLabel(_isPublished ? context.l10n.protocolRepublish : context.l10n.protocolPublish),
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
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kicker.isNotEmpty) Text(kicker, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.medium)),
            Text(s.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppDimensions.paddingS),
            Wrap(
              spacing: AppDimensions.paddingM,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (s.isTop) _outcomeSelector(s.id),
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
                    icon: const Icon(Icons.add_circle_outline),
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
            const Icon(Icons.list, size: 56, color: AppColors.medium),
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
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
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
                      t.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
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
              Expanded(child: main),
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
    return ListView(
      padding: EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM, AppDimensions.paddingM, scrollEndPadding(context, base: AppDimensions.paddingM)),
      children: [
        Text(_title, style: theme.textTheme.headlineSmall),
        Text([_dateLabel, if (_timeRange.isNotEmpty) context.l10n.attendanceTimeOClock(_timeRange)].join(' · ')),
        if (_isPublished)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusLine)),
            ]),
          ),
        if (att.present.isNotEmpty || att.excused.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.protocolPresentList(att.present.length), style: theme.textTheme.titleSmall),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final a in att.present) Chip(label: Text(a.name)),
                  ]),
                  if (att.excused.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(context.l10n.protocolExcusedList(att.excused.length), style: theme.textTheme.titleSmall),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final a in att.excused)
                        Chip(label: Text(a.name, style: const TextStyle(color: AppColors.medium))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        for (final s in _sections)
          if (s.isTop || _hasNotes(s.id) || _outcomes[s.id] != null || _tasksFor(s.id, map).isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.topNumber != null) Text(context.l10n.protocolTop(s.topNumber!), style: theme.textTheme.labelSmall),
                    Row(children: [
                      Expanded(child: Text(s.name, style: theme.textTheme.titleMedium)),
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
            ),
        ..._leftoverWidgets(),
        if (_hasNotes(protocolGeneralSectionId) || unassigned.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.protocolGeneralNotes, style: theme.textTheme.titleMedium),
                  if (_hasNotes(protocolGeneralSectionId))
                    _editor(_controllerFor(protocolGeneralSectionId, readOnly: true), editable: false),
                  _taskList(unassigned),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppDimensions.paddingM),
        OutlinedButton.icon(
          onPressed: _sharePdf,
          icon: const Icon(Icons.ios_share),
          label: IonButtonLabel(context.l10n.protocolSharePdf),
        ),
      ],
    );
  }
}
