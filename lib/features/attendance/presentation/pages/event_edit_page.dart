import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/enums.dart' show AttendanceStatus;
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/offline_queue_service.dart';
import '../../../../core/providers/debug_providers.dart';
import '../../../../core/theme/design_theme.dart';
import '../../../../core/utils/attendance_logic_utils.dart' show defaultDeadline;
import '../../../../core/utils/demo_guard.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../core/utils/event_list_utils.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/utils/plan_utils.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart' show showAppDatePicker, showAppTimePicker;
import '../attendance_permissions.dart'
    show isDeadlineReadonly;
import '../attendance_status_labels.dart' show ionicStatusLabel;
import '../widgets/attendance_date_change.dart';
import '../widgets/attendance_detail/attendance_detail_sheets.dart'
    show showFilesFolderPicker;
import '../widgets/attendance_detail/description_attachment_sheet.dart';
import '../../../today/data/providers/today_providers.dart' show rdDeadlineLabel;
import '../../data/create_logic.dart' show rdEndAfter, rdEndBeforeStart, rdPickedTimes, rdRecentPlaces;
import '../../data/event_details_logic.dart';
import '../../data/event_phase.dart' show rdEffectiveDurationDays;
import '../../../../core/logic/type_flags.dart';
import '../../../../shared/widgets/adaptive/app_dialog.dart';
import '../widgets/event/create_sheets.dart' show showRdTypePicker;
import '../widgets/event/event_now.dart' show rdPlanMovedWithStart;
import '../../../settings/presentation/widgets/manage/manage_entries.dart' show rdManageAccessProvider;
import '../widgets/event/form_widgets.dart';
import '../../../../shared/widgets/components/components.dart';
import '../../../today/presentation/widgets/today_common.dart';

part 'event_edit_form.dart';
part 'event_edit_writes.dart';

/// Edit screen for an existing Termin: every change is saved right away
/// (text fields on blur or page close). Works, schedule, and preparation are
/// edited in the overview; event deletion sits at the bottom.
class RdEventEditPage extends ConsumerStatefulWidget {
  const RdEventEditPage({super.key, required this.attendanceId});

  final int attendanceId;

  @override
  ConsumerState<RdEventEditPage> createState() => _RdEventEditPageState();
}

class _RdEventEditPageState extends ConsumerState<RdEventEditPage> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _notes = TextEditingController();
  final _titleFocus = FocusNode();
  final _placeFocus = FocusNode();
  final _notesFocus = FocusNode();

  /// Stored values the text fields started from (null until loaded).
  String? _storedTitle;
  String? _storedPlace;
  String? _storedNotes;

  /// Text saves run one after another; each compares its value with what
  /// is stored when it runs, so the last typed value always wins.
  Future<void> _textQueue = Future.value();

  // UI_TENANT_HOIST: bound when the page opens, so text that is saved when
  // the page closes still goes to this Termin's tenant.
  late final AttendanceRepository _repo;
  late final ProviderContainer _container;

  /// #232: the acting user's session; text saved when the page closes
  /// after a sign-out or account switch is dropped, not written.
  late final OfflineWriteSession _session;

  int get _id => widget.attendanceId;

  /// Set once the Termin is deleted: nothing is written any more.
  bool _deleted = false;
  bool _typeChanging = false;

  /// The Termin's Art as last shown; a place switches its Ort on.
  AttendanceType? _type;
  late final AttendanceTypeNotifier _typeNotifier;

  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _repo = ref.read(attendanceRepositoryWithTenantProvider);
    _typeNotifier = ref.read(attendanceTypeNotifierProvider.notifier);
    _container = ProviderScope.containerOf(context, listen: false);
    _session = ref.read(offlineQueueNotifierProvider.notifier).captureWriteSession();
    for (final (focus, save) in [
      (_titleFocus, _saveTitle),
      (_placeFocus, _savePlace),
      (_notesFocus, _saveNotes),
    ]) {
      focus.addListener(() {
        if (!focus.hasFocus) save();
      });
    }
  }

  @override
  void dispose() {
    // Text typed last is saved when the page closes (no focus change).
    _saveTitle();
    _savePlace();
    _saveNotes();
    for (final c in [_title, _place, _notes]) {
      c.dispose();
    }
    for (final f in [_titleFocus, _placeFocus, _notesFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _fill(Attendance att) {
    if (_storedTitle != null) return;
    _storedTitle = att.typeInfo ?? '';
    _storedPlace = att.place ?? '';
    _storedNotes = att.notes ?? '';
    _title.text = _storedTitle!;
    _place.text = _storedPlace!;
    _notes.text = _storedNotes!;
  }

  void _done() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RedesignRoutes.event(_id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final async = ref.watch(attendanceDetailProvider(_id));
    final att = async.valueOrNull;
    final type = ref.watch(attendanceTypeForAttendanceProvider(_id)).valueOrNull;
    _type = type;

    final Widget body;
    if (att == null) {
      body = RdFormBody(
        children: [
          async.isLoading
              ? RdInfoCard(text: l10n.redesignTodayLoading, loading: true)
              : RdInfoCard(
                text: async.hasError ? l10n.redesignTodayLoadFailed : l10n.redesignEventNotFound,
                icon: Icons.error_outline,
                action: RdOutlineButton(
                  label: l10n.redesignCommonRetry,
                  onPressed: () => ref.invalidate(attendanceDetailProvider(_id)),
                ),
              ),
        ],
      );
    } else {
      _fill(att);
      body = _form(context, att, type);
    }

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RdEditTopBar(title: l10n.redesignEventEditTitle, doneKey: const Key('rd-edit-done'), onDone: _done),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
