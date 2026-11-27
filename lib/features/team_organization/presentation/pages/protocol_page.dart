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
import '../../../../shared/widgets/redesign/rd_widgets.dart';
import '../../../today/presentation/widgets/rd_today_common.dart' show RdInfoCard;
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
import '../widgets/protocol_widgets.dart';
import '../widgets/protocol_editor.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/tasks_tab.dart' show TeamOrgBadge, outcomeColor;
import '../../../../core/services/error_reporter.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../core/services/native/native_file_service.dart';

part 'protocol_page_view.dart';
part 'protocol_page_layouts.dart';
part 'protocol_page_panes.dart';
part 'protocol_page_publish.dart';
part 'protocol_page_sections.dart';

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
    return _buildView(context, wide, showFooter);
  }
}
