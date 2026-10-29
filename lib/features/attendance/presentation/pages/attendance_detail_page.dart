import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/attendance_detail_providers.dart';
import '../../../../core/providers/church_providers.dart'; // ATT_DETAIL
import '../../../../core/providers/group_providers.dart'; // ATT_DETAIL
import '../../../../core/providers/team_org_providers.dart' show protocolTypeByIdProvider; // IOS_DETAIL
import '../../../../core/providers/profile_providers.dart'; // ATT_DETAIL
import '../../../../core/utils/shift_utils.dart'; // ATT_DETAIL
import '../../../../core/providers/shift_providers.dart'; // LOGIC_ATT
import '../../../../core/providers/player_absence_providers.dart'; // LOGIC_ATT
import '../../../../core/utils/attendance_logic_utils.dart'; // LOGIC_ATT
import '../../../../data/models/player_absence/player_absence.dart'; // LOGIC_ATT
import '../../../../data/models/shift/shift_plan.dart'; // LOGIC_ATT
import '../../../../shared/widgets/sheets/church_overview_sheet.dart'; // ATT_DETAIL
import '../widgets/attendance_detail/ad_hoc_reminder_sheet.dart'; // ATT_DETAIL
import '../widgets/attendance_detail/add_persons_sheet.dart'; // ATT_DETAIL
import '../widgets/attendance_detail/attendance_view_options.dart'; // ATT_DETAIL
import '../widgets/attendance_detail/description_attachment_sheet.dart'; // ATT_DETAIL
import 'package:shared_preferences/shared_preferences.dart'; // ATT_DETAIL
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/debug_providers.dart'; // ORG_PLANS
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/role_permission_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../data/repositories/attendance_repository.dart'; // UI_TENANT_HOIST
import '../../../../core/services/export_service.dart';
import '../../../../core/services/offline_queue_service.dart'; // PROFILE_OFFLINE
import '../../../../core/services/telegram_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/church/church.dart'; // ATT_DETAIL
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
import '../../../../shared/widgets/event_list/event_list_widgets.dart';
import '../../../../shared/widgets/event_list/excuse_reason_sheet.dart';
import '../../../../shared/widgets/layout/ionic_ios.dart' show IonIos; // PARITY_R3
import '../../../../shared/widgets/layout/ionic_md.dart' show IonMd; // PARITY_R9
import '../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../../../duty/presentation/widgets/duty_staffing_section.dart';
import '../widgets/attendance_detail/attendance_detail_widgets.dart';
import '../widgets/ios_condense_header.dart'; // UX_ATT
import '../widgets/attendance_legend_sheet.dart';
import '../widgets/attendance_status_overview_sheet.dart';
import '../widgets/songs_selection_sheet.dart';
import '../../../../core/utils/demo_guard.dart';
import '../../../team_organization/presentation/widgets/attendance_protocol_section.dart'; // PROTOCOL
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK
import '../../../../shared/widgets/display/ion_badge_text.dart'; // PARITY_R8

/// Attendance detail/taking page
class AttendanceDetailPage extends ConsumerStatefulWidget {
  const AttendanceDetailPage({super.key, required this.attendanceId});

  final int attendanceId;

  @override
  ConsumerState<AttendanceDetailPage> createState() => _AttendanceDetailPageState();
}

class _AttendanceDetailPageState extends ConsumerState<AttendanceDetailPage> {
  // ARCHITECTURE: Two complementary sync mechanisms:
  // 1. _personAttChannel (Supabase realtime): instant updates from Postgres
  //    change payloads — avoids full refetch for individual status changes.
  // 2. _providerSubscription (Riverpod listenManual): full dataset sync after
  //    provider invalidation — catches additions/deletions.
  // Both check _savingPersonIds to avoid overwriting optimistic local updates.

  final Map<int, AttendanceStatus> _localStatuses = {};
  final Map<int, String?> _personAttendanceIds = {}; // Map personId -> personAttendanceId
  final Map<int, String?> _personNotes = {}; // Map personId -> notes
  final Map<int, String?> _changedBy = {}; // Map personId -> changedBy userId
  final Map<int, String?> _changedAt = {}; // Map personId -> changedAt timestamp
  final Set<int> _savingPersonIds = {}; // Track in-flight saves to prevent realtime overwrites
  bool _isDisposed = false; // Track disposal state for realtime callbacks
  final Map<int, Map<String, dynamic>?> _registrationAnswers = {}; // personId -> registration_answers
  bool? _lastOnline; // last known connectivity, toast only on a real change

  // Realtime channel - typed for proper cleanup
  RealtimeChannel? _personAttChannel;

  // Provider subscription - managed separately from realtime
  ProviderSubscription? _providerSubscription;

  // LEFTOVERS: Ionic onVisibilityChange – refetch + resubscribe when the
  // app/tab becomes visible again (realtime events may have been missed).
  AppLifecycleListener? _lifecycleListener;

  // Local checklist state - maintained separately to allow editing
  List<ChecklistItem> _localChecklist = [];
  bool _checklistLoaded = false;

  // Click mode: tap cycles status instead of opening picker
  // UX_ATT: Ionic default AttendanceViewMode.CLICK (tap cycles the status)
  bool _clickMode = true;

  // Local songs/history entries
  List<SongHistoryEntry> _songEntries = [];
  bool _isSavingSongs = false;

