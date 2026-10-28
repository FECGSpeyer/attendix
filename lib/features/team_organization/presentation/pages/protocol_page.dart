import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/team_org_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/team_org/team_org.dart';
import '../../../../data/repositories/protocol_repository.dart';
import '../../protocol_pdf.dart';
import '../../team_org_utils.dart';
import '../../tiptap_delta.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, outcomeColor;

const _saveDebounce = Duration(milliseconds: 800);
const _avatarColors = [
  Color(0xFF3B7D84), Color(0xFF7B5EA7), Color(0xFFC0703A), Color(0xFF2F7D4F),
  Color(0xFFA6475F), Color(0xFF4A6FA5), Color(0xFF8A7A2F),
];
const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

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
  final Map<String, List<Map<String, dynamic>>> _refs = {};
  final Map<String, Timer> _timers = {};
  final Set<String> _pending = {};

  String? _activeId;
  int _savingCount = 0;
  DateTime? _lastSavedAt;
  DateTime _lastErrorToast = DateTime(2000);
  Timer? _liveTimer;
  ({String fieldId, int remainingMinutes})? _live;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(protocolRepositoryWithTenantProvider);
    _isLeader = ref.read(isTeamLeaderProvider);
    _load();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    // Last chance: send what is still waiting in the debounce.
    for (final id in _pending.toList()) {
      _timers[id]?.cancel();
      final doc = _currentDoc(id);
      if (doc != null) unawaited(_repo.saveSection(widget.attendanceId, id, doc: doc).catchError((_) => null));
    }
    for (final s in _subscriptions.values) {
      s.cancel();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
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
        ref.read(taskRepositoryWithTenantProvider).getTasksForAttendance(widget.attendanceId).catchError((_) => <TeamTask>[]),
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
        items = await ref.read(agendaItemRepositoryWithTenantProvider).getAgendaItemsByIds(ids);
      } catch (_) {}
    }
    _leftovers = entries.map((e) {
      String title = 'Früherer Programmpunkt';
      if (e.key.startsWith(legacy)) {
        final id = e.key.substring(legacy.length);
        title = 'Tagesordnungspunkt';
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

  QuillController _controllerFor(String id, {bool readOnly = false}) {
    final existing = _controllers[id];
    if (existing != null) return existing;
    final parts = tiptapToDelta(_docs[id]);
    _refs[id] = parts.refs;
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
    if (c == null) return _docs[id];
    return deltaToTiptap(c.document.toDelta().toJson(), _refs[id] ?? const []);
  }

  void _queueSave(String id) {
    _pending.add(id);
    _timers[id]?.cancel();
    _timers[id] = Timer(_saveDebounce, () => _flush(id));
  }

  Future<void> _flush(String id) async {
    _timers.remove(id)?.cancel();
    if (!_pending.remove(id)) return;
    final doc = _currentDoc(id);
    if (doc == null) return;
    setState(() {
      _docs[id] = doc;
      _savingCount++;
    });
    try {
      final row = await _repo.saveSection(widget.attendanceId, id, doc: doc);
      _applyRow(row);
      _lastSavedAt = DateTime.now();
    } catch (_) {
      _pending.add(id);
      if (mounted && DateTime.now().difference(_lastErrorToast).inSeconds > 10) {
        _lastErrorToast = DateTime.now();
        ToastHelper.showError(context, 'Notizen konnten nicht gespeichert werden. Prüfe deine Verbindung.');
      }
    } finally {
      if (mounted) setState(() => _savingCount--);
    }
  }

  Future<void> _flushAll() async {
    if (!_isLeader) return;
    await Future.wait(_pending.toList().map(_flush));
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
      if (mounted) ToastHelper.showError(context, 'Ergebnis konnte nicht gespeichert werden');
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
      final refs = _refs[id];
      final refIds = refs != null
          ? refs.where((r) => r['type'] == 'taskRef').map((r) => (r['attrs'] as Map?)?['id']?.toString())
          : taskRefIds(_docs[id]);
      for (final tid in refIds.whereType<String>()) {
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
      if (mounted) ToastHelper.showError(context, 'Protokoll konnte nicht angelegt werden');
      return;
    }
    if (!mounted) return;
    final task = await showTaskFormSheet(
      context,
      attendanceId: widget.attendanceId,
      protocolId: protocolId,
      agendaItemId: section?.agendaItemId,
      contextLabel: section?.title ?? 'Allgemeine Notizen',
    );
    if (task?.id == null || !mounted) return;
    // Put a task reference into the section's notes so it maps to the section.
    _controllerFor(sectionId);
    (_refs[sectionId] ??= []).add(taskRefNode(id: task!.id!, title: task.title, status: task.status));
    _pending.add(sectionId);
    await _flush(sectionId);
    try {
      final tasks = await ref.read(taskRepositoryWithTenantProvider).getTasksForAttendance(widget.attendanceId);
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spontaner Punkt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Wird als neues Thema angelegt und im Ablaufplan ergänzt.'),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titel'), autofocus: true),
            TextField(
              controller: durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Dauer in Minuten'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Hinzufügen')),
        ],
      ),
    );
    final title = titleCtrl.text.trim();
    final duration = int.tryParse(durationCtrl.text.trim()) ?? defaultDuration;
    titleCtrl.dispose();
    durationCtrl.dispose();
    if (ok != true) return;
    if (title.isEmpty) {
      if (mounted) ToastHelper.showWarning(context, 'Bitte einen Titel eingeben');
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
      if (mounted) ToastHelper.showError(context, 'Punkt konnte nicht hinzugefügt werden');
    }
  }

  // ── Display helpers ────────────────────────────────────────

  String get _title => attendanceTitle(_attendance?.typeInfo, _type) == 'Termin'
      ? 'Protokoll'
      : attendanceTitle(_attendance?.typeInfo, _type);

  String get _dateLabel {
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    return d == null ? '' : '${_weekdays[d.weekday - 1]}, ${DateFormat('dd.MM.yyyy').format(d)}';
  }

  String get _shortDate {
    final d = DateTime.tryParse(_attendance?.date ?? '')?.toLocal();
    return d == null ? '' : DateFormat('dd.MM.').format(d);
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
    if (!_isPublished) return 'Entwurf';
    final fmt = DateFormat('dd.MM.yyyy');
    final pub = DateTime.tryParse(_protocol?.publishedAt ?? '')?.toLocal();
    var line = 'Freigegeben am ${pub != null ? fmt.format(pub) : ''}';
    if (isEditedAfterPublish(_protocol)) {
      final upd = DateTime.tryParse(_protocol!.updatedAt!)?.toLocal();
      line = '$line · geändert am ${upd != null ? fmt.format(upd) : ''}';
    }
    return line;
  }

  String get _saveLabel {
    if (_savingCount > 0) return 'Speichert …';
    if (_lastSavedAt != null) return 'Automatisch gespeichert · ${DateFormat('HH:mm').format(_lastSavedAt!)}';
    return _isPublished ? 'Änderungen werden automatisch gespeichert' : 'Wird automatisch gespeichert';
  }

  bool _hasNotes(String id) {
    final c = _controllers[id];
    if (c != null && c.document.toPlainText().trim().isNotEmpty) return true;
    return !isDocEmpty(_docs[id]);
  }

  String _sectionMeta(_Section s) =>
      [s.start, if (s.duration > 0) '${s.duration} min', s.conductor].whereType<String>().where((x) => x.isNotEmpty).join(' · ');

  String _taskLine(TeamTask t) {
    final parts = <String>[];
    if (t.responsiblePerson.fullName.isNotEmpty) parts.add(t.responsiblePerson.fullName);
    final due = DateTime.tryParse(t.dueDate ?? '');
    if (due != null) parts.add('fällig ${DateFormat('dd.MM.').format(due)}');
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
    final dueFmt = DateFormat('dd.MM.yyyy');
    String taskText(TeamTask t) {
      final parts = [t.title];
      if (t.responsiblePerson.fullName.isNotEmpty) parts.add(t.responsiblePerson.fullName);
      final due = DateTime.tryParse(t.dueDate ?? '');
      if (due != null) parts.add('fällig ${dueFmt.format(due)}');
      if (t.status == 'completed') parts.add('erledigt');
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
        ProtocolPdfSection(title: 'Weitere Notizen · ${l.title}', doc: l.doc, tasks: _tasksFor(l.key, map).map(taskText).toList()),
    ];
    final leftoverKeys = _leftovers.map((l) => l.key).toSet();
    final other = _tasks.where((t) {
      final id = map[t.id];
      return id == null || (!_sections.any((s) => s.id == id) && !leftoverKeys.contains(id));
    }).toList();
    return ProtocolPdfData(
      title: 'Protokoll · $_title',
      subtitle: [_dateLabel, if (_timeRange.isNotEmpty) '$_timeRange Uhr'].join(' · '),
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
      final name = 'Protokoll $_title ${d != null ? DateFormat('yyyy-MM-dd').format(d) : ''}'
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
      await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'PDF konnte nicht erstellt werden');
    }
  }

  // ── Publish ────────────────────────────────────────────────

  Future<void> _openPublish() async {
    await _flushAll();
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
        final items = await ref.read(agendaItemRepositoryWithTenantProvider).getAgendaItemsByIds(agendaIds);
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: Column(
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                leading: TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                leadingWidth: 100,
                title: const Text('Protokoll freigeben'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  children: [
                    Text('Zusammenfassung', style: Theme.of(ctx).textTheme.titleSmall),
                    Card(
                      child: Column(children: [
                        if (summary.decided.isNotEmpty)
                          _summaryTile(Icons.check_circle, AppColors.success,
                              '${summary.decided.length} ${summary.decided.length == 1 ? 'Thema' : 'Themen'} beschlossen',
                              summary.decided.join(', ')),
                        if (summary.discussed.isNotEmpty)
                          _summaryTile(Icons.forum_outlined, AppColors.primary,
                              '${summary.discussed.length} ${summary.discussed.length == 1 ? 'Thema' : 'Themen'} besprochen',
                              summary.discussed.join(', ')),
                        if (summary.postponed.isNotEmpty)
                          _summaryTile(
                              Icons.schedule,
                              AppColors.warning,
                              '${summary.postponed.length} ${summary.postponed.length == 1 ? 'Thema' : 'Themen'} vertagt',
                              '${summary.postponed.join(', ')}${_type?.suggestPostponed == true ? ' · wird beim nächsten Termin vorgeschlagen' : ''}'),
                        _summaryTile(
                            Icons.check_box_outlined,
                            AppColors.medium,
                            '${summary.taskCount} ${summary.taskCount == 1 ? 'Aufgabe' : 'Aufgaben'}',
                            summary.taskOwners.isNotEmpty ? 'für ${joinNames(summary.taskOwners)}' : null),
                        if (summary.withoutOutcome.isNotEmpty)
                          _summaryTile(Icons.help_outline, AppColors.medium,
                              'Ohne Ergebnis: ${summary.withoutOutcome.length}', summary.withoutOutcome.join(', ')),
                        if (summary.withoutNotes.isNotEmpty)
                          _summaryTile(Icons.error_outline, AppColors.warning,
                              'Noch ohne Notizen: ${summary.withoutNotes.length}', summary.withoutNotes.join(', ')),
                      ]),
                    ),
                    if (closures.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.paddingS),
                      Text('Themen als erledigt markieren', style: Theme.of(ctx).textTheme.titleSmall),
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
                    Text('Sichtbarkeit', style: Theme.of(ctx).textTheme.titleSmall),
                    Card(
                      child: Column(children: [
                        _summaryTile(
                          Icons.visibility_outlined,
                          AppColors.medium,
                          'Lesen dürfen',
                          (_type?.relevantGroups?.isNotEmpty ?? false)
                              ? 'die Gruppen aus dem Termintyp „${_type?.name ?? ''}“'
                              : 'alle Mitglieder (Termintyp „${_type?.name ?? ''}“ hat keine Gruppen)',
                        ),
                        _summaryTile(
                          Icons.notifications_outlined,
                          AppColors.medium,
                          'Benachrichtigt werden',
                          '${summary.recipientCount} Anwesende${summary.taskOwners.isNotEmpty ? ' · ${summary.taskOwners.length} ${summary.taskOwners.length == 1 ? 'Person' : 'Personen'} mit Aufgaben' : ''}',
                        ),
                        SwitchListTile(
                          value: sendPdf,
                          onChanged: (v) => setLocal(() => sendPdf = v),
                          title: const Text('Protokoll als PDF mitschicken'),
                          subtitle: const Text('Per Telegram als Dokument'),
                        ),
                      ]),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingS),
                      child: Text(
                          'Die Leitung kann das Protokoll auch nach der Freigabe noch bearbeiten. Änderungen werden mit Datum angezeigt.'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.send),
                      label: Text(_isPublished ? 'Erneut freigeben & benachrichtigen' : 'Freigeben & benachrichtigen'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(_isPublished ? 'Abbrechen' : 'Als Entwurf lassen'),
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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _flushAll();
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
        ToastHelper.showWarning(context, 'Nicht alle Themen konnten als erledigt markiert werden');
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
            ToastHelper.showWarning(context, 'PDF konnte nicht erstellt werden, die Benachrichtigung geht ohne PDF raus');
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
      if (mounted) ToastHelper.showSuccess(context, 'Protokoll freigegeben');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Protokoll konnte nicht freigegeben werden');
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
    final showFooter = _isLeader && !_loading && !_loadFailed && !_notAvailable && _attendance != null;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_flushAll());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Protokoll'),
              if (_attendance != null && !_notAvailable)
                Text(
                  '$_title · $_shortDate · ${_isPublished ? 'Freigegeben' : 'Entwurf'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          actions: [
            if (_attendance != null && !_notAvailable && !_loadFailed)
              IconButton(tooltip: 'Als PDF teilen', icon: const Icon(Icons.ios_share), onPressed: _sharePdf),
          ],
        ),
        bottomNavigationBar: showFooter
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
                  child: Row(
                    children: [
                      if (_savingCount > 0)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      Expanded(child: Text(_saveLabel, style: Theme.of(context).textTheme.bodySmall)),
                      OutlinedButton.icon(
                        onPressed: _openGeneralNotes,
                        icon: Badge(
                          isLabelVisible: _hasNotes(protocolGeneralSectionId),
                          smallSize: 8,
                          child: const Icon(Icons.description_outlined),
                        ),
                        label: const Text('Notizen'),
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      FilledButton(
                        onPressed: _openPublish,
                        child: Text(_isPublished ? 'Erneut freigeben' : 'Freigeben'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notAvailable
                ? _centerState(Icons.lock_outline, 'Dieses Protokoll ist noch nicht freigegeben.',
                    'Sobald die Leitung es freigibt, kannst du es hier lesen.')
                : _loadFailed || _attendance == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off, size: 56, color: AppColors.medium),
                            const SizedBox(height: AppDimensions.paddingM),
                            const Text('Protokoll konnte nicht geladen werden.'),
                            OutlinedButton(onPressed: _load, child: const Text('Erneut versuchen')),
                          ],
                        ),
                      )
                    : _isLeader
                        ? _buildEditLayout(context)
                        : _buildReadLayout(context),
      ),
    );
  }

  Widget _centerState(IconData icon, String title, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.medium),
              const SizedBox(height: AppDimensions.paddingM),
              Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
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
        title: Text('${att.present.length} anwesend'),
        subtitle: Text('${att.excused.isNotEmpty ? '${att.excused.length} entschuldigt · ' : ''}aus der Anwesenheit'),
        trailing: const Icon(Icons.chevron_right),
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Teilnehmende'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fertig'))],
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(title: Text('Anwesend (${att.present.length})', style: Theme.of(ctx).textTheme.titleSmall)),
                  for (final a in att.present)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _avatarColors[(a.personId ?? 0) % _avatarColors.length],
                        child: Text(_initials(a), style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(a.name),
                    ),
                  if (att.present.isEmpty)
                    const ListTile(
                        title: Text('Niemand als anwesend eingetragen', style: TextStyle(color: AppColors.medium))),
                  if (att.excused.isNotEmpty) ...[
                    ListTile(
                        title: Text('Entschuldigt (${att.excused.length})', style: Theme.of(ctx).textTheme.titleSmall)),
                    for (final a in att.excused)
                      ListTile(
                        leading: CircleAvatar(child: Text(_initials(a))),
                        title: Text(a.name),
                        subtitle: a.notes?.isNotEmpty == true ? Text(a.notes!) : null,
                      ),
                  ],
                  if (att.others.isNotEmpty) ...[
                    ListTile(
                        title: Text('Nicht da / offen (${att.others.length})',
                            style: Theme.of(ctx).textTheme.titleSmall)),
                    for (final a in att.others)
                      ListTile(title: Text(a.name, style: const TextStyle(color: AppColors.medium))),
                  ],
                  const Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingM),
                    child: Text('Die Liste kommt aus der Anwesenheit des Termins.'),
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Allgemeine Notizen'),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fertig'))],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                children: [
                  const Text('Gilt für die ganze Sitzung, unabhängig vom Punkt.'),
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
                      label: const Text('Aufgabe'),
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

  Widget _editor(QuillController controller, {bool editable = true}) {
    if (!editable || controller.readOnly) {
      return QuillEditor.basic(
        controller: controller,
        config: const QuillEditorConfig(showCursor: false, scrollable: false),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuillSimpleToolbar(
          controller: controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showStrikeThrough: true,
            showColorButton: false,
            showBackgroundColorButton: false,
            showInlineCode: false,
            showCodeBlock: false,
            showLink: true,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            showFontFamily: false,
            showFontSize: false,
            showHeaderStyle: true,
            showListNumbers: true,
            showListBullets: true,
            showListCheck: true,
            showQuote: true,
            showIndent: true,
            showAlignmentButtons: false,
            showDirection: false,
            showUndo: true,
            showRedo: true,
            showClearFormat: false,
            showDividers: false,
            showSmallButton: false,
            showLineHeightButton: false,
            showClipboardCut: false,
            showClipboardCopy: false,
            showClipboardPaste: false,
          ),
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 140),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: QuillEditor.basic(
            controller: controller,
            config: const QuillEditorConfig(
              scrollable: false,
              placeholder: 'Notizen …',
              padding: EdgeInsets.all(AppDimensions.paddingS),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        _attendeeRow(),
        if (_live != null && liveSec != null)
          Card(
            color: AppColors.danger.withValues(alpha: 0.08),
            child: ListTile(
              leading: const Icon(Icons.circle, color: AppColors.danger, size: 12),
              title: Text(
                  'Läuft: ${liveSec.topNumber != null ? 'TOP ${liveSec.topNumber}' : liveSec.name} · noch ${_live!.remainingMinutes} min'),
              trailing: hasNext
                  ? TextButton(
                      onPressed: () => setState(() => _activeId = _sections[activeIndex + 1].id),
                      child: const Text('Nächster Punkt'),
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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingM),
              child: Text('Der Ablaufplan ist noch leer. Füge einen Punkt hinzu oder schreib in die Notizen.'),
            ),
          ),
        for (final s in _sections) _sectionCard(s, map),
        TextButton.icon(
          onPressed: _addSpontaneousTopic,
          icon: const Icon(Icons.add),
          label: const Text('Punkt'),
        ),
        if (unassigned.isNotEmpty) ...[
          Text('Weitere Aufgaben dieser Sitzung', style: Theme.of(context).textTheme.titleSmall),
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
                      Text('TOP ${s.topNumber}${s.start != null ? ' · ${s.start}' : ''}',
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
                  Padding(padding: const EdgeInsets.only(left: 6), child: Text('${s.duration} min')),
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
                      label: const Text('Aufgabe'),
                    ),
                  ),
                ],
              ),
            )
          else if (tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingS),
              child: Text('${tasks.length} ${tasks.length == 1 ? 'Aufgabe' : 'Aufgaben'}',
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
      Text('Weitere Notizen', style: Theme.of(context).textTheme.titleSmall),
      const Text('Notizen zu Punkten, die nicht mehr im Ablaufplan stehen.'),
      for (final l in _leftovers)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, style: Theme.of(context).textTheme.titleSmall),
                _editor(_controllerFor('leftover:${l.key}', readOnly: true), editable: false),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _buildReadLayout(BuildContext context) {
    final theme = Theme.of(context);
    final map = _taskSectionMap;
    final att = _attendees;
    final unassigned = _unassignedTasks(map);
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        Text(_title, style: theme.textTheme.headlineSmall),
        Text([_dateLabel, if (_timeRange.isNotEmpty) '$_timeRange Uhr'].join(' · ')),
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
                  Text('Anwesend (${att.present.length})', style: theme.textTheme.titleSmall),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final a in att.present) Chip(label: Text(a.name)),
                  ]),
                  if (att.excused.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.paddingS),
                    Text('Entschuldigt (${att.excused.length})', style: theme.textTheme.titleSmall),
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
                    if (s.topNumber != null) Text('TOP ${s.topNumber}', style: theme.textTheme.labelSmall),
                    Row(children: [
                      Expanded(child: Text(s.name, style: theme.textTheme.titleMedium)),
                      if (_outcomes[s.id] != null)
                        TeamOrgBadge(
                            label: outcomeLabels[_outcomes[s.id]] ?? '', color: outcomeColor(_outcomes[s.id])),
                    ]),
                    if (_hasNotes(s.id))
                      _editor(_controllerFor(s.id, readOnly: true), editable: false)
                    else if (_tasksFor(s.id, map).isEmpty)
                      const Text('Keine Notizen', style: TextStyle(color: AppColors.medium)),
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
                  Text('Allgemeine Notizen', style: theme.textTheme.titleMedium),
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
          label: const Text('Als PDF teilen'),
        ),
      ],
    );
  }
}