  // ATT_DETAIL: view options (Ionic statusFilter / extraFieldSort / showAvatars / showRegFields)
  Set<AttendanceStatus> _statusFilter = {};
  AttendanceSort _sort = const AttendanceSort();
  bool _showAvatars = false;
  bool _showRegFields = true;
  bool _deletedHandled = false;
  // LOGIC_ATT: person rows removed on this device (no "deletedByOther")
  final Set<String> _ownDeletedPaIds = {};
  bool _isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to realtime changes after first frame. LOGIC_ATT: like Ionic,
    // opening a Termin never creates person rows; an empty Termin shows the
    // "Neu laden" banner instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force fresh data from DB (handles cross-device changes and stale autoDispose cache)
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      _subscribeToRealtimeChanges();
      _setupProviderListener();
      _loadChecklistFromAttendance();
      _loadSongEntries();
      _loadViewPrefs(); // ATT_DETAIL
    });
    _lifecycleListener = AppLifecycleListener(onShow: _onBecameVisible); // LEFTOVERS
  }

  /// LEFTOVERS: Ionic onVisibilityChange (document visible again) – reload
  /// the Termin and its persons and resubscribe the realtime channel.
  void _onBecameVisible() {
    if (_isDisposed || !mounted || _deletedHandled) return;
    ref.invalidate(attendanceDetailProvider(widget.attendanceId));
    ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
    _unsubscribeFromRealtimeChanges();
    _subscribeToRealtimeChanges();
  }

  /// Load checklist from attendance data
  void _loadChecklistFromAttendance() {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance != null && !_checklistLoaded) {
      setState(() {
        _localChecklist = List.from(attendance.checklist ?? []);
        _checklistLoaded = true;
      });
    }
  }

  /// Load song entries from attendance data with resolved names
  Future<void> _loadSongEntries() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final Attendance? attendance;
    try {
      attendance = await ref.read(attendanceDetailProvider(widget.attendanceId).future);
    } catch (_) {
      return;
    }
    if (attendance == null || !mounted) return;

    // LOGIC_ATT: like Ionic (getHistoryByAttendanceId) the history table is
    // the only source; the legacy attendance.songs/conductors arrays are
    // neither read nor written.
    try {
      final songs = await ref.read(songsProvider.future);
      final allConductors = await ref.read(conductorsProvider.future);
      if (!repo.hasTenantId) return;
      final rows = await repo.getHistoryForAttendance(widget.attendanceId);
      if (!mounted) return;
      final fromHistory = rows.map((row) {
        final songId = (row['songId'] as num).toInt();
        final personId = (row['person_id'] as num?)?.toInt();
        final other = row['otherConductor'] as String?;
        final song = songs.where((s) => s.id == songId).firstOrNull;
        final conductor = allConductors.where((c) => c.id == personId).firstOrNull;
        return SongHistoryEntry(
          songId: songId,
          songName: song?.displayName ?? context.l10n.historyFlutterUnknownSong,
          conductorId: personId,
          conductorName: conductor?.fullName,
          otherConductor: other?.isNotEmpty == true ? other : null,
        );
      }).toList();
      setState(() => _songEntries = fromHistory);
    } catch (_) {
      // songs accordion stays empty
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _lifecycleListener?.dispose(); // LEFTOVERS
    _providerSubscription?.close();
    _unsubscribeFromRealtimeChanges();
    super.dispose();
  }

  /// Setup provider listener to sync data from server to local state.
  void _setupProviderListener() {
    _providerSubscription = ref.listenManual(
      filteredPersonAttendancesForAttendanceProvider(widget.attendanceId),
      (previous, next) {
        if (!mounted || _isDisposed) return;

        // Only process completed data. Skip AsyncLoading which carries stale
        // previous data and would cause a flicker (unnecessary setState with
        // unchanged values). The fresh AsyncData arrives once the refetch completes.
        if (next is! AsyncData) return;

        final value = next.value;
        if (value != null) {
          setState(() {
            for (final pa in value) {
              if (pa.personId != null) {
                // IDs und Metadaten IMMER aktualisieren
                _personAttendanceIds[pa.personId!] = pa.id;
                _changedBy[pa.personId!] = pa.changedBy;
                _changedAt[pa.personId!] = pa.changedAt;
                _registrationAnswers[pa.personId!] = pa.registrationAnswers;
                // Status/Notiz nur setzen wenn nicht gerade lokal geändert
                if (!_savingPersonIds.contains(pa.personId!)) {
                  _localStatuses[pa.personId!] = pa.status;
                  _personNotes[pa.personId!] = pa.notes;
                }
              }
            }
          });
        }
      },
      fireImmediately: true,
    );
  }

  void _subscribeToRealtimeChanges() {
    // TODO(sprint-2c): migrate Realtime channel subscription to a repository
    // or dedicated realtime service. Keeping direct client access for now.
    final supabase = ref.read(supabaseClientProvider);

    _personAttChannel = supabase
        .channel('person-att-${widget.attendanceId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'person_attendances',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'attendance_id',
            value: widget.attendanceId,
          ),
          callback: _onPersonAttendanceChange,
        )
        // LOGIC_ATT: person rows deleted elsewhere (DELETE events carry
        // only the old id and cannot be filtered by attendance_id)
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'person_attendances',
          callback: _onPersonAttendanceDeleted,
        )
        // LOGIC_ATT: times, notes, plan … changed by another user
        // (Ionic onAttRealtimeChanges → this.attendance = payload.new)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'attendance',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.attendanceId,
          ),
          callback: _onAttendanceUpdated,
        )
        // ATT_DETAIL: Termin deleted by another user
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'attendance',
          callback: _onAttendanceDeleted,
        )
        .subscribe();
  }

  void _unsubscribeFromRealtimeChanges() {
    final channel = _personAttChannel;
    if (channel != null) {
      // TODO(sprint-2c): mirror the Realtime channel migration above.
      final supabase = ref.read(supabaseClientProvider);
      supabase.removeChannel(channel);
      _personAttChannel = null;
    }
  }

  void _onPersonAttendanceChange(dynamic payload) {
    if (_isDisposed) return;

    final newRecord = payload.newRecord as Map<String, dynamic>?;
    if (newRecord == null || newRecord.isEmpty) return;

    final personId = newRecord['person_id'] as int?;
    // LOGIC_ATT: a person added on another device → reload the rows so the
    // new person shows up.
    if (payload is PostgresChangePayload && payload.eventType == PostgresChangeEvent.insert) {
      if (personId != null && !_personAttendanceIds.containsKey(personId) && mounted) {
        ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      }
      return;
    }
    if (personId != null && _savingPersonIds.contains(personId)) return;

    // LEFTOVERS: Ionic also takes duty_state from the payload; the Dienst
    // section reads the provider rows, so reload them when it changed.
    final rows = ref.read(personAttendancesForAttendanceProvider(widget.attendanceId)).valueOrNull;
    if (rows != null && realtimeDutyStateChanged(newRecord, rows) && mounted) {
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
    }

    final statusValue = newRecord['status'];
    final notes = newRecord['notes'] as String?;
    final changedBy = newRecord['changed_by'] as String?;
    final changedAt = newRecord['changed_at'] as String?;

    if (personId != null && statusValue != null) {
      AttendanceStatus status;
      if (statusValue is int) {
        status = AttendanceStatus.fromValue(statusValue);
      } else {
        final statusStr = statusValue.toString();
        final intValue = int.tryParse(statusStr);
        if (intValue != null) {
          status = AttendanceStatus.fromValue(intValue);
        } else {
          status = AttendanceStatus.values.firstWhere(
            (s) => s.name.toLowerCase() == statusStr.toLowerCase(),
            orElse: () => AttendanceStatus.neutral,
          );
        }
      }

      if (_isDisposed || !mounted) return;

      final recordId = newRecord['id']?.toString();
      try {
        setState(() {
          _localStatuses[personId] = status;
          if (recordId != null) _personAttendanceIds[personId] = recordId;
          _personNotes[personId] = notes;
          _changedBy[personId] = changedBy;
          _changedAt[personId] = changedAt;
        });
      } catch (e) {
        // Ignore setState errors if widget was disposed during callback
      }
    }
  }

  /// UX_ATT: corner radius of the page's section cards (theme card shape).
  BorderRadius _sectionRadius(BuildContext context) {
    // PARITY_R3: iOS inset item groups (ionic-theme-ios26/27) radius 28.
    if (useIosLook(context)) {
      return BorderRadius.circular(IonIos.groupRadius);
    }
    // PARITY_R9: md – the md-ion-list-inset item-group radius (16), not
    // the md ion-card radius (4) of the card theme.
    return BorderRadius.circular(IonMd.groupRadius);
  }

  @override
  Widget build(BuildContext context) {
    // Tenant switched while this Termin is open -> close it (it belongs to
    // the previous tenant).
    ref.listen<int?>(currentTenantIdProvider, (previous, next) {
      if (previous != null && next != previous && mounted) {
        GoRouter.of(context).go('/attendance');
      }
    });
    // Toast only on a real online/offline transition (not on every
    // connectivity event, e.g. Wi-Fi <-> mobile).
    ref.listen<AsyncValue<bool>>(connectivityProvider, (previous, next) {
      final online = next.valueOrNull;
      if (online == null) return;
      final before = _lastOnline ?? previous?.valueOrNull;
      _lastOnline = online;
      if (before == null || before == online || !mounted) return;
      if (online) {
        ToastHelper.showSuccess(context, context.l10n.attendanceConnectionRestored);
      } else {
        ToastHelper.showError(context, context.l10n.attendanceNoConnection);
      }
    });

    final attendanceAsync = ref.watch(attendanceDetailProvider(widget.attendanceId));
    final personsAsync = ref.watch(filteredPersonsForAttendanceProvider(widget.attendanceId));
    ref.watch(filteredPersonAttendancesForAttendanceProvider(widget.attendanceId));
    final attendanceTypeAsync = ref.watch(attendanceTypeForAttendanceProvider(widget.attendanceId));

    final typeStatuses = attendanceTypeAsync.valueOrNull?.availableStatuses;
    final availableStatuses = (typeStatuses?.isNotEmpty == true) ? typeStatuses! : AttendanceStatus.values;

    return attendanceAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l10n.signoutAttendance)),
        body: const Center(child: AppSpinner()),
      ),
      // ATT_DETAIL: Ionic "loadFailedReopen" / "Neu laden"
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.signoutAttendance)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                const SizedBox(height: AppDimensions.paddingM),
                Text(
                  context.l10n.attendanceLoadFailedReopen,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(attendanceDetailProvider(widget.attendanceId)),
                  icon: const Icon(Icons.refresh),
                  label: IonButtonLabel(context.l10n.attendanceReload),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (attendance) {
        if (attendance == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.signoutAttendance)),
            body: Center(child: Text(context.l10n.attendanceFlutterNotFound)),
          );
        }

        // UX_ATT: Ionic title "dd.MM.yyyy | anwesend/gesamt" of the shown persons
        final titlePersons = personsAsync.valueOrNull == null
            ? null
            : _titlePersons(personsAsync.valueOrNull!);
        final dateLabel = attendance.formattedDate;
        final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
        final pendingOffline = ref.watch(offlinePendingCountProvider);

        // IOS_DETAIL: iOS header: back and ⋮ each in a 44 pt glass circle
        final ios = useIosLook(context);
        final canPop = Navigator.of(context).canPop();
        // IOS_DETAIL: the shell's floating button / FAB never covers the
        // last row (Ionic .marginBottom 5rem + tabbar-safe padding).
        final fabShown = ios && !ref.watch(effectiveRoleProvider).isViewer;
        // IOS_SHELL2: iOS shell → the FAB sits in the tab bar row and the
        // MediaQuery padding is the floating tab bar inset.
        final bottomSpace = scrollEndPadding(context,
            base: 16, fabRoom: fabShown ? 80.0 : 64.0);

        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : AppColors.light,
          appBar: AppBar(
            leading: ios && canPop
                ? Center(
                    child: Semantics(
                      button: true,
                      label: MaterialLocalizations.of(context).backButtonTooltip,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const IosCircleIcon(
                          icon: Icons.arrow_back_ios_new,
                          size: 44,
                          iconSize: 20,
                        ),
                      ),
                    ),
                  )
                : null,
            leadingWidth: ios && canPop ? 68 : null,
            title: Text(
              titlePersons == null
                  ? dateLabel
                  : '$dateLabel | ${_attendedCount(titlePersons)}/${titlePersons.length}',
            ),
            actions: [
              // UX_ATT: Ionic offline chip in the header
              if (!isOnline)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.warning,
                    side: BorderSide.none,
                    avatar: const Icon(Icons.cloud_off, size: 16, color: Colors.black),
                    label: Text(
                      pendingOffline > 0 ? context.l10n.attendancePending(pendingOffline) : context.l10n.attendanceOffline,
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                ),
              // IOS_DETAIL: Ionic ion-popover menu (iOS popover / Material
              // popup menu) behind a glass circle button on iOS.
              ToolbarButtonGroup(
                children: [
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                      // ATT_DETAIL: badge with the number of active status filters
                      icon: Badge(
                        isLabelVisible: _statusFilter.isNotEmpty,
                        // PARITY_R8: Ionic `ion-badge color="primary"
                        // class="filter-badge"` – 10px bold (700).
                        backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                        textStyle: ionBadgeTextStyle(fontSize: 10, height: null),
                        label: Text('${_statusFilter.length}'),
                        child: Icon(
                          Icons.more_vert,
                          color: _statusFilter.isNotEmpty ? AppColors.primary : null,
                        ),
                      ),
                      onPressed: () async {
                        final action = await showAppPopoverMenu<String>(
                          context: buttonContext,
                          items: _buildAttDetailMenuItems(attendance),
                          // PARITY_R3: nested popovers update the entries
                          // ("Filter aktiv") while the menu stays open.
                          itemsBuilder: () => _buildAttDetailMenuItems(attendance),
                        );
                        if (action != null && mounted) _handleMenuAction(action);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: personsAsync.when(
            loading: () => const Center(child: AppSpinner()),
            // ATT_DETAIL: "Neu laden" banner
            error: (error, stack) => ListView(children: [_buildLoadFailedBanner()]),
            data: (persons) {
              // GROUP_ORDER: Ionic has the groups (main group, sort_order)
              // before the list renders; never show a first frame in query
              // order that re-sorts once the groups arrive.
              final groupsAsync = ref.watch(groupsProvider);
              if (groupsAsync.isLoading && !groupsAsync.hasValue) {
                return const Center(child: AppSpinner());
              }
              if (!_checklistLoaded && attendance.checklist != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_checklistLoaded) {
                    setState(() {
                      _localChecklist = List.from(attendance.checklist!);
                      _checklistLoaded = true;
                    });
                  }
                });
              }

              final attendanceType = attendanceTypeAsync.valueOrNull;
              // SETTINGS_EXT: Rollenberechtigungen für Helfer (Checkliste, Notizen, Gruppe)
              final canViewChecklist = ref.watch(canViewAttendanceChecklistProvider);
              final canViewNotes = ref.watch(canViewAttendanceNotesProvider);
              // SOL_FIX2: loading/error/missing profile group = no access
              // (never "all groups" before the permission is confirmed).
              final groupScopeAsync = ref.watch(attendanceGroupScopeProvider);
              final groupScope = resolvedGroupScope(groupScopeAsync);
              final groupPersons = groupScope.isAll
                  ? _personsInAttendance(persons)
                  : _personsInAttendance(persons).where((p) => groupScope.allowsGroup(p.instrument)).toList();
              // ATT_DETAIL: status filter + extra field sort
              final sortFields = _sortableFields(attendanceType);
              final sortField = sortFields.where((f) => f.id == _sort.fieldId).firstOrNull;
              final churches = ref.watch(churchesProvider).valueOrNull ?? const [];
              final statusFiltered = filterPersonsByStatus(groupPersons, _localStatuses, _statusFilter);
              final groups = groupsAsync.valueOrNull ?? const [];
              final visiblePersons = sortField == null
                  // UX_ATT: Ionic group order (main group, sort_order, name)
                  ? sortPersonsByGroup(
                      statusFiltered,
                      groups: groups,
                      mainGroupId: mainGroupIdOf(groups) ?? ref.watch(mainGroupProvider).valueOrNull?.id,
                      // GROUP_ORDER: Ionic Termin page sorts by last name only
                      usePersonSortOrder: false,
                    )
                  : sortPersonsByField(statusFiltered, _sort, sortField, _registrationAnswers, churches);
              final sortLines = sortField == null
                  ? null
                  : {
                      for (final p in visiblePersons)
                        if (p.id != null)
                          p.id!: '${sortDisplayValueOf(p, _sort, sortField, _registrationAnswers, churches)}'
                              ' · ${p.groupName ?? context.l10n.attendanceNoGroup}',
                    };
              final isHelper = ref.watch(effectiveRoleProvider).isHelperRole;
              final visibleNotes = canViewNotes
                  ? _personNotes
                  : {
                      for (final e in _personNotes.entries)
                        e.key: (e.value?.isNotEmpty ?? false) ? context.l10n.attendanceNoteAdded : e.value,
                    };
              // UX_ATT: Ionic shows the Checkliste only once it has items;
              // an empty one is started via the menu ("Checkliste starten").
              final hasChecklist = canViewChecklist && _localChecklist.isNotEmpty;
              final hasSongs = attendanceType?.manageSongs ?? false;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    // UX_ATT: Ionic iOS inset list: 16 px between the groups
                    child: Column(
                      spacing: AppDimensions.paddingS,
                      children: [
                        const SizedBox(height: AppDimensions.paddingXS),

                        GeneralInfoAccordion(
                          key: const ValueKey('att-acc-general'), // IOS_DETAIL
                          attendance: attendance,
                          attendanceType: attendanceType,
                          onTypeInfoChanged: _updateTypeInfo,
                          onNotesChanged: (value) async {
                            try {
                              final repo = ref.read(attendanceRepositoryWithTenantProvider);
                              if (!repo.hasTenantId) return;
                              await repo.updateAttendance(
                                widget.attendanceId,
                                {'notes': value.isEmpty ? null : value},
                              );
                              ref.invalidate(attendanceDetailProvider(widget.attendanceId));
                            } catch (e) {
                              if (mounted) {
                                ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
                              }
                            }
                          },
                          onStartTimeSelect: _selectStartTime,
                          onEndTimeSelect: _selectEndTime,
                          onDeadlineToggle: _toggleDeadline,
                          onDeadlineSelect: _selectDeadline,
                          onExportExcel: _exportAttendanceToExcel,
                          onDateSelect: _changeDate,
                          onPlaceChanged: _updatePlace,
                          onOpenNavigation: attendance.place?.isNotEmpty == true
                              ? () => openEventNavigation(context, attendance.place!)
                              : null,
                          onChooseFilesFolder: _chooseFilesFolder,
                          onRemoveFilesFolder: _removeFilesFolder,
                          onOpenFilesFolder: attendance.filesFolder?.isNotEmpty == true
                              ? () => openFilesFolderRoute(context, attendance.filesFolder!)
                              : null,
                          // ATT_DETAIL
                          // IOS_DETAIL: Ionic shows the link to every role that
                          // edits the Termin (Helfer included); viewers stay
                          // read-only (MED5).
                          onEditDescription: canEditAttendanceDescription(
                                  ref.watch(effectiveRoleProvider))
                              ? () => showDescriptionAttachmentSheet(context,
                                  attendance: attendance)
                              : null,
                        ),

                        // UX_ATT: Ionic order Allgemein, Werke, Checkliste,
                        // Besetzung, Protokoll, Ablaufplan, Personen
                        if (hasSongs)
                          SongsHistoryAccordion(
                            key: const ValueKey('att-acc-songs'),
                            entries: _songEntries,
                            onAdd: _openSongsSelection,
                            onRemove: _removeSongEntry,
                            onTap: _onSongEntryTap,
                          ),

                        if (hasChecklist)
                          ChecklistAccordion(
                            key: const ValueKey('att-acc-checklist'),
                            checklist: _localChecklist,
                            onToggle: _toggleChecklistItem,
                            onAdd: _addChecklistItem,
                            onRemove: _removeChecklistItem,
                            onRestore: _restoreChecklist,
                            getDeadlineStatus: _getDeadlineStatus,
                            formatDeadlineRelative: _formatDeadlineRelative,
                          ),

                        // DUTY: Dienstplan "Besetzung"
                        if (attendanceType != null && attendanceType.dutyMode && attendance.id != null)
                          DutyStaffingSection(
                            attendance: attendance,
                            attendanceType: attendanceType,
                          ),

                        // PROTOCOL: Protokoll-Karte + "Aufgaben aus diesem Termin"
                        if (ref.watch(protocolTypeByIdProvider(attendance.typeId))?.enableProtocol ?? false)
                          AttendanceProtocolSection(attendanceId: widget.attendanceId, typeId: attendance.typeId),

                        // ORG_PLANS: observers (viewer role) must not see the plan
                        if (!ref.watch(effectiveRoleProvider).isViewer)
                        PlanAccordion(
                          key: const ValueKey('att-acc-plan'),
                          attendance: attendance,
                          // IOS_DETAIL: Ionic never opens an accordion by itself
                          // (no auto-expand after the planning page); the open
                          // state lives with the accordion like Ionic's.
                          onCreate: () => context.push<bool>('/planning?attendanceId=${widget.attendanceId}'),
                          onEdit: () => context.push<bool>('/planning?attendanceId=${widget.attendanceId}'),
                          onExportPdf: _exportPlanPdf,
                          onSendViaTelegram: _showTelegramFormatOptions,
                          onSharePlanChanged: _toggleSharePlan,
                        ),
                      ],
                    ),
                  ),

                  // ATT_DETAIL: no persons could be loaded
                  if ((persons.isEmpty || _noPersonRows) && groupScope.isAll)
                    SliverToBoxAdapter(child: _buildLoadFailedBanner()),
                  // SOL_FIX2: group permission not confirmed yet
                  if (groupScopeAsync.isLoading)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),

                  // UX_ATT: the persons are the last item-group of Ionic's
                  // inset list: a rounded white section with 16 px margins.
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppDimensions.paddingM, 12, AppDimensions.paddingM, 0),
                    sliver: AttendanceGrid(
                      cornerRadius: _sectionRadius(context),
                      persons: visiblePersons,
                      localStatuses: _localStatuses,
                      personNotes: visibleNotes,
                      availableStatuses: availableStatuses,
                      clickMode: _clickMode,
                      onStatusChanged: (personId, status) {
                        // SOL_FIX2: only persons inside the confirmed group scope
                        if (!groupPersons.any((p) => p.id == personId)) return;
                        final previousStatus = _localStatuses[personId];
                        setState(() {
                          _localStatuses[personId] = status;
                        });
                        _savePersonStatus(personId, status, previousStatus: previousStatus);
                      },
                      // Maskierte Notiz nicht als neuen Wert zurückschreiben
                      onNoteChanged: (personId, notes) {
                        if (!canViewNotes && notes == context.l10n.attendanceNoteAdded) return;
                        _updatePersonNote(personId, notes);
                      },
                      onShowModifierInfo: _showModifierInfo,
                      onRemoveFromAttendance: _removePersonFromAttendance,
                      registrationSummaries:
                          _showRegFields ? _registrationSummaries(attendanceType) : const {},
                      // ATT_DETAIL
                      showAvatars: _showAvatars,
                      extraLines: sortLines,
                      showModifierInfo: !isHelper,
                      onSendReminder: (personId) {
                        final appId = visiblePersons.where((p) => p.id == personId).firstOrNull?.appId;
                        if (appId == null || appId.isEmpty) {
                          ToastHelper.showWarning(context, context.l10n.attendanceFlutterNoAccount);
                          return;
                        }
                        _sendAdHocReminder(playerAppId: appId);
                      },
                      onEditRegistrationFields: (attendanceType?.registrationFields?.isNotEmpty ?? false)
                          ? (personId) => _editRegistrationFields(personId, attendanceType!)
                          : null,
                    ),
                  ),
                  // Ionic .marginBottom (5rem) below the list; IOS_DETAIL:
                  // plus the FAB and the bottom inset on iOS.
                  SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
                ],
              );
            },
          ),
          // UX_ATT: no Flutter-only bottom summary bar (Ionic has none; the
          // counts live in "Statusübersicht"). On iOS Ionic shows a FAB that
          // opens the Ablaufplan editor (isIos && attendance → editPlan()).
          // IOS_SHELL2: iOS → ion-fab in the tab bar row
          floatingActionButton: fabShown
              ? TabBarFab(
                  child: IonFabButton(
                    heroTag: 'att-detail-plan-fab',
                    icon: Icons.format_list_bulleted,
                    onPressed: () => context.push<bool>('/planning?attendanceId=${widget.attendanceId}'),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// Validate that a personAttendance belongs to current tenant
  /// (UI_TENANT_HOIST: takes the repository the caller bound before its
  /// first await.)
  Future<bool> _validatePersonAttendanceTenant(
      AttendanceRepository repo, String personAttendanceId) async {
    if (!repo.hasTenantId) return false;
    return repo.validatePersonAttendanceTenant(personAttendanceId);
  }

  /// Update notes for a specific person
  Future<void> _updatePersonNote(int personId, String? notes) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final personAttendanceId = _personAttendanceIds[personId];
    if (personAttendanceId == null) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterNoEntry);
      return;
    }

    // INTEGRATION: queue while offline like every Ionic updatePersonAttendance
    // SOL_FIX12: a write that could not be queued is reported, never
    // treated as saved.
    // SOL_FIX13: the session captured here also guards the direct write.
    final offlineQueue = ref.read(offlineQueueNotifierProvider.notifier);
    final writeSession = offlineQueue.captureWriteSession();
    try {
      if (await offlineQueue.enqueueIfOffline(
          personAttendanceId, {'notes': notes ?? ''},
          attendanceId: widget.attendanceId, session: writeSession)) {
        if (mounted) setState(() => _personNotes[personId] = notes);
        return;
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
      return;
    }

    final isValid = await _validatePersonAttendanceTenant(repo, personAttendanceId);
    if (!isValid) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterNoPermission);
      }
      return;
    }

    // Show the note immediately; the provider listener is guarded via
    // _savingPersonIds so a stale refetch cannot overwrite it.
    final previousNote = _personNotes[personId];
    if (mounted) setState(() => _personNotes[personId] = notes);
    _savingPersonIds.add(personId);

    try {
      await repo.updatePersonAttendance(
        personAttendanceId,
        {'notes': notes ?? ''},
        isSessionCurrent: writeSession.isCurrent,
        actingUserId: writeSession.userId,
      );

      if (mounted) {
        ToastHelper.showSuccess(context, notes?.isNotEmpty == true ? context.l10n.attendanceNoteAdded : context.l10n.attendanceFlutterNoteDeleted);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _personNotes[personId] = previousNote);
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    } finally {
      _savingPersonIds.remove(personId);
    }
  }

  /// Show modifier info (who changed, when)
  Future<void> _showModifierInfo(int personId) async {
    final changedBy = _changedBy[personId];
    final changedAt = _changedAt[personId];

    // ATT_DETAIL: Ionic getModifierInfo (toast when unchanged, alert otherwise)
    if (changedBy == null) {
      ToastHelper.showWarning(context, context.l10n.attendanceStatusNotChanged);
      return;
    }
    final persons = ref.read(allPersonsForAttendanceProvider).valueOrNull ?? [];
    final modifier = persons.where((p) => p.appId == changedBy).firstOrNull;
    final modifierName = modifier != null && modifier.fullName.isNotEmpty
        ? modifier.fullName
        : "'${context.l10n.commonUnknown}'";
    final date = changedAt == null ? null : DateTime.tryParse(changedAt)?.toLocal();
    final message = date == null
        ? context.l10n.attendanceLastChangedBy(modifierName)
        : context.l10n.attendanceLastChangedByAt(
            modifierName, DateFormat(dateFmt()).format(date), DateFormat('HH:mm').format(date));

    showAppDialog(
      context: context,
      builder: (ctx) => AppAlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    const mutating = {
      'photo', 'add_person', 'start_checklist', 'reset_checklist', 'reminder',
    };
    if (mutating.contains(action) &&
        !canMutateAttendanceDetail(ref.read(effectiveRoleProvider))) {
      return;
    }
    switch (action) {
      case 'stats':
        _showStatsDialog();
        break;
      case 'legend':
        showAttendanceLegendSheet(context);
        break;
      case 'photo':
        _takePhoto();
        break;
      case 'export_excel':
        _exportAttendanceToExcel();
        break;
      // ATT_DETAIL (Status-Filter / Ansicht open nested popovers)
      case 'sort':
        _openSortPicker();
        break;
      case 'add_person':
        _openAddPersons();
        break;
      case 'start_checklist':
        _addChecklistItem();
        break;
      case 'reset_checklist':
        _restoreChecklist(confirm: false);
        break;
      case 'church':
        _showChurchOverview();
        break;
      case 'reminder':
        _sendAdHocReminder();
        break;
    }
  }

  // ============== ATT_DETAIL ==============

  static const _prefShowAvatars = 'attendanceShowAvatars';
  static const _prefShowRegFields = 'attendanceShowRegFields';
  static const _prefViewMode = 'attendanceViewMode'; // UX_ATT: 'click' | 'select'
  String get _prefSortField => 'attSortField${widget.attendanceId}';
  String get _prefSortLevel => 'attSortLevel${widget.attendanceId}';
  String get _prefSortDir => 'attSortDir${widget.attendanceId}';

  Future<void> _loadViewPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final field = prefs.getString(_prefSortField);
      final level = prefs.getString(_prefSortLevel);
      if (!mounted) return;
      setState(() {
        _showAvatars = prefs.getBool(_prefShowAvatars) ?? false;
        _showRegFields = prefs.getBool(_prefShowRegFields) ?? true;
        _clickMode = prefs.getString(_prefViewMode) != 'select';
        if (field != null && field.isNotEmpty) {
          _sort = AttendanceSort(
            fieldId: field,
            level: level == 'registration' ? SortFieldLevel.registration : SortFieldLevel.person,
            ascending: prefs.getString(_prefSortDir) != 'desc',
          );
        }
      });
    } catch (_) {
      // Preferences unavailable (e.g. private mode) – keep defaults.
    }
  }

  Future<void> _savePref(Future<void> Function(SharedPreferences prefs) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  /// Persons that are part of this Termin (have a person_attendances row).
  /// Before the rows are loaded all candidates are shown.
  // LOGIC_ATT: only persons with a row in this Termin (Ionic
  // attendance.persons); an empty Termin shows nobody (no auto-fill).
  List<Person> _personsInAttendance(List<Person> persons) {
    final rows = ref.read(filteredPersonAttendancesForAttendanceProvider(widget.attendanceId)).valueOrNull;
    if (rows == null || rows.isEmpty) return const [];
    final ids = {for (final r in rows) r.personId};
    return persons.where((p) => ids.contains(p.id)).toList();
  }

  /// Ionic personsLoadFailed: the Termin has no person rows at all.
  bool get _noPersonRows =>
      ref.read(filteredPersonAttendancesForAttendanceProvider(widget.attendanceId)).valueOrNull?.isEmpty ?? false;

  // UX_ATT: persons counted in the Ionic header title (helper group +
  // status filter applied, like Ionic `filteredPlayers`).
  List<Person> _titlePersons(List<Person> persons) {
    final groupScope = resolvedGroupScope(ref.watch(attendanceGroupScopeProvider));
    final inAttendance = _personsInAttendance(persons);
    final group = groupScope.isAll
        ? inAttendance
        : inAttendance.where((p) => groupScope.allowsGroup(p.instrument)).toList();
    return filterPersonsByStatus(group, _localStatuses, _statusFilter);
  }

  /// Ionic getAttendedPlayers: Anwesend + Verspätet.
  int _attendedCount(List<Person> persons) => persons.where((p) {
        final s = _localStatuses[p.id];
        return s == AttendanceStatus.present || s == AttendanceStatus.late;
      }).length;

  List<SortableField> _sortableFields(AttendanceType? type) {
    final personFields = ref.watch(personExtraFieldsProvider).valueOrNull ?? const [];
    return sortableFields(personFields, type?.registrationFields ?? const []);
  }

  /// Id of the `bfecg_church` extra field, if the tenant has one.
  String? _churchFieldId() {
    final fields = ref.read(personExtraFieldsProvider).valueOrNull ?? const [];
    return fields.where((f) => f.type == 'bfecg_church').firstOrNull?.id;
  }

  List<AppPopoverMenuItem<String>> _buildAttDetailMenuItems(Attendance attendance) {
    final role = ref.read(effectiveRoleProvider);
    // Mutating actions only for admin/responsible (not helpers, not viewers).
    final canMutate = canMutateAttendanceDetail(role);
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final sortFields = sortableFields(
      ref.read(personExtraFieldsProvider).valueOrNull ?? const [],
      type?.registrationFields ?? const [],
    );
    final hasChurch = _churchFieldId() != null;
    final checklistEmpty = _localChecklist.isEmpty;
    final canRestore = (type?.checklist?.isNotEmpty ?? false) && checklistEmpty;
    final activeSort = sortFields.where((f) => f.id == _sort.fieldId).firstOrNull;

    // IOS_DETAIL: entries of the adaptive popover menu; Ionic `detail="true"`
    // (Status-Filter, Ansicht) open a nested popover (PARITY_R3) → chevron.
    AppPopoverMenuItem<String> item(String value, IconData icon, String title,
            {String? subtitle,
            bool highlight = false,
            bool submenu = false,
            List<AppPopoverSubItem> Function()? submenuItems}) =>
        AppPopoverMenuItem<String>(
          value: value,
          icon: icon,
          label: title,
          subtitle: subtitle,
          color: highlight ? AppColors.primary : null,
          submenu: submenu,
          submenuItems: submenuItems,
        );

    return [
      item('status_filter', Icons.filter_list, context.l10n.attendanceStatusFilter,
          subtitle: _statusFilter.isEmpty ? null : context.l10n.attendanceFilterActive(_statusFilter.length),
          highlight: _statusFilter.isNotEmpty, submenu: true,
          submenuItems: _statusFilterSubItems),
      if (sortFields.isNotEmpty)
        item('sort', Icons.swap_vert, context.l10n.attendanceSorting,
            subtitle: activeSort == null ? null : '${activeSort.name} ${_sort.ascending ? '↑' : '↓'}'),
      item('view', Icons.visibility_outlined, context.l10n.attendanceView, submenu: true,
          submenuItems: _viewSubItems),
      if (canMutate) item('add_person', Icons.person_add_alt_1_outlined, context.l10n.attendanceAddPerson),
      if (canMutate && checklistEmpty)
        item('start_checklist', Icons.check_box_outlined, context.l10n.attendanceStartChecklist),
      if (canMutate && canRestore)
        item('reset_checklist', Icons.refresh, context.l10n.attendanceResetChecklist),
      // UX_ATT: Ionic order continues with Status-Übersicht, Gemeinde-Übersicht,
      // Legende, Erinnerung versenden
      item('stats', Icons.bar_chart, context.l10n.attendanceStatusOverview),
      if (hasChurch) item('church', Icons.business_outlined, context.l10n.attendanceChurchOverview),
      item('legend', Icons.info_outline, context.l10n.signoutLegend),
      if (canMutate) item('reminder', Icons.notifications_outlined, context.l10n.attendanceSendReminder),
      // Flutter-only extra (Ionic has the photo upload commented out)
      if (canMutate) item('photo', Icons.camera_alt_outlined, context.l10n.attendanceFlutterPhoto),
    ];
  }

  /// PARITY_R3: nested "Status-Filter" popover (Ionic toggleStatusFilter /
  /// clearStatusFilter, `dismissOnSelect=false`): one checkbox per status,
  /// "Filter zurücksetzen" while a filter is active.
  List<AppPopoverSubItem> _statusFilterSubItems() {
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final available = (type?.availableStatuses?.isNotEmpty ?? false)
        ? type!.availableStatuses!
        : AttendanceStatus.values;
    final options = <(AttendanceStatus, String)>[
      if (available.contains(AttendanceStatus.neutral)) (AttendanceStatus.neutral, context.l10n.commonStatusNeutral),
      if (available.contains(AttendanceStatus.present)) (AttendanceStatus.present, context.l10n.commonStatusPresent),
      if (available.contains(AttendanceStatus.excused)) (AttendanceStatus.excused, context.l10n.commonStatusExcused),
      if (available.contains(AttendanceStatus.late)) (AttendanceStatus.late, context.l10n.commonStatusLateShort),
      if (available.contains(AttendanceStatus.late))
        (AttendanceStatus.lateExcused, context.l10n.commonStatusLateExcused),
      if (available.contains(AttendanceStatus.absent)) (AttendanceStatus.absent, context.l10n.commonStatusAbsent),
    ];
    return [
      for (final (status, label) in options)
        AppPopoverSubItem(
          label: label,
          checked: _statusFilter.contains(status),
          onTap: () {
            if (!mounted) return;
            setState(() {
              final next = {..._statusFilter};
              if (!next.remove(status)) next.add(status);
              _statusFilter = next;
            });
          },
        ),
      if (_statusFilter.isNotEmpty)
        AppPopoverSubItem(
          label: context.l10n.attendanceClearFilter,
          icon: Icons.highlight_off,
          color: AppColors.danger,
          onTap: () {
            if (mounted) setState(() => _statusFilter = {});
          },
        ),
    ];
  }

  /// "Sortierung": Standard (Gruppe) or an extra / registration field ↑↓.
  Future<void> _openSortPicker() async {
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final fields = sortableFields(
      ref.read(personExtraFieldsProvider).valueOrNull ?? const [],
      type?.registrationFields ?? const [],
    );
    final current =
        _sort.isDefault ? '__default__' : '${_sort.fieldId}__${_sort.ascending ? 'asc' : 'desc'}';
    String selected = current;
    final result = await showAppDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget radio(String value, String label) => RadioListTile<String>(
                value: value,
                groupValue: selected,
                title: Text(label),
                dense: true,
                onChanged: (v) => setDialogState(() => selected = v!),
              );
          return AppAlertDialog(
            title: Text(context.l10n.attendanceSorting),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  radio('__default__', context.l10n.attendanceDefaultSortGroup),
                  for (final f in fields) ...[
                    radio('${f.id}__asc', '${f.name} ↑'),
                    radio('${f.id}__desc', '${f.name} ↓'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
              TextButton(onPressed: () => Navigator.pop(ctx, selected), child: Text(context.l10n.commonOk)),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    if (result == '__default__') {
      setState(() => _sort = const AttendanceSort());
      await _savePref((p) async {
        await p.setString(_prefSortField, '');
        await p.setString(_prefSortLevel, '');
        await p.setString(_prefSortDir, '');
      });
      return;
    }
    final idx = result.lastIndexOf('__');
    final fieldId = result.substring(0, idx);
    final asc = result.substring(idx + 2) != 'desc';
    final field = fields.where((f) => f.id == fieldId).firstOrNull;
    final level = field?.level ?? SortFieldLevel.person;
    setState(() => _sort = AttendanceSort(fieldId: fieldId, level: level, ascending: asc));
    await _savePref((p) async {
      await p.setString(_prefSortField, fieldId);
      await p.setString(
          _prefSortLevel, level == SortFieldLevel.registration ? 'registration' : 'person');
      await p.setString(_prefSortDir, asc ? 'asc' : 'desc');
    });
  }

  /// PARITY_R3: nested "Ansicht" popover (Ionic `attendance-view-trigger`):
  /// Bilder anzeigen / Anmeldefelder anzeigen / Explizite Statusauswahl.
  List<AppPopoverSubItem> _viewSubItems() {
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final hasRegFields = type?.registrationFields?.isNotEmpty ?? false;
    return [
      AppPopoverSubItem(
        label: context.l10n.attendanceShowPictures,
        checked: _showAvatars,
        onTap: () {
          if (!mounted) return;
          setState(() => _showAvatars = !_showAvatars);
          _savePref((p) => p.setBool(_prefShowAvatars, _showAvatars));
        },
      ),
      if (hasRegFields)
        AppPopoverSubItem(
          label: context.l10n.attendanceShowRegFields,
          checked: _showRegFields,
          onTap: () {
            if (!mounted) return;
            setState(() => _showRegFields = !_showRegFields);
            _savePref((p) => p.setBool(_prefShowRegFields, _showRegFields));
          },
        ),
      AppPopoverSubItem(
        label: context.l10n.attendanceExplicitStatus,
        subtitle: context.l10n.attendanceExplicitStatusHint,
        checked: !_clickMode,
        onTap: () {
          if (!mounted) return;
          setState(() => _clickMode = !_clickMode);
          _savePref((p) => p.setString(_prefViewMode, _clickMode ? 'click' : 'select'));
        },
      ),
    ];
  }

  /// "Person hinzufügen" (Ionic openAddPersonModal / addPersonsToAttendance).
  Future<void> _openAddPersons() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final AddPersonCandidates candidates;
    try {
      final allPersons = await ref.read(allPersonsForAttendanceProvider.future);
      final type = await ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId).future);
      final groups = await ref.read(groupsProvider.future);
      final extraFields = ref.read(personExtraFieldsProvider).valueOrNull ?? const [];
      candidates = computeAddPersonCandidates(
        allPersons: allPersons,
        currentPersonIds: _personAttendanceIds.keys.toSet(),
        type: type,
        groups: groups,
        extraFieldDefaults: {for (final f in extraFields) f.id: f.defaultValue},
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceLoadPeopleFailed);
      return;
    }
    if (!mounted) return;
    final selected = await showAddPersonsSheet(
      context,
      candidates: candidates,
      groupNameOf: (p) => p.groupName ?? context.l10n.attendanceNoGroup,
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    try {
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
      final defaultStatus = type?.defaultStatus ?? AttendanceStatus.neutral;
      final date = DateTime.tryParse(attendance?.date ?? '') ?? DateTime.now();
      final shifts = await ref.read(shiftsProvider.future).catchError((_) => <ShiftPlan>[]);
      final all = [...candidates.matching, ...candidates.others];
      final records = <PersonAttendance>[];
      for (final personId in selected) {
        final person = all.where((p) => p.id == personId).firstOrNull;
        if (person == null) continue;
        var status = defaultStatus;
        var notes = '';
        if (person.shiftId != null && type?.allDay != true) {
          final result = ShiftUtils.statusByShiftOrDefault(
            shift: ShiftUtils.findShift(shifts, person.shiftId),
            attendanceDate: date,
            attendanceStart: type?.startTime ?? '19:00',
            attendanceEnd: type?.endTime ?? '21:00',
            defaultStatus: defaultStatus,
            shiftStart: person.shiftStart,
            shiftName: person.shiftName,
          );
          status = result.status;
          notes = result.note;
        }
        records.add(PersonAttendance(
          attendanceId: widget.attendanceId,
          personId: personId,
          status: status,
          notes: notes,
        ));
      }
      await repo.createPersonAttendances(records);
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        context.l10n.attendancePeopleAdded(records.length),
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceAddPeopleFailed);
    }
  }

  /// "Gemeinde-Übersicht" of the present persons.
  Future<void> _showChurchOverview() async {
    final fieldId = _churchFieldId();
    if (fieldId == null) return;
    const present = {AttendanceStatus.present, AttendanceStatus.late, AttendanceStatus.lateExcused};
    final persons = _personsInAttendance(
        ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull ?? const []);
    final churchIds = persons
        .where((p) => present.contains(_localStatuses[p.id]))
        .map((p) => churchIdOf(p.additionalFields, fieldId))
        .toList();
    List<Church> churches;
    try {
      churches = await ref.read(churchesProvider.future);
    } catch (_) {
      churches = const [];
    }
    if (!mounted) return;
    await showChurchOverviewSheet(
      context,
      churchIds: churchIds,
      churches: churches,
      subtitle: context.l10n.attendancePresentPeople,
    );
  }

  /// "Erinnerung versenden" for the Termin or one person
  /// (`send-ad-hoc-reminder` Edge Function, push + e-mail).
  Future<void> _sendAdHocReminder({String? playerAppId}) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final tenant = ref.read(currentTenantProvider);
    final defaults = adHocReminderDefaults(
      typeName: type?.name,
      date: attendance.date,
      startTime: attendance.startTime,
      typeInfo: attendance.typeInfo,
      tenantLongName: tenant?.longName,
    );
    final persons = _personsInAttendance(
        ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull ?? const []);
    final neutralAppIds = persons
        .where((p) =>
            (_localStatuses[p.id] ?? AttendanceStatus.neutral) == AttendanceStatus.neutral &&
            (p.appId?.isNotEmpty ?? false))
        .map((p) => p.appId!)
        .toList();

    final result = await showAdHocReminderSheet(
      context,
      defaultTitle: defaults.title,
      defaultMessage: defaults.message,
      attendanceLink:
          tenant?.id == null ? null : adHocReminderLink(widget.attendanceId, tenant!.id!),
      hasNeutralPersons: neutralAppIds.isNotEmpty,
    );
    if (result == null || !mounted || _isSendingReminder) return;
    _isSendingReminder = true;
    try {
      await repo.sendAdHocReminder(
        attendanceId: widget.attendanceId,
        title: result.title,
        message: result.message,
        playerAppId: playerAppId,
        playerAppIds: (result.neutralOnly && playerAppId == null) ? neutralAppIds : null,
      );
      if (mounted) ToastHelper.showSuccess(context, context.l10n.attendanceReminderSent);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceSendFailed);
    } finally {
      _isSendingReminder = false;
    }
  }

  /// LOGIC_ATT: Ionic onAttRealtimeChanges – another user changed the Termin
  /// (times, notes, plan, deadline …): reload it.
  void _onAttendanceUpdated(PostgresChangePayload payload) {
    if (_isDisposed || !mounted) return;
    final id = payload.newRecord['id'];
    if (id == null || id.toString() != widget.attendanceId.toString()) return;
    ref.invalidate(attendanceDetailProvider(widget.attendanceId));
  }

  /// LOGIC_ATT: Ionic onPersonAttRealtimeChanges – a shown person row was
  /// deleted by someone else: toast "deletedByOther" and leave the page.
  void _onPersonAttendanceDeleted(PostgresChangePayload payload) {
    if (_isDisposed || !mounted || _deletedHandled) return;
    final oldId = payload.oldRecord['id']?.toString();
    if (oldId == null) return;
    if (_ownDeletedPaIds.remove(oldId)) return;
    if (!_personAttendanceIds.values.contains(oldId)) return;
    _deletedHandled = true;
    ToastHelper.showError(context, context.l10n.attendanceDeletedByOther);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/attendance');
    }
  }

  /// Leaves the page when the Termin is deleted by someone else
  /// (Ionic onAttRealtimeChanges "deletedByOther").
  void _onAttendanceDeleted(PostgresChangePayload payload) {
    final oldId = payload.oldRecord['id'];
    if (oldId == null || oldId.toString() != widget.attendanceId.toString()) return;
    if (_isDisposed || !mounted || _deletedHandled) return;
    _deletedHandled = true;
    ToastHelper.showError(context, context.l10n.attendanceDeletedByOther);
    ref.read(attendanceRefetchCounter.notifier).state++;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/attendance');
    }
  }

  /// "Neu laden" banner when the persons of the Termin could not be loaded.
  Widget _buildLoadFailedBanner() {
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.attendanceLoadFailed,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(context.l10n.attendanceTryAgain, style: const TextStyle(color: AppColors.medium)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(allPersonsForAttendanceProvider);
                ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
                ref.invalidate(attendanceDetailProvider(widget.attendanceId));
              },
              icon: const Icon(Icons.refresh),
              label: IonButtonLabel(context.l10n.attendanceReload),
            ),
          ],
        ),
      ),
    );
  }
  // ============== END ATT_DETAIL ==============

  // ============== CHECKLIST METHODS ==============

  Future<void> _toggleChecklistItem(int index) async {
    if (index < 0 || index >= _localChecklist.length) return;

    final item = _localChecklist[index];
    final updatedItem = ChecklistItem(
      id: item.id,
      text: item.text,
      deadlineHours: item.deadlineHours,
      completed: !item.completed,
      dueDate: item.dueDate,
    );

    setState(() {
      _localChecklist[index] = updatedItem;
    });

    await _saveChecklist();
  }

  /// ATT_DETAIL: start of the Termin (start time or 19:00) for checklist due dates.
  DateTime? _checklistEventStart(Attendance attendance) {
    final date = DateTime.tryParse(attendance.date);
    if (date == null) return null;
    var hour = 19, minute = 0;
    final start = attendance.startTime;
    if (start != null && start.length >= 5) {
      hour = int.tryParse(start.substring(0, 2)) ?? 19;
      minute = int.tryParse(start.substring(3, 5)) ?? 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// ATT_DETAIL: "To-Do hinzufügen" dialog with text + optional deadline hours.
  Future<({String text, int? hours})?> _showTodoDialog() async {
    final textController = TextEditingController();
    final hoursController = TextEditingController();
    final result = await showAppDialog<({String text, int? hours})>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.attendanceAddTodo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: context.l10n.attendanceTodoText),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hoursController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: context.l10n.attendanceDeadlineHours),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isEmpty) {
                ToastHelper.showWarning(ctx, context.l10n.attendanceEnterText);
                return;
              }
              Navigator.pop(ctx, (
                text: textController.text.trim(),
                hours: int.tryParse(hoursController.text.trim()),
              ));
            },
            child: Text(context.l10n.attendanceAdd),
          ),
        ],
      ),
    );
    textController.dispose();
    hoursController.dispose();
    return result;
  }

  Future<void> _addChecklistItem() async {
    final input = await _showTodoDialog();

    if (input != null && mounted) {
      String? dueDate;
      if (input.hours != null) {
        final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
        final eventStart = attendance == null ? null : _checklistEventStart(attendance);
        dueDate = eventStart?.subtract(Duration(hours: input.hours!)).toUtc().toIso8601String();
      }
      final newItem = ChecklistItem(
        id: const Uuid().v4(),
        text: input.text,
        deadlineHours: input.hours,
        completed: false,
        dueDate: dueDate,
      );

      setState(() {
        _localChecklist.add(newItem);
      });

      await _saveChecklist();
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.attendanceFlutterTodoAdded);
    }
  }

  Future<void> _removeChecklistItem(int index) async {
    if (index < 0 || index >= _localChecklist.length) return;

    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.attendanceFlutterDeleteTodoTitle,
      message: context.l10n.attendanceDeleteTodoConfirm,
      confirmText: context.l10n.commonDelete,
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      setState(() {
        _localChecklist.removeAt(index);
      });

      await _saveChecklist();
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.attendanceFlutterTodoDeleted);
    }
  }

  Future<void> _restoreChecklist({bool confirm = true}) async {
    final attendanceType = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    if (attendanceType?.checklist == null || attendanceType!.checklist!.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attendanceNoDefaultChecklist);
      return;
    }

    // ATT_DETAIL: "Checkliste zurücksetzen" from the menu restores without asking (Ionic)
    final confirmed = !confirm ||
        await DialogHelper.showConfirmation(
          context,
          title: context.l10n.attendanceFlutterRestoreChecklistTitle,
          message: context.l10n.attendanceFlutterRestoreChecklistMessage,
          confirmText: context.l10n.plansRestore,
        );

    if (confirmed == true && mounted) {
      final restoredList = attendanceType.checklist!.map((item) {
        String? dueDate;
        if (item.deadlineHours != null) {
          final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
          final eventStart = attendance == null ? null : _checklistEventStart(attendance);
          if (eventStart != null) {
            dueDate = eventStart.subtract(Duration(hours: item.deadlineHours!)).toUtc().toIso8601String();
          }
        }

        return ChecklistItem(
          id: const Uuid().v4(),
          text: item.text,
          deadlineHours: item.deadlineHours,
          completed: false,
          dueDate: dueDate,
        );
      }).toList();

      setState(() {
        _localChecklist = restoredList;
      });

      await _saveChecklist();
      ToastHelper.showSuccess(context, context.l10n.attendanceChecklistRestored);
    }
  }

  Future<void> _saveChecklist() async {
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      final checklistJson = _localChecklist.map((item) => item.toJson()).toList();

      await repo.updateAttendance(
        widget.attendanceId,
        {'checklist': checklistJson},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  DeadlineStatus _getDeadlineStatus(ChecklistItem item) {
    if (item.completed) return DeadlineStatus.normal;
    if (item.dueDate == null) return DeadlineStatus.normal;

    final dueDate = DateTime.tryParse(item.dueDate!);
    if (dueDate == null) return DeadlineStatus.normal;

    final now = DateTime.now();
    if (now.isAfter(dueDate)) {
      return DeadlineStatus.overdue;
    }

    final warningThreshold = dueDate.subtract(const Duration(hours: 24));
    if (now.isAfter(warningThreshold)) {
      return DeadlineStatus.warning;
    }

    return DeadlineStatus.normal;
  }

  String _formatDeadlineRelative(ChecklistItem item) {
    if (item.dueDate == null) return '';

    final dueDate = DateTime.tryParse(item.dueDate!);
    if (dueDate == null) return '';

    final now = DateTime.now();
    final diff = dueDate.difference(now);

    // Ionic formatDeadline (attendance.overdue* / dueNow / in*)
    final l10n = context.l10n;
    if (diff.isNegative) {
      final absDiff = diff.abs();
      if (absDiff.inDays >= 1) return l10n.attendanceOverdueDays(absDiff.inDays);
      return l10n.attendanceOverdueHours(absDiff.inHours);
    }
    if (diff.inHours < 1) return l10n.attendanceDueNow;
    if (diff.inHours < 24) return l10n.attendanceInHours(diff.inHours);
    return l10n.attendanceInDays(diff.inDays);
  }

  // ============== DEADLINE METHODS ==============

  Future<void> _toggleDeadline(bool enabled) async {
    String? deadlineStr;

    if (enabled) {
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      if (attendance != null) {
        final attendanceDate = DateTime.tryParse(attendance.date);
        if (attendanceDate != null) {
          // LOGIC_ATT: Ionic onDeadlineToggleChanged (day before at type
          // start hour + 2, or the Termin day when that is already past)
          final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
          deadlineStr = defaultDeadline(attendanceDate, type?.startTime).toUtc().toIso8601String();
        }
      }
    }

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'deadline': deadlineStr},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          enabled ? context.l10n.attendanceFlutterDeadlineEnabled : context.l10n.attendanceFlutterDeadlineDisabled,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _selectDeadline() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;

    final attendanceDate = DateTime.tryParse(attendance.date);
    final currentDeadline = attendance.deadline != null
        ? DateTime.tryParse(attendance.deadline!)
        : null;

    final now = DateTime.now();
    final initialDate = currentDeadline ?? attendanceDate?.subtract(const Duration(days: 1)) ?? now;

    final selectedDate = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: attendanceDate ?? now.add(const Duration(days: 365)),
      helpText: context.l10n.attendanceFlutterChooseDeadline,
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showAppTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (!mounted) return;

    final finalDeadline = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime?.hour ?? 23,
      selectedTime?.minute ?? 59,
    );

    try {
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'deadline': finalDeadline.toUtc().toIso8601String()},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.attendanceFlutterDeadlineUpdated);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  // ============== PLAN EXPORT METHODS ==============

  Future<void> _exportPlanPdf() async {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    final plan = attendance?.plan;

    if (plan == null || plan.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attendanceFlutterNoPlanToExport);
      return;
    }

    final fields = plan['fields'] as List?;
    if (fields == null || fields.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attendanceFlutterNoItemsToExport);
      return;
    }

    // Show format selection dialog
    final format = await showAppDialog<String>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(context.l10n.attendanceFlutterExportFormat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(context.l10n.attendanceFlutterA4Standard),
              subtitle: Text(context.l10n.attendanceFlutterOnePlanPerPage),
              onTap: () => Navigator.pop(context, 'a4'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: Text(context.l10n.attendanceFlutterA5OnA4),
              subtitle: Text(context.l10n.attendanceFlutterTwoIdenticalPlans),
              onTap: () => Navigator.pop(context, '2xa5'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) {
      ToastHelper.showError(context, context.l10n.historyFlutterNoTenant);
      return;
    }

    final startTime = plan['startTime'] as String? ?? attendance?.startTime ?? '17:00';
    final endTime = plan['endTime'] as String?;
    final dateStr = attendance?.formattedDate ?? DateTime.now().toIso8601String().substring(0, 10);

    try {
      final exportService = ExportService();

      if (format == '2xa5') {
        await exportService.exportPlanPdf2xA5(
          context: context,
          tenantName: tenant.shortName,
          date: dateStr,
          startTime: startTime,
          endTime: endTime,
          fields: fields.cast<Map<String, dynamic>>(),
        );
      } else {
        await exportService.exportPlanPdf(
          context: context,
          tenantName: tenant.shortName,
          date: dateStr,
          startTime: startTime,
          endTime: endTime,
          fields: fields.cast<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.exportFlutterFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _showTelegramFormatOptions() async {
    final result = await showAppActionSheet<String>(
      context,
      actions: [
        AppActionSheetAction(
          value: 'pdf',
          icon: Icons.picture_as_pdf,
          label: 'PDF (A4)',
          subtitle: context.l10n.attendanceFlutterStandardFormat,
        ),
        AppActionSheetAction(
          value: '2xa5',
          icon: Icons.content_cut,
          label: 'PDF (2x A5)',
          subtitle: context.l10n.attendanceFlutterTwoPlansOnePage,
        ),
        AppActionSheetAction(
          value: 'image',
          icon: Icons.image,
          label: context.l10n.attendanceFlutterAsImage,
          subtitle: context.l10n.attendanceFlutterQuickPreview,
        ),
      ],
    );
    if (result != null && mounted) await _sendPlanViaTelegram(format: result);
  }

  Future<void> _sendPlanViaTelegram({String format = 'pdf'}) async {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    final plan = attendance?.plan;

    if (plan == null || plan.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attendanceFlutterNoPlanToSend);
      return;
    }

    final fields = plan['fields'] as List?;
    if (fields == null || fields.isEmpty) {
      ToastHelper.showWarning(context, context.l10n.attendanceFlutterNoItemsToSend);
      return;
    }

    // Check Telegram connection
    final notificationConfig = await ref.read(notificationConfigProvider.future);
    if (notificationConfig == null || !notificationConfig.isConnected || notificationConfig.telegramChatId == null) {
      if (mounted) {
        ToastHelper.showError(
          context,
          context.l10n.attendanceFlutterTelegramNotConnected,
        );
      }
      return;
    }

    final chatId = notificationConfig.telegramChatId!;

    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.historyFlutterNoTenant);
      }
      return;
    }

    final startTime = plan['startTime'] as String? ?? attendance?.startTime ?? '17:00';
    final endTime = plan['endTime'] as String?;
    final dateStr = attendance?.formattedDate ?? DateTime.now().toIso8601String().substring(0, 10);

    try {
      final exportService = ExportService();
      late final Uint8List pdfBytes;
      if (format == '2xa5') {
        pdfBytes = await exportService.generatePlan2xA5PdfBytes(
          tenantName: tenant.shortName,
          date: dateStr,
          startTime: startTime,
          endTime: endTime,
          fields: fields.cast<Map<String, dynamic>>(),
        );
      } else {
        pdfBytes = await exportService.generatePlanPdfBytes(
          tenantName: tenant.shortName,
          date: dateStr,
          startTime: startTime,
          endTime: endTime,
          fields: fields.cast<Map<String, dynamic>>(),
        );
      }

      final telegramService = ref.read(telegramServiceProvider);
      await telegramService.sendPlanPerTelegram(
        fileBytes: pdfBytes,
        name: '${tenant.shortName}_Plan_$dateStr',
        chatId: chatId,
        asImage: format == 'image',
      );

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.attendanceFlutterPlanSentTelegram);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterSendFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  // ============== SHARE PLAN METHOD ==============

  Future<void> _toggleSharePlan(bool value) async {
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;

      await repo.updateAttendance(
        widget.attendanceId,
        {'share_plan': value},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          value ? context.l10n.attendanceFlutterPlanShared : context.l10n.attendanceFlutterPlanNotShared,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  // ============== SONGS/HISTORY METHODS ==============

  Future<void> _openSongsSelection() async {
    final result = await SongsSelectionSheet.show(
      context,
      existingEntries: _songEntries,
    );

    if (result != null && mounted) {
      setState(() {
        _songEntries = result;
      });
      await _saveSongEntries();
    }
  }

  Future<void> _removeSongEntry(int index) async {
    if (index < 0 || index >= _songEntries.length) return;

    setState(() {
      _songEntries.removeAt(index);
    });

    await _saveSongEntries();
    if (mounted) {
      ToastHelper.showSuccess(context, context.l10n.attendanceFlutterSongRemoved);
    }
  }

  Future<void> _saveSongEntries() async {
    // Prevent concurrent saves
    if (_isSavingSongs) return;
    _isSavingSongs = true;

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      if (!repo.hasTenantId || attendance == null) return;

      // LOGIC_ATT: like Ionic only the history table is written (no legacy
      // attendance.songs / conductors), row by row so unchanged entries keep
      // their id, created_at and visible flag.
      await _syncHistoryEntries(attendance.date);

      ref.invalidate(currentSongsProvider);
      ref.invalidate(songHistoryProvider(null));
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
    } finally {
      _isSavingSongs = false;
    }
  }

  /// Sync the history rows of this Termin with [_songEntries].
  Future<void> _syncHistoryEntries(String date) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final attendanceId = widget.attendanceId;
    final songEntries = List.of(_songEntries);

    final rows = await repo.getHistoryForAttendance(attendanceId);
    final plan = planHistorySync(
      [
        for (final r in rows)
          (
            id: (r['id'] as num).toInt(),
            songId: (r['songId'] as num).toInt(),
            personId: (r['person_id'] as num?)?.toInt(),
            otherConductor: r['otherConductor'] as String?,
          ),
      ],
      [
        for (final e in songEntries)
          (
            songId: e.songId,
            personId: e.otherConductor?.isNotEmpty == true ? null : e.conductorId,
            otherConductor: e.otherConductor?.isNotEmpty == true ? e.otherConductor : null,
          ),
      ],
    );

    for (final id in plan.delete) {
      await repo.deleteHistoryEntry(id);
    }
    for (final u in plan.update) {
      await repo.updateHistoryEntry(u.id, {
        'person_id': u.entry.personId,
        'otherConductor': u.entry.otherConductor,
      });
    }
    // Ionic addSongsToHistory: History columns songId (camelCase),
    // person_id, otherConductor, visible: true, date of the Termin.
    await repo.addHistoryEntries([
      for (final e in plan.insert)
        {
          'songId': e.songId,
          'attendance_id': attendanceId,
          'date': date,
          'person_id': e.personId,
          'otherConductor': e.otherConductor,
          'visible': true,
        },
    ]);
  }

  // ATTENDANCE_SIGNOUT: conductor change, date change, place, files folder,
  // registration fields (Ionic attendance.page.ts parity)

  /// Tap on a song entry: "Dirigent ändern" / "Zum Werk" (Ionic onHistoryEntryClick).
  Future<void> _onSongEntryTap(int index) async {
    if (index < 0 || index >= _songEntries.length) return;
    final entry = _songEntries[index];
    final action = await showAppActionSheet<String>(
      context,
      title: entry.songName,
      message: entry.displayConductor,
      actions: [
        AppActionSheetAction(
          value: 'conductor',
          icon: Icons.person_outline,
          label: context.l10n.attendanceChangeConductor,
        ),
        AppActionSheetAction(
          value: 'song',
          icon: Icons.music_note_outlined,
          label: context.l10n.attendanceToSong,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'song') {
      GoRouter.of(context).push('/songs/${entry.songId}');
      return;
    }
    await _changeConductor(index);
  }

  Future<void> _changeConductor(int index) async {
    final entry = _songEntries[index];
    final conductors = await ref.read(activeConductorsProvider.future);
    if (!mounted) return;
    final choice = await showConductorChangeDialog(
      context,
      conductors: conductors,
      currentConductorId: entry.conductorId,
      currentOtherConductor: entry.otherConductor,
    );
    if (choice == null || !mounted || index >= _songEntries.length) return;
    setState(() {
      _songEntries[index] = choice.person != null
          ? entry.copyWith(
              conductorId: choice.person!.id,
              conductorName: choice.person!.fullName,
              otherConductor: null,
            )
          : entry.copyWith(
              conductorId: null,
              conductorName: null,
              otherConductor: choice.otherConductor,
            );
    });
    await _saveSongEntries();
  }

  /// "Datum ändern" (Ionic promptAttendanceDateChange / changeAttendanceDate).
  Future<void> _changeDate() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    // SOL_FIX13: session of the acting user, captured before the first await.
    final offlineQueue = ref.read(offlineQueueNotifierProvider.notifier);
    final writeSession = offlineQueue.captureWriteSession();
    final playerAbsenceRepo = ref.read(playerAbsenceRepositoryWithTenantProvider);
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;
    final current = DateTime.tryParse(attendance.date)?.toLocal() ?? DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(current.year + 5),
      helpText: context.l10n.dateDialogMoveTo,
    );
    if (picked == null || !mounted) return;
    if (DateUtils.isSameDay(picked, current)) return;

    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    var reset = false;
    if (type != null && _localStatuses.values.any((s) => s != type.defaultStatus)) {
      final choice = await showAppDialog<String>(
        context: context,
        builder: (ctx) => AppAlertDialog(
          title: Text(context.l10n.dateDialogResetStatus),
          content: Text(
            context.l10n.dateDialogResetStatusMessage(ionicStatusLabel(type.defaultStatus)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(context.l10n.dateDialogKeep)),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'reset'), child: Text(context.l10n.dateDialogReset)),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      reset = choice == 'reset';
    }

    try {
      if (!repo.hasTenantId) return;
      final normalized = DateTime(picked.year, picked.month, picked.day, 12);
      final days = calendarDayDifference(current, normalized);
      final normalizedIso = normalized.toUtc().toIso8601String();

      // Deadline and checklist due dates move along with the Termin.
      String? shift(String? value) {
        if (value == null || value.isEmpty) return value;
        final d = DateTime.tryParse(value);
        return d == null ? value : shiftByCalendarDays(d, days).toIso8601String();
      }

      final checklist = attendance.checklist
          ?.map((item) => item.copyWith(dueDate: shift(item.dueDate)).toJson())
          .toList();
      await repo.updateAttendance(widget.attendanceId, {
        'date': normalizedIso,
        if (attendance.deadline != null) 'deadline': shift(attendance.deadline),
        if (checklist != null) 'checklist': checklist,
      });
      await repo.updateHistoryDatesForAttendance(widget.attendanceId, normalizedIso);
      if (type != null) {
        // LOGIC_ATT: Ionic changeAttendanceDate – absences on the new day
        // excuse persons still on the default status (or everyone when
        // reset), reset the rest, then re-run the shift computation.
        final rows = await ref.refresh(personAttendancesForAttendanceProvider(widget.attendanceId).future);
        List<PlayerAbsence> absences;
        try {
          absences = await playerAbsenceRepo.getAbsencesForTenant();
        } catch (_) {
          absences = const []; // non-fatal — proceed without absence check
        }
        final updates = dateChangeStatusUpdates(
          rows: [
            for (final r in rows)
              if (r.id != null && r.personId != null)
                (id: r.id!, personId: r.personId!, status: r.status, notes: r.notes),
          ],
          absences: absences,
          newDay: normalized,
          defaultStatus: type.defaultStatus,
          resetStatuses: reset,
        );
        // LEFTOVERS: like every Ionic updatePersonAttendance, queued while offline
        for (final u in updates) {
          final payload = {'status': u.status.value, 'notes': u.notes};
          if (await offlineQueue.enqueueIfOffline(u.id, payload,
              attendanceId: widget.attendanceId, session: writeSession)) {
            continue;
          }
          // SOL_FIX13: guarded by the session captured when the user acted.
          await repo.updatePersonAttendance(
            u.id,
            payload,
            isSessionCurrent: writeSession.isCurrent,
            actingUserId: writeSession.userId,
          );
        }
        await repo.updateShiftAssignmentsForAttendance(widget.attendanceId);
      }

      if (mounted) setState(() => _checklistLoaded = false);
      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          context.l10n.dateDialogMoved(DateFormat('EE, ${dateFmt()}', currentIntlLocale()).format(normalized)),
        );
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.dateDialogChangeFailed);
    }
  }

  Future<void> _updateAttendanceField(Map<String, dynamic> updates) async {
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(widget.attendanceId, updates);
      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  Future<void> _updatePlace(String value) =>
      _updateAttendanceField({'place': value.isEmpty ? null : value});

  Future<void> _chooseFilesFolder() async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    final path = await showFilesFolderPicker(
      context,
      tenantId: tenantId,
      initialPath: attendance?.filesFolder ?? '',
    );
    if (path == null || path.isEmpty) return;
    await _updateAttendanceField({'files_folder': path});
  }

  Future<void> _removeFilesFolder() => _updateAttendanceField({'files_folder': null});

  Map<int, String> _registrationSummaries(AttendanceType? type) {
    final fields = type?.registrationFields ?? const <RegistrationField>[];
    if (fields.isEmpty) return const {};
    final result = <int, String>{};
    _registrationAnswers.forEach((personId, answers) {
      if (answers == null || answers.isEmpty) return;
      final parts = <String>[];
      for (final f in fields) {
        final value = answers[f.id];
        if (value == null) continue;
        final text = registrationAnswerText(f, value);
        parts.add('${f.label}: ${text.isEmpty ? '–' : text}');
      }
      if (parts.isNotEmpty) result[personId] = parts.join(' · ');
    });
    return result;
  }

  /// "Anmeldefelder bearbeiten": merges the answers into registration_answers.
  Future<void> _editRegistrationFields(int personId, AttendanceType type) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    // SOL_FIX13: session of the acting user, captured before the first await.
    final offlineQueue = ref.read(offlineQueueNotifierProvider.notifier);
    final writeSession = offlineQueue.captureWriteSession();
    final personAttendanceId = _personAttendanceIds[personId];
    final fields = type.registrationFields ?? const <RegistrationField>[];
    if (personAttendanceId == null || fields.isEmpty) return;
    final existing = _registrationAnswers[personId];
    final answers = await showRegistrationFieldsSheet(
      context,
      fields: fields,
      existing: existing,
      editMode: true,
      requireText: false,
    );
    if (answers == null || !mounted) return;
    final merged = <String, dynamic>{...?existing, ...answers};
    try {
      // INTEGRATION: queue while offline like every Ionic updatePersonAttendance
      final queued = await offlineQueue.enqueueIfOffline(
          personAttendanceId, {'registration_answers': merged},
          attendanceId: widget.attendanceId, session: writeSession);
      if (!queued) {
        // SOL_FIX13: guarded by the session captured before the sheet.
        await repo.updatePersonAttendance(
          personAttendanceId,
          {'registration_answers': merged},
          isSessionCurrent: writeSession.isCurrent,
          actingUserId: writeSession.userId,
        );
      }
      if (mounted) {
        setState(() => _registrationAnswers[personId] = merged);
        ToastHelper.showSuccess(context, context.l10n.attendanceFlutterRegFieldsSaved);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
    }
  }

  // ============== GENERAL INFO METHODS ==============

  Future<void> _updateTypeInfo(String value) async {
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'typeInfo': value.isEmpty ? null : value},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _selectStartTime() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;

    // RT-011: Safe bounds check for split()
    TimeOfDay currentTime;
    if (attendance.startTime != null) {
      final parts = attendance.startTime!.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 17 : 17;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      currentTime = TimeOfDay(hour: hour, minute: minute);
    } else {
      currentTime = const TimeOfDay(hour: 17, minute: 0);
    }

    final selectedTime = await showAppTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime == null || !mounted) return;

    final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    final previous = attendance.startTime;

    try {
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'start_time': timeStr},
      );
      // LOGIC_ATT: Ionic onInfoChanged – the time window moved, re-run the
      // shift computation for everyone in this Termin.
      if (timeStr != previous) {
        await repo.updateShiftAssignmentsForAttendance(widget.attendanceId);
        ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      }

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.attendanceFlutterStartTimeUpdated);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _selectEndTime() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;

    // RT-011: Safe bounds check for split()
    TimeOfDay currentTime;
    if (attendance.endTime != null) {
      final parts = attendance.endTime!.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 20 : 20;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      currentTime = TimeOfDay(hour: hour, minute: minute);
    } else {
      currentTime = const TimeOfDay(hour: 20, minute: 0);
    }

    final selectedTime = await showAppTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime == null || !mounted) return;

    final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
    final previous = attendance.endTime;

    try {
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'end_time': timeStr},
      );
      // LOGIC_ATT: Ionic onInfoChanged – the time window moved, re-run the
      // shift computation for everyone in this Termin.
      if (timeStr != previous) {
        await repo.updateShiftAssignmentsForAttendance(widget.attendanceId);
        ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      }

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      if (!mounted) return;
      ToastHelper.showSuccess(context, context.l10n.attendanceFlutterEndTimeUpdated);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterErrorWith(friendlyErrorMessage(e)));
      }
    }
  }

  Future<void> _exportAttendanceToExcel() async {
    try {
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      final persons = ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull;
      final tenant = ref.read(currentTenantProvider);

      if (attendance == null || persons == null || tenant == null) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterDataUnavailable);
        return;
      }

      ToastHelper.showInfo(context, context.l10n.attendanceFlutterCreatingExcel);

      final exportService = ExportService();
      await exportService.exportAttendanceToExcel(
        context: context,
        attendance: attendance,
        persons: _personsInAttendance(persons),
        statuses: _localStatuses,
        tenantName: tenant.shortName,
      );
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.exportFlutterFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  // ============== PERSON REMOVE METHOD ==============

  Future<void> _removePersonFromAttendance(int personId) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final personAttendanceId = _personAttendanceIds[personId];
    if (personAttendanceId == null) {
      ToastHelper.showError(context, context.l10n.attendanceFlutterNoEntry);
      return;
    }

    final isValid = await _validatePersonAttendanceTenant(repo, personAttendanceId);
    if (!isValid) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterNoPermission);
      }
      return;
    }

    final name = (ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull ?? const [])
            .where((p) => p.id == personId)
            .firstOrNull
            ?.fullName ??
        '';
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.attendanceRemovePerson,
      message: context.l10n.attendanceRemovePersonConfirm(name),
      confirmText: context.l10n.commonRemove,
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      _ownDeletedPaIds.add(personAttendanceId);
      await repo.deletePersonAttendance(personAttendanceId);
      if (!mounted) return;

      setState(() {
        _localStatuses.remove(personId);
        _personAttendanceIds.remove(personId);
        _personNotes.remove(personId);
        _changedBy.remove(personId);
        _changedAt.remove(personId);
      });

      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      ref.invalidate(filteredPersonsForAttendanceProvider(widget.attendanceId));

      ToastHelper.showSuccess(context, context.l10n.attendancePersonRemoved);
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendancePersonRemoveFailed);
      }
    }
  }

  void _showStatsDialog() {
    final all = ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull ?? [];
    // PARITY_R5: Ionic counts `this.players` – all person rows of the Termin
    // (helper group only), not the search / status-filtered list and not
    // the tenant's other persons.
    final groupScope = resolvedGroupScope(ref.read(attendanceGroupScopeProvider));
    final inAttendance = _personsInAttendance(all);
    final persons = groupScope.isAll
        ? inAttendance
        : inAttendance.where((p) => groupScope.allowsGroup(p.instrument)).toList();
    final result = statusOverviewCounts(
      persons.map((p) => p.id).whereType<int>(),
      _localStatuses,
    );
    final statusCounts = result.counts;
    final total = result.total;

    showStatusOverviewSheet(
      context,
      statusCounts: statusCounts,
      total: total,
    );
  }

  Future<void> _takePhoto() async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final source = await showAppDialog<ImageSource>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: Text(context.l10n.attendanceFlutterAddPhoto),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(context.l10n.attendanceFlutterCamera),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.l10n.attendanceFlutterGallery),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );

    if (source == null) return;
    if (DemoGuard.blocked()) return; // DEMO_GUARD

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;
      ToastHelper.showInfo(context, context.l10n.attendanceFlutterUploadingPhoto);

      final bytes = await image.readAsBytes();

      if (!repo.hasTenantId) {
        if (mounted) {
          ToastHelper.showError(context, context.l10n.historyFlutterNoTenant);
        }
        return;
      }

      // DB_REVIEW_REST (H4): bucket `attendances`, key `<id>`, upsert (Ionic).
      await repo.uploadAttendanceImage(widget.attendanceId, bytes);

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));

      if (mounted) {
        ToastHelper.showSuccess(context, context.l10n.attendanceFlutterPhotoUploaded);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, context.l10n.attendanceFlutterUploadFailedWith(friendlyErrorMessage(e)));
      }
    }
  }

  /// Save a single person's attendance status immediately
  Future<void> _savePersonStatus(
    int personId,
    AttendanceStatus status, {
    AttendanceStatus? previousStatus,
  }) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    final personAttendanceId = _personAttendanceIds[personId];
    if (personAttendanceId == null) {
      if (mounted && previousStatus != null) {
        setState(() {
          _localStatuses[personId] = previousStatus;
        });
      }
      return;
    }

    // PROFILE_OFFLINE: queue the change while offline (Ionic OfflineQueueService)
    // SOL_FIX12: a write that could not be queued reverts and is reported.
    // SOL_FIX13: the session captured here also guards the direct write.
    final offlineQueue = ref.read(offlineQueueNotifierProvider.notifier);
    final writeSession = offlineQueue.captureWriteSession();
    try {
      if (await offlineQueue.enqueueIfOffline(
          personAttendanceId, {'status': status.value},
          attendanceId: widget.attendanceId, session: writeSession)) {
        return;
      }
    } catch (e) {
      if (mounted) {
        if (previousStatus != null) {
          setState(() => _localStatuses[personId] = previousStatus);
        }
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
      return;
    }

    final isValid = await _validatePersonAttendanceTenant(repo, personAttendanceId);
    if (!isValid) {
      if (mounted && previousStatus != null) {
        setState(() {
          _localStatuses[personId] = previousStatus;
        });
      }
      return;
    }

    _savingPersonIds.add(personId);
    try {
      await repo.updatePersonAttendance(
        personAttendanceId,
        {'status': status.value},
        isSessionCurrent: writeSession.isCurrent,
        actingUserId: writeSession.userId,
      );

      // Invalidate list provider so percentage updates when navigating back
      ref.invalidate(realtimeAttendanceListProvider);

      // DUTY: status changes also change the assignment (synced in the repository)
      if (ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull?.dutyMode ?? false) {
        ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      }
    } catch (e) {
      if (mounted) {
        if (previousStatus != null) {
          setState(() {
            _localStatuses[personId] = previousStatus;
          });
        }
        ToastHelper.showError(context, context.l10n.attendanceFlutterSaveFailedWith(friendlyErrorMessage(e)));
      }
    } finally {
      _savingPersonIds.remove(personId);
    }
  }
}

/// Whether [role] may use the mutating attendance-detail actions (add
/// persons, checklist, reminder, photo, description). Viewers are read-only
/// and helpers only set statuses.
bool canMutateAttendanceDetail(Role role) =>
    role.canEdit && !role.isHelperRole;

/// IOS_DETAIL: "Beschreibung & Anhang bearbeiten" – Ionic shows it on the
/// attendance page for every role that edits Termine (Helfer included, like
/// Info-Text / Notizen); viewers and players stay read-only.
bool canEditAttendanceDescription(Role role) => role.canEdit;

/// LEFTOVERS: whether a realtime person_attendances payload carries a
/// duty_state that differs from the loaded row (Ionic copies duty_state from
/// the payload in onPersonAttRealtimeChanges).
bool realtimeDutyStateChanged(Map<String, dynamic> newRecord, List<PersonAttendance> rows) {
  if (!newRecord.containsKey('duty_state')) return false;
  final id = newRecord['id']?.toString();
  if (id == null) return false;
  final row = rows.where((r) => r.id == id).firstOrNull;
  if (row == null) return false;
  final incoming = newRecord['duty_state']?.toString();
  return (incoming ?? '') != (row.dutyState ?? '');
}

/// SOL_FIX35: whole calendar days between the local dates of [from] and
/// [to]. Computed on UTC date values, so a DST change in between (e.g.
/// 29.03.→30.03.2026 in Europe/Berlin, only 23 hours) still counts 1.
int calendarDayDifference(DateTime from, DateTime to) {
  final a = from.isUtc ? from.toLocal() : from;
  final b = to.isUtc ? to.toLocal() : to;
  return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// SOL_FIX35: moves [value] by [days] calendar days keeping its local wall
/// time across DST changes; a UTC value stays UTC.
DateTime shiftByCalendarDays(DateTime value, int days) {
  final l = value.isUtc ? value.toLocal() : value;
  final moved = DateTime(l.year, l.month, l.day + days, l.hour, l.minute, l.second, l.millisecond, l.microsecond);
  return value.isUtc ? moved.toUtc() : moved;
}
