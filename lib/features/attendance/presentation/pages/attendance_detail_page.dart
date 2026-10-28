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
import '../../../../core/providers/profile_providers.dart'; // ATT_DETAIL
import '../../../../core/utils/shift_utils.dart'; // ATT_DETAIL
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
import '../../../self_service/presentation/widgets/self_service_event_actions.dart';
import '../../../duty/presentation/widgets/duty_staffing_section.dart';
import '../widgets/attendance_detail/attendance_detail_widgets.dart';
import '../widgets/attendance_legend_sheet.dart';
import '../widgets/attendance_status_overview_sheet.dart';
import '../widgets/songs_selection_sheet.dart';

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

  // Local checklist state - maintained separately to allow editing
  List<ChecklistItem> _localChecklist = [];
  bool _checklistLoaded = false;

  // Plan accordion state - expand after returning from planning with changes
  bool _planAccordionExpanded = false;

  // Click mode: tap cycles status instead of opening picker
  bool _clickMode = false;

  // Local songs/history entries
  List<SongHistoryEntry> _songEntries = [];
  bool _isSavingSongs = false;

  // ATT_DETAIL: view options (Ionic statusFilter / extraFieldSort / showAvatars / showRegFields)
  Set<AttendanceStatus> _statusFilter = {};
  AttendanceSort _sort = const AttendanceSort();
  bool _showAvatars = false;
  bool _showRegFields = true;
  bool _deletedHandled = false;
  bool _isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    // Subscribe to realtime changes and ensure PersonAttendances exist after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force fresh data from DB (handles cross-device changes and stale autoDispose cache)
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      _subscribeToRealtimeChanges();
      _ensurePersonAttendancesExist();
      _setupProviderListener();
      _loadChecklistFromAttendance();
      _loadSongEntries();
      _loadViewPrefs(); // ATT_DETAIL
    });
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
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;

    final songIds = attendance.songs ?? [];
    final conductorIds = attendance.conductors ?? [];

    if (songIds.isEmpty) {
      if (mounted) {
        setState(() {
          _songEntries = [];
        });
      }
      return;
    }

    // Load songs and conductors from providers to resolve names
    final songs = await ref.read(songsProvider.future);
    final conductors = await ref.read(activeConductorsProvider.future);
    final allConductors = await ref.read(conductorsProvider.future);

    // Prefer the history rows: they keep the conductor per song including
    // "Anderer Dirigent" (otherConductor).
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (repo.hasTenantId) {
        final rows = await repo.getHistoryForAttendance(widget.attendanceId);
        if (rows.isNotEmpty) {
          final fromHistory = rows.map((row) {
            final songId = row['songId'] as int;
            final personId = row['person_id'] as int?;
            final other = row['otherConductor'] as String?;
            final song = songs.where((s) => s.id == songId).firstOrNull;
            final conductor = allConductors.where((c) => c.id == personId).firstOrNull;
            return SongHistoryEntry(
              songId: songId,
              songName: song?.displayName ?? 'Unbekanntes Werk',
              conductorId: personId,
              conductorName: conductor?.fullName,
              otherConductor: other?.isNotEmpty == true ? other : null,
            );
          }).toList();
          if (mounted) setState(() => _songEntries = fromHistory);
          return;
        }
      }
    } catch (_) {
      // fall back to the songs/conductors arrays below
    }

    // Create entries with resolved names
    final entries = <SongHistoryEntry>[];
    for (var i = 0; i < songIds.length; i++) {
      final songId = songIds[i];
      final conductorId = i < conductorIds.length ? conductorIds[i] : null;

      // Find song name
      final song = songs.where((s) => s.id == songId).firstOrNull;
      final songName = song?.displayName ?? 'Unbekanntes Werk';

      // Find conductor name
      String? conductorName;
      if (conductorId != null) {
        final conductor = conductors.where((c) => c.id == conductorId).firstOrNull;
        conductorName = conductor?.fullName;
      }

      entries.add(SongHistoryEntry(
        songId: songId,
        songName: songName,
        conductorId: conductorId,
        conductorName: conductorName,
      ));
    }

    if (mounted) {
      setState(() {
        _songEntries = entries;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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

  /// Ensures PersonAttendance records exist for this attendance.
  Future<void> _ensurePersonAttendancesExist() async {
    final personAttendances = await ref.read(personAttendancesForAttendanceProvider(widget.attendanceId).future);
    if (personAttendances.isNotEmpty) return;

    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return;

    final attendanceType = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final defaultStatus = attendanceType?.defaultStatus ?? AttendanceStatus.neutral;

    await repo.ensurePersonAttendances(widget.attendanceId, defaultStatus.value);

    if (!mounted) return;
    ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
  }

  void _onPersonAttendanceChange(dynamic payload) {
    if (_isDisposed) return;

    final newRecord = payload.newRecord as Map<String, dynamic>?;
    if (newRecord == null || newRecord.isEmpty) return;

    final personId = newRecord['person_id'] as int?;
    if (personId != null && _savingPersonIds.contains(personId)) return;

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
        ToastHelper.showSuccess(context, 'Verbindung wiederhergestellt');
      } else {
        ToastHelper.showError(context, 'Keine Internetverbindung vorhanden');
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
        appBar: AppBar(title: const Text('Anwesenheit')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      // ATT_DETAIL: Ionic "loadFailedReopen" / "Neu laden"
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Anwesenheit')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                const SizedBox(height: AppDimensions.paddingM),
                const Text(
                  'Anwesenheit konnte nicht geladen werden — bitte erneut öffnen.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(attendanceDetailProvider(widget.attendanceId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu laden'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (attendance) {
        if (attendance == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Anwesenheit')),
            body: const Center(child: Text('Anwesenheit nicht gefunden')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attendance.displayTitle),
                Text(
                  attendance.formattedDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.medium,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _clickMode ? Icons.touch_app : Icons.touch_app_outlined,
                  color: _clickMode ? AppColors.primary : null,
                ),
                tooltip: _clickMode ? 'Klick-Modus aktiv' : 'Klick-Modus',
                onPressed: () => setState(() => _clickMode = !_clickMode),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Legende',
                onPressed: () => showAttendanceLegendSheet(context),
              ),
              PopupMenuButton<String>(
                onSelected: _handleMenuAction,
                // ATT_DETAIL: badge with the number of active status filters
                icon: Badge(
                  isLabelVisible: _statusFilter.isNotEmpty,
                  label: Text('${_statusFilter.length}'),
                  child: Icon(
                    Icons.more_vert,
                    color: _statusFilter.isNotEmpty ? AppColors.primary : null,
                  ),
                ),
                itemBuilder: (context) => [
                  ..._buildAttDetailMenuItems(attendance),
                  const PopupMenuItem(
                    value: 'stats',
                    child: ListTile(
                      leading: Icon(Icons.bar_chart),
                      title: Text('Statistik'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'notes',
                    child: ListTile(
                      leading: Icon(Icons.note_add),
                      title: Text('Notizen'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'photo',
                    child: ListTile(
                      leading: Icon(Icons.camera_alt),
                      title: Text('Foto'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'export_excel',
                    child: ListTile(
                      leading: Icon(Icons.table_chart),
                      title: Text('Excel exportieren'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: personsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            // ATT_DETAIL: "Neu laden" banner
            error: (error, stack) => ListView(children: [_buildLoadFailedBanner()]),
            data: (persons) {
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
              final helperGroupId = ref.watch(helperGroupFilterProvider).valueOrNull;
              final groupPersons = helperGroupId == null
                  ? _personsInAttendance(persons)
                  : _personsInAttendance(persons).where((p) => p.instrument == helperGroupId).toList();
              // ATT_DETAIL: status filter + extra field sort
              final sortFields = _sortableFields(attendanceType);
              final sortField = sortFields.where((f) => f.id == _sort.fieldId).firstOrNull;
              final churches = ref.watch(churchesProvider).valueOrNull ?? const [];
              final statusFiltered = filterPersonsByStatus(groupPersons, _localStatuses, _statusFilter);
              final visiblePersons = sortField == null
                  ? statusFiltered
                  : sortPersonsByField(statusFiltered, _sort, sortField, _registrationAnswers, churches);
              final sortLines = sortField == null
                  ? null
                  : {
                      for (final p in visiblePersons)
                        if (p.id != null)
                          p.id!: '${sortDisplayValueOf(p, _sort, sortField, _registrationAnswers, churches)}'
                              ' · ${p.groupName ?? 'Keine Gruppe'}',
                    };
              final isHelper = ref.watch(effectiveRoleProvider).isHelperRole;
              final visibleNotes = canViewNotes
                  ? _personNotes
                  : {
                      for (final e in _personNotes.entries)
                        e.key: (e.value?.isNotEmpty ?? false) ? 'Notiz hinzugefügt' : e.value,
                    };
              final hasChecklist = canViewChecklist &&
                  (_localChecklist.isNotEmpty || (attendanceType?.checklist?.isNotEmpty ?? false));
              final hasSongs = attendanceType?.manageSongs ?? false;

              return CustomScrollView(
                slivers: [
                  // Offline banner
                  SliverToBoxAdapter(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
                        if (isOnline) return const SizedBox.shrink();
                        // PROFILE_OFFLINE: show pending offline writes
                        final pending = ref.watch(offlinePendingCountProvider);
                        return MaterialBanner(
                          content: Text(pending > 0
                              ? 'Offline – $pending ausstehend. Änderungen werden gespeichert, sobald du wieder online bist.'
                              : 'Offline – Änderungen werden gespeichert, sobald du wieder online bist.'),
                          leading: const Icon(Icons.wifi_off, color: AppColors.warning),
                          backgroundColor: AppColors.warning.withAlpha(30),
                          actions: [
                            TextButton(
                              onPressed: () {},
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: AppDimensions.paddingS),

                        GeneralInfoAccordion(
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
                                ToastHelper.showError(context, 'Fehler: $e');
                              }
                            }
                          },
                          onStartTimeSelect: _selectStartTime,
                          onEndTimeSelect: _selectEndTime,
                          onDeadlineToggle: _toggleDeadline,
                          onDeadlineSelect: _selectDeadline,
                          onExportExcel: _exportAttendanceToExcel,
                          hasNeutralStatuses: _localStatuses.isEmpty || _localStatuses.values.any((s) => s.isNeutral),
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
                          onEditDescription: () =>
                              showDescriptionAttachmentSheet(context, attendance: attendance),
                        ),

                        if (hasChecklist)
                          ChecklistAccordion(
                            checklist: _localChecklist,
                            onToggle: _toggleChecklistItem,
                            onAdd: _addChecklistItem,
                            onRemove: _removeChecklistItem,
                            onRestore: _restoreChecklist,
                            getDeadlineStatus: _getDeadlineStatus,
                            formatDeadlineRelative: _formatDeadlineRelative,
                          ),

                        if (hasSongs)
                          SongsHistoryAccordion(
                            entries: _songEntries,
                            onAdd: _openSongsSelection,
                            onRemove: _removeSongEntry,
                            onTap: _onSongEntryTap,
                          ),

                        // ORG_PLANS: observers (viewer role) must not see the plan
                        if (!ref.watch(effectiveRoleProvider).isViewer)
                        PlanAccordion(
                          attendance: attendance,
                          initiallyExpanded: _planAccordionExpanded,
                          onCreate: () async {
                            final hasChanges = await context.push<bool>('/planning?attendanceId=${widget.attendanceId}');
                            if (hasChanges == true && mounted) {
                              setState(() => _planAccordionExpanded = true);
                            }
                          },
                          onEdit: () async {
                            final hasChanges = await context.push<bool>('/planning?attendanceId=${widget.attendanceId}');
                            if (hasChanges == true && mounted) {
                              setState(() => _planAccordionExpanded = true);
                            }
                          },
                          onExportPdf: _exportPlanPdf,
                          onSendViaTelegram: _showTelegramFormatOptions,
                          onSharePlanChanged: _toggleSharePlan,
                        ),

                        // DUTY: Dienstplan "Besetzung"
                        if (attendanceType != null && attendanceType.dutyMode && attendance.id != null)
                          DutyStaffingSection(
                            attendance: attendance,
                            attendanceType: attendanceType,
                          ),

                        const SizedBox(height: AppDimensions.paddingS),
                      ],
                    ),
                  ),

                  // ATT_DETAIL: no persons could be loaded
                  if (persons.isEmpty && helperGroupId == null)
                    SliverToBoxAdapter(child: _buildLoadFailedBanner()),

                  SliverToBoxAdapter(
                    child: AttendanceGrid(
                      persons: visiblePersons,
                      localStatuses: _localStatuses,
                      personNotes: visibleNotes,
                      availableStatuses: availableStatuses,
                      clickMode: _clickMode,
                      onStatusChanged: (personId, status) {
                        final previousStatus = _localStatuses[personId];
                        setState(() {
                          _localStatuses[personId] = status;
                        });
                        _savePersonStatus(personId, status, previousStatus: previousStatus);
                      },
                      // Maskierte Notiz nicht als neuen Wert zurückschreiben
                      onNoteChanged: (personId, notes) {
                        if (!canViewNotes && notes == 'Notiz hinzugefügt') return;
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
                          ToastHelper.showWarning(context, 'Die Person hat keinen Account');
                          return;
                        }
                        _sendAdHocReminder(playerAppId: appId);
                      },
                      onEditRegistrationFields: (attendanceType?.registrationFields?.isNotEmpty ?? false)
                          ? (personId) => _editRegistrationFields(personId, attendanceType!)
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: AttendanceStatusBar(
            persons: _personsInAttendance(personsAsync.valueOrNull ?? []),
            localStatuses: _localStatuses,
            availableStatuses: availableStatuses,
          ),
        );
      },
    );
  }

  /// Validate that a personAttendance belongs to current tenant
  Future<bool> _validatePersonAttendanceTenant(String personAttendanceId) async {
    final repo = ref.read(attendanceRepositoryWithTenantProvider);
    if (!repo.hasTenantId) return false;
    return repo.validatePersonAttendanceTenant(personAttendanceId);
  }

  /// Update notes for a specific person
  Future<void> _updatePersonNote(int personId, String? notes) async {
    final personAttendanceId = _personAttendanceIds[personId];
    if (personAttendanceId == null) {
      ToastHelper.showError(context, 'Kein Anwesenheitseintrag gefunden');
      return;
    }

    // INTEGRATION: queue while offline like every Ionic updatePersonAttendance
    if (await ref.read(offlineQueueNotifierProvider.notifier).enqueueIfOffline(
        personAttendanceId, {'notes': notes ?? ''},
        attendanceId: widget.attendanceId)) {
      if (mounted) setState(() => _personNotes[personId] = notes);
      return;
    }

    final isValid = await _validatePersonAttendanceTenant(personAttendanceId);
    if (!isValid) {
      if (mounted) {
        ToastHelper.showError(context, 'Keine Berechtigung');
      }
      return;
    }

    // Show the note immediately; the provider listener is guarded via
    // _savingPersonIds so a stale refetch cannot overwrite it.
    final previousNote = _personNotes[personId];
    if (mounted) setState(() => _personNotes[personId] = notes);
    _savingPersonIds.add(personId);

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.updatePersonAttendance(personAttendanceId, {'notes': notes ?? ''});

      if (mounted) {
        ToastHelper.showSuccess(context, notes?.isNotEmpty == true ? 'Notiz hinzugefügt' : 'Notiz gelöscht');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _personNotes[personId] = previousNote);
        ToastHelper.showError(context, 'Fehler: $e');
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
      ToastHelper.showWarning(context, 'Der Status wurde bisher nicht verändert');
      return;
    }
    final persons = ref.read(allPersonsForAttendanceProvider).valueOrNull ?? [];
    final modifier = persons.where((p) => p.appId == changedBy).firstOrNull;
    final modifierName = modifier != null && modifier.fullName.isNotEmpty
        ? modifier.fullName
        : "'Unbekannt'";
    var message = 'Zuletzt geändert von $modifierName';
    final date = changedAt == null ? null : DateTime.tryParse(changedAt)?.toLocal();
    if (date != null) {
      message += ' am ${DateFormat('dd.MM.yyyy').format(date)} um ${DateFormat('HH:mm').format(date)} Uhr';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'stats':
        _showStatsDialog();
        break;
      case 'notes':
        _showNotesDialog();
        break;
      case 'photo':
        _takePhoto();
        break;
      case 'export_excel':
        _exportAttendanceToExcel();
        break;
      // ATT_DETAIL
      case 'status_filter':
        _openStatusFilter();
        break;
      case 'sort':
        _openSortPicker();
        break;
      case 'view':
        _openViewOptions();
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
  List<Person> _personsInAttendance(List<Person> persons) {
    final rows = ref.read(filteredPersonAttendancesForAttendanceProvider(widget.attendanceId)).valueOrNull;
    if (rows == null || rows.isEmpty) return persons;
    final ids = _personAttendanceIds.keys.toSet();
    return persons.where((p) => ids.contains(p.id)).toList();
  }

  List<SortableField> _sortableFields(AttendanceType? type) {
    final personFields = ref.watch(personExtraFieldsProvider).valueOrNull ?? const [];
    return sortableFields(personFields, type?.registrationFields ?? const []);
  }

  /// Id of the `bfecg_church` extra field, if the tenant has one.
  String? _churchFieldId() {
    final fields = ref.read(personExtraFieldsProvider).valueOrNull ?? const [];
    return fields.where((f) => f.type == 'bfecg_church').firstOrNull?.id;
  }

  List<PopupMenuEntry<String>> _buildAttDetailMenuItems(Attendance attendance) {
    final role = ref.read(effectiveRoleProvider);
    final isHelper = role.isHelperRole;
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final sortFields = sortableFields(
      ref.read(personExtraFieldsProvider).valueOrNull ?? const [],
      type?.registrationFields ?? const [],
    );
    final hasChurch = _churchFieldId() != null;
    final checklistEmpty = _localChecklist.isEmpty;
    final canRestore = (type?.checklist?.isNotEmpty ?? false) && checklistEmpty;
    final activeSort = sortFields.where((f) => f.id == _sort.fieldId).firstOrNull;

    PopupMenuItem<String> item(String value, IconData icon, String title,
            {String? subtitle, bool highlight = false}) =>
        PopupMenuItem<String>(
          value: value,
          child: ListTile(
            leading: Icon(icon, color: highlight ? AppColors.primary : null),
            title: Text(title, style: TextStyle(color: highlight ? AppColors.primary : null)),
            subtitle: subtitle == null ? null : Text(subtitle),
            contentPadding: EdgeInsets.zero,
          ),
        );

    return [
      item('status_filter', Icons.filter_list, 'Status-Filter',
          subtitle: _statusFilter.isEmpty ? null : '${_statusFilter.length} aktiv',
          highlight: _statusFilter.isNotEmpty),
      if (sortFields.isNotEmpty)
        item('sort', Icons.swap_vert, 'Sortierung',
            subtitle: activeSort == null ? null : '${activeSort.name} ${_sort.ascending ? '↑' : '↓'}'),
      item('view', Icons.visibility_outlined, 'Ansicht'),
      if (!isHelper) item('add_person', Icons.person_add_alt_1_outlined, 'Person hinzufügen'),
      if (!isHelper && checklistEmpty)
        item('start_checklist', Icons.check_box_outlined, 'Checkliste starten'),
      if (!isHelper && canRestore)
        item('reset_checklist', Icons.refresh, 'Checkliste zurücksetzen'),
      if (hasChurch) item('church', Icons.business_outlined, 'Gemeinde-Übersicht'),
      if (!isHelper) item('reminder', Icons.notifications_outlined, 'Erinnerung versenden'),
      const PopupMenuDivider(),
    ];
  }

  /// Status filter sheet (Ionic toggleStatusFilter / clearStatusFilter).
  Future<void> _openStatusFilter() async {
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final available = (type?.availableStatuses?.isNotEmpty ?? false)
        ? type!.availableStatuses!
        : AttendanceStatus.values;
    final options = <(AttendanceStatus, String)>[
      if (available.contains(AttendanceStatus.neutral)) (AttendanceStatus.neutral, 'Neutral'),
      if (available.contains(AttendanceStatus.present)) (AttendanceStatus.present, 'Anwesend'),
      if (available.contains(AttendanceStatus.excused)) (AttendanceStatus.excused, 'Entschuldigt'),
      if (available.contains(AttendanceStatus.late)) (AttendanceStatus.late, 'Verspätet'),
      if (available.contains(AttendanceStatus.late))
        (AttendanceStatus.lateExcused, 'Verspätet entschuldigt'),
      if (available.contains(AttendanceStatus.absent)) (AttendanceStatus.absent, 'Abwesend'),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void toggle(AttendanceStatus s) {
            setState(() {
              final next = {..._statusFilter};
              if (!next.remove(s)) next.add(s);
              _statusFilter = next;
            });
            setSheetState(() {});
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text('Status-Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final (status, label) in options)
                  CheckboxListTile(
                    value: _statusFilter.contains(status),
                    onChanged: (_) => toggle(status),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(label),
                  ),
                if (_statusFilter.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.highlight_off, color: AppColors.danger),
                    title: const Text('Filter löschen', style: TextStyle(color: AppColors.danger)),
                    onTap: () {
                      setState(() => _statusFilter = {});
                      setSheetState(() {});
                    },
                  ),
                const SizedBox(height: AppDimensions.paddingS),
              ],
            ),
          );
        },
      ),
    );
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
    final result = await showDialog<String>(
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
          return AlertDialog(
            title: const Text('Sortierung'),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  radio('__default__', 'Standard (Gruppe)'),
                  for (final f in fields) ...[
                    radio('${f.id}__asc', '${f.name} ↑'),
                    radio('${f.id}__desc', '${f.name} ↓'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
              TextButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('OK')),
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

  /// "Ansicht": Bilder anzeigen / Anmeldefelder anzeigen / Explizite Statusauswahl.
  Future<void> _openViewOptions() async {
    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    final hasRegFields = type?.registrationFields?.isNotEmpty ?? false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Ansicht', style: TextStyle(fontWeight: FontWeight.bold))),
              CheckboxListTile(
                value: _showAvatars,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Bilder anzeigen'),
                onChanged: (v) {
                  setState(() => _showAvatars = v ?? false);
                  setSheetState(() {});
                  _savePref((p) => p.setBool(_prefShowAvatars, _showAvatars));
                },
              ),
              if (hasRegFields)
                CheckboxListTile(
                  value: _showRegFields,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Anmeldefelder anzeigen'),
                  onChanged: (v) {
                    setState(() => _showRegFields = v ?? true);
                    setSheetState(() {});
                    _savePref((p) => p.setBool(_prefShowRegFields, _showRegFields));
                  },
                ),
              CheckboxListTile(
                value: !_clickMode,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Explizite Statusauswahl'),
                subtitle: const Text('Status über Dropdown statt Antippen wählen'),
                onChanged: (v) {
                  setState(() => _clickMode = !(v ?? true));
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: AppDimensions.paddingS),
            ],
          ),
        ),
      ),
    );
  }

  /// "Person hinzufügen" (Ionic openAddPersonModal / addPersonsToAttendance).
  Future<void> _openAddPersons() async {
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
      if (mounted) ToastHelper.showError(context, 'Fehler beim Laden der Personen');
      return;
    }
    if (!mounted) return;
    final selected = await showAddPersonsSheet(
      context,
      candidates: candidates,
      groupNameOf: (p) => p.groupName ?? 'Keine Gruppe',
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    try {
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
      final defaultStatus = type?.defaultStatus ?? AttendanceStatus.neutral;
      final date = DateTime.tryParse(attendance?.date ?? '') ?? DateTime.now();
      final all = [...candidates.matching, ...candidates.others];
      final records = <PersonAttendance>[];
      for (final personId in selected) {
        final person = all.where((p) => p.id == personId).firstOrNull;
        if (person == null) continue;
        var status = defaultStatus;
        var notes = '';
        if (person.shiftId != null && type?.allDay != true) {
          final result = ShiftUtils.getStatusByShift(
            shiftId: person.shiftId,
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
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.createPersonAttendances(records);
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        records.length == 1 ? '1 Person hinzugefügt' : '${records.length} Personen hinzugefügt',
      );
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Hinzufügen der Personen');
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
      subtitle: 'Anwesende',
    );
  }

  /// "Erinnerung versenden" for the Termin or one person
  /// (`send-ad-hoc-reminder` Edge Function, push + e-mail).
  Future<void> _sendAdHocReminder({String? playerAppId}) async {
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
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.sendAdHocReminder(
        attendanceId: widget.attendanceId,
        title: result.title,
        message: result.message,
        playerAppId: playerAppId,
        playerAppIds: (result.neutralOnly && playerAppId == null) ? neutralAppIds : null,
      );
      if (mounted) ToastHelper.showSuccess(context, 'Erinnerung versendet');
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Fehler beim Versenden');
    } finally {
      _isSendingReminder = false;
    }
  }

  /// Leaves the page when the Termin is deleted by someone else
  /// (Ionic onAttRealtimeChanges "deletedByOther").
  void _onAttendanceDeleted(PostgresChangePayload payload) {
    final oldId = payload.oldRecord['id'];
    if (oldId == null || oldId.toString() != widget.attendanceId.toString()) return;
    if (_isDisposed || !mounted || _deletedHandled) return;
    _deletedHandled = true;
    ToastHelper.showError(context, 'Die Anwesenheit wurde soeben von einem anderen Nutzer gelöscht');
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Anwesenheitsliste konnte nicht geladen werden',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Bitte versuche es erneut.', style: TextStyle(color: AppColors.medium)),
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
              label: const Text('Neu laden'),
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
    final result = await showDialog<({String text, int? hours})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('To-Do hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'To-Do Text...'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Deadline in Stunden (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isEmpty) {
                ToastHelper.showWarning(ctx, 'Bitte einen Text eingeben');
                return;
              }
              Navigator.pop(ctx, (
                text: textController.text.trim(),
                hours: int.tryParse(hoursController.text.trim()),
              ));
            },
            child: const Text('Hinzufügen'),
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
      ToastHelper.showSuccess(context, 'To-Do hinzugefügt');
    }
  }

  Future<void> _removeChecklistItem(int index) async {
    if (index < 0 || index >= _localChecklist.length) return;

    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'To-Do löschen?',
      message: 'Möchtest du dieses To-Do wirklich löschen?',
      confirmText: 'Löschen',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      setState(() {
        _localChecklist.removeAt(index);
      });

      await _saveChecklist();
      if (!mounted) return;
      ToastHelper.showSuccess(context, 'To-Do gelöscht');
    }
  }

  Future<void> _restoreChecklist({bool confirm = true}) async {
    final attendanceType = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    if (attendanceType?.checklist == null || attendanceType!.checklist!.isEmpty) {
      ToastHelper.showWarning(context, 'Keine Standard-Checkliste vorhanden');
      return;
    }

    // ATT_DETAIL: "Checkliste zurücksetzen" from the menu restores without asking (Ionic)
    final confirmed = !confirm ||
        await DialogHelper.showConfirmation(
          context,
          title: 'Checkliste wiederherstellen?',
          message: 'Die aktuelle Checkliste wird durch die Standard-Checkliste ersetzt.',
          confirmText: 'Wiederherstellen',
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
      ToastHelper.showSuccess(context, 'Checkliste wiederhergestellt');
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
        ToastHelper.showError(context, 'Fehler beim Speichern: $e');
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

    if (diff.isNegative) {
      final absDiff = diff.abs();
      if (absDiff.inDays > 0) {
        return '${absDiff.inDays} Tag(e) überfällig';
      } else if (absDiff.inHours > 0) {
        return '${absDiff.inHours} Std. überfällig';
      } else {
        return 'überfällig';
      }
    } else {
      if (diff.inDays > 0) {
        return 'in ${diff.inDays} Tag(en)';
      } else if (diff.inHours > 0) {
        return 'in ${diff.inHours} Std.';
      } else {
        return 'in ${diff.inMinutes} Min.';
      }
    }
  }

  // ============== DEADLINE METHODS ==============

  Future<void> _toggleDeadline(bool enabled) async {
    String? deadlineStr;

    if (enabled) {
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      if (attendance != null) {
        final attendanceDate = DateTime.tryParse(attendance.date);
        if (attendanceDate != null) {
          final defaultDeadline = attendanceDate.subtract(const Duration(days: 1));
          deadlineStr = defaultDeadline.toIso8601String();
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
          enabled ? 'Anmeldefrist aktiviert' : 'Anmeldefrist deaktiviert',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _selectDeadline() async {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;

    final attendanceDate = DateTime.tryParse(attendance.date);
    final currentDeadline = attendance.deadline != null
        ? DateTime.tryParse(attendance.deadline!)
        : null;

    final now = DateTime.now();
    final initialDate = currentDeadline ?? attendanceDate?.subtract(const Duration(days: 1)) ?? now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: attendanceDate ?? now.add(const Duration(days: 365)),
      helpText: 'Anmeldefrist wählen',
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
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
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'deadline': finalDeadline.toIso8601String()},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));

      if (mounted) {
        ToastHelper.showSuccess(context, 'Anmeldefrist aktualisiert');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  // ============== PLAN EXPORT METHODS ==============

  Future<void> _exportPlanPdf() async {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    final plan = attendance?.plan;

    if (plan == null || plan.isEmpty) {
      ToastHelper.showWarning(context, 'Kein Ablaufplan zum Exportieren');
      return;
    }

    final fields = plan['fields'] as List?;
    if (fields == null || fields.isEmpty) {
      ToastHelper.showWarning(context, 'Keine Programmpunkte zum Exportieren');
      return;
    }

    // Show format selection dialog
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export-Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('A4 (Standard)'),
              subtitle: const Text('Ein Plan pro Seite'),
              onTap: () => Navigator.pop(context, 'a4'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: const Text('2x A5 auf A4'),
              subtitle: const Text('Zwei identische Pläne (Querformat)'),
              onTap: () => Navigator.pop(context, '2xa5'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (format == null || !mounted) return;

    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) {
      ToastHelper.showError(context, 'Kein Tenant ausgewählt');
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
        ToastHelper.showError(context, 'Fehler beim Export: $e');
      }
    }
  }

  Future<void> _showTelegramFormatOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF (A4)'),
              subtitle: const Text('Standard-Format'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: const Text('PDF (2x A5)'),
              subtitle: const Text('Zwei Pläne auf einer Seite'),
              onTap: () => Navigator.pop(ctx, '2xa5'),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Als Bild'),
              subtitle: const Text('Für schnelle Vorschau'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null && mounted) await _sendPlanViaTelegram(format: result);
  }

  Future<void> _sendPlanViaTelegram({String format = 'pdf'}) async {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    final plan = attendance?.plan;

    if (plan == null || plan.isEmpty) {
      ToastHelper.showWarning(context, 'Kein Ablaufplan zum Senden');
      return;
    }

    final fields = plan['fields'] as List?;
    if (fields == null || fields.isEmpty) {
      ToastHelper.showWarning(context, 'Keine Programmpunkte zum Senden');
      return;
    }

    // Check Telegram connection
    final notificationConfig = await ref.read(notificationConfigProvider.future);
    if (notificationConfig == null || !notificationConfig.isConnected || notificationConfig.telegramChatId == null) {
      if (mounted) {
        ToastHelper.showError(
          context,
          'Telegram nicht verbunden. Bitte zuerst in den Einstellungen verbinden.',
        );
      }
      return;
    }

    final chatId = notificationConfig.telegramChatId!;

    final tenant = ref.read(currentTenantProvider);
    if (tenant == null) {
      if (mounted) {
        ToastHelper.showError(context, 'Kein Tenant ausgewählt');
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
        ToastHelper.showSuccess(context, 'Plan per Telegram gesendet');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Senden: $e');
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
          value ? 'Plan wird jetzt mit Mitgliedern geteilt' : 'Plan wird nicht mehr geteilt',
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
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
      ToastHelper.showSuccess(context, 'Werk entfernt');
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

      final songIds = _songEntries.map((e) => e.songId).toList();
      final conductorIds = _songEntries
          .map((e) => e.conductorId)
          .where((id) => id != null)
          .toList();

      // 1. Update attendance table with songs/conductors arrays
      await repo.updateAttendance(
        widget.attendanceId,
        {
          'songs': songIds,
          'conductors': conductorIds,
        },
      );

      // 2. Sync history table: delete old entries and create new ones
      await _syncHistoryEntries(attendance.date);

      // 3. Invalidate providers
      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      ref.invalidate(currentSongsProvider);
      ref.invalidate(songHistoryProvider(null));
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Speichern: $e');
      }
    } finally {
      _isSavingSongs = false;
    }
  }

  /// Sync history table entries for this attendance
  Future<void> _syncHistoryEntries(String date) async {
    // TODO(sprint-2b): migrate history-table delete + insert to a new
    // HistoryRepository. Both Supabase calls in this method (delete on
    // history, insert on history) will move there together so they stay
    // testable against tenantId.
    final supabase = ref.read(supabaseClientProvider);
    final tenant = ref.read(currentTenantProvider);
    if (tenant?.id == null) return;

    // Delete existing history entries for this attendance
    await supabase
        .from('history')
        .delete()
        .eq('attendance_id', widget.attendanceId)
        .eq('tenantId', tenant!.id!);

    if (!mounted) return;

    // Create new history entries if there are songs
    if (_songEntries.isNotEmpty) {
      final entries = _songEntries.map((entry) {
        return {
          // Ionic History columns: songId (camelCase), person_id,
          // otherConductor, visible. conductorName is not a column.
          'songId': entry.songId,
          'attendance_id': widget.attendanceId,
          'date': date,
          'tenantId': tenant.id,
          'person_id': entry.otherConductor?.isNotEmpty == true ? null : entry.conductorId,
          'otherConductor': entry.otherConductor,
          'visible': true,
        };
      }).toList();

      await supabase.from('history').insert(entries);
    }
  }

  // ATTENDANCE_SIGNOUT: conductor change, date change, place, files folder,
  // registration fields (Ionic attendance.page.ts parity)

  /// Tap on a song entry: "Dirigent ändern" / "Zum Werk" (Ionic onHistoryEntryClick).
  Future<void> _onSongEntryTap(int index) async {
    if (index < 0 || index >= _songEntries.length) return;
    final entry = _songEntries[index];
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(entry.songName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(entry.displayConductor),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Dirigent ändern'),
              onTap: () => Navigator.pop(ctx, 'conductor'),
            ),
            ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: const Text('Zum Werk'),
              onTap: () => Navigator.pop(ctx, 'song'),
            ),
            ListTile(
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
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
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    if (attendance == null) return;
    final current = DateTime.tryParse(attendance.date)?.toLocal() ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 5),
      lastDate: DateTime(current.year + 5),
      helpText: 'Auf welchen Tag soll der Termin verschoben werden?',
    );
    if (picked == null || !mounted) return;
    if (DateUtils.isSameDay(picked, current)) return;

    final type = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    var reset = false;
    if (type != null && _localStatuses.values.any((s) => s != type.defaultStatus)) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Status zurücksetzen?'),
          content: Text(
            'Nicht alle stehen auf „${type.defaultStatus.label}“. Sollen mit der '
            'Verschiebung alle auf den Standardstatus zurückgesetzt werden?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Behalten')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'reset'), child: const Text('Zurücksetzen')),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      reset = choice == 'reset';
    }

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      final normalized = DateTime(picked.year, picked.month, picked.day, 12);
      final days = DateUtils.dateOnly(normalized).difference(DateUtils.dateOnly(current)).inDays;
      final normalizedIso = normalized.toUtc().toIso8601String();

      // Deadline and checklist due dates move along with the Termin.
      String? shift(String? value) {
        if (value == null || value.isEmpty) return value;
        final d = DateTime.tryParse(value);
        return d == null ? value : d.add(Duration(days: days)).toIso8601String();
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
      if (reset && type != null) {
        await repo.resetPersonAttendancesForAttendance(widget.attendanceId, type.defaultStatus);
        if (mounted) {
          setState(() {
            for (final id in _localStatuses.keys.toList()) {
              _localStatuses[id] = type.defaultStatus;
              _personNotes[id] = null;
            }
          });
        }
      }
      // Hook: absences on the new day and shift re-evaluation belong to the
      // absences / duty-roster packages.

      if (mounted) setState(() => _checklistLoaded = false);
      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          'Termin auf ${DateFormat('EE, dd.MM.yyyy', 'de_DE').format(normalized)} verschoben',
        );
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Datum konnte nicht geändert werden');
    }
  }

  Future<void> _updateAttendanceField(Map<String, dynamic> updates) async {
    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(widget.attendanceId, updates);
      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
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
      final queued = await ref.read(offlineQueueNotifierProvider.notifier).enqueueIfOffline(
          personAttendanceId, {'registration_answers': merged},
          attendanceId: widget.attendanceId);
      if (!queued) {
        final repo = ref.read(attendanceRepositoryWithTenantProvider);
        await repo.updatePersonAttendance(personAttendanceId, {'registration_answers': merged});
      }
      if (mounted) {
        setState(() => _registrationAnswers[personId] = merged);
        ToastHelper.showSuccess(context, 'Anmeldefelder gespeichert');
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, 'Fehler: $e');
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
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _selectStartTime() async {
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

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime == null || !mounted) return;

    final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'start_time': timeStr},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      ToastHelper.showSuccess(context, 'Startzeit aktualisiert');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _selectEndTime() async {
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

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime == null || !mounted) return;

    final timeStr = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return;
      await repo.updateAttendance(
        widget.attendanceId,
        {'end_time': timeStr},
      );

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));
      ToastHelper.showSuccess(context, 'Endzeit aktualisiert');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _exportAttendanceToExcel() async {
    try {
      final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
      final persons = ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull;
      final tenant = ref.read(currentTenantProvider);

      if (attendance == null || persons == null || tenant == null) {
        ToastHelper.showError(context, 'Daten nicht verfügbar');
        return;
      }

      ToastHelper.showInfo(context, 'Erstelle Excel-Export...');

      final exportService = ExportService();
      await exportService.exportAttendanceToExcel(
        context: context,
        attendance: attendance,
        persons: persons,
        statuses: _localStatuses,
        tenantName: tenant.shortName,
      );
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Export: $e');
      }
    }
  }

  // ============== PERSON REMOVE METHOD ==============

  Future<void> _removePersonFromAttendance(int personId) async {
    final personAttendanceId = _personAttendanceIds[personId];
    if (personAttendanceId == null) {
      ToastHelper.showError(context, 'Kein Anwesenheitseintrag gefunden');
      return;
    }

    final isValid = await _validatePersonAttendanceTenant(personAttendanceId);
    if (!isValid) {
      if (mounted) {
        ToastHelper.showError(context, 'Keine Berechtigung');
      }
      return;
    }

    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Person entfernen?',
      message: 'Möchtest du diese Person aus der Anwesenheitsliste entfernen?',
      confirmText: 'Entfernen',
      isDestructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.deletePersonAttendance(personAttendanceId);

      setState(() {
        _localStatuses.remove(personId);
        _personAttendanceIds.remove(personId);
        _personNotes.remove(personId);
        _changedBy.remove(personId);
        _changedAt.remove(personId);
      });

      ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      ref.invalidate(filteredPersonsForAttendanceProvider(widget.attendanceId));

      ToastHelper.showSuccess(context, 'Person entfernt');
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  void _showStatsDialog() {
    final persons = ref.read(filteredPersonsForAttendanceProvider(widget.attendanceId)).valueOrNull ?? [];
    final total = persons.length;

    // Only count statuses for persons in the filtered list (consistent with status bar)
    final personIds = persons.map((p) => p.id).whereType<int>().toSet();
    final statusCounts = <AttendanceStatus, int>{};
    for (final status in AttendanceStatus.values) {
      statusCounts[status] = _localStatuses.entries
          .where((e) => personIds.contains(e.key) && e.value == status)
          .length;
    }

    showStatusOverviewSheet(
      context,
      statusCounts: statusCounts,
      total: total,
    );
  }

  Future<void> _showNotesDialog() async {
    final attendance = ref.read(attendanceDetailProvider(widget.attendanceId)).valueOrNull;
    final currentNotes = attendance?.notes ?? '';

    final result = await DialogHelper.showTextInput(
      context,
      title: 'Notizen',
      initialValue: currentNotes,
      hint: 'Notizen zur Anwesenheit...',
      maxLines: 5,
      confirmText: 'Speichern',
    );

    if (result != null && mounted) {
      try {
        final repo = ref.read(attendanceRepositoryWithTenantProvider);
        if (!repo.hasTenantId) return;
        await repo.updateAttendance(
          widget.attendanceId,
          {'notes': result},
        );

        ref.invalidate(attendanceDetailProvider(widget.attendanceId));
        if (mounted) {
          ToastHelper.showSuccess(context, 'Notizen gespeichert');
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.showError(context, 'Fehler: $e');
        }
      }
    }
  }

  Future<void> _takePhoto() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foto hinzufügen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (source == null) return;

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
      ToastHelper.showInfo(context, 'Lade Foto hoch...');

      final bytes = await image.readAsBytes();
      final fileName = 'attendance_${widget.attendanceId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // TODO(sprint-2c): migrate Storage upload + public URL retrieval to a
      // dedicated storage service. The subsequent attendance update can move
      // to repo.updateAttendance once the URL is returned by that service.
      final supabase = ref.read(supabaseClientProvider);
      final tenant = ref.read(currentTenantProvider);

      if (tenant == null) {
        if (mounted) {
          ToastHelper.showError(context, 'Kein Tenant ausgewählt');
        }
        return;
      }

      final storagePath = '${tenant.id}/attendance/$fileName';

      await supabase.storage
          .from('attendance-images')
          .uploadBinary(storagePath, bytes);

      final publicUrl = supabase.storage
          .from('attendance-images')
          .getPublicUrl(storagePath);

      await supabase
          .from('attendance')
          .update({'img': publicUrl})
          .eq('id', widget.attendanceId)
          .eq('tenantId', tenant.id!);

      ref.invalidate(attendanceDetailProvider(widget.attendanceId));

      if (mounted) {
        ToastHelper.showSuccess(context, 'Foto hochgeladen');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler beim Hochladen: $e');
      }
    }
  }

  /// Save a single person's attendance status immediately
  Future<void> _savePersonStatus(
    int personId,
    AttendanceStatus status, {
    AttendanceStatus? previousStatus,
  }) async {
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
    if (await ref.read(offlineQueueNotifierProvider.notifier).enqueueIfOffline(
        personAttendanceId, {'status': status.value},
        attendanceId: widget.attendanceId)) {
      return;
    }

    final isValid = await _validatePersonAttendanceTenant(personAttendanceId);
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
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.updatePersonAttendance(
        personAttendanceId,
        {'status': status.value},
      );

      // Invalidate list provider so percentage updates when navigating back
      ref.invalidate(realtimeAttendanceListProvider);

      // DUTY: status changes also change the assignment (synced in the repository)
      if (ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull?.dutyMode ?? false) {
        ref.invalidate(personAttendancesForAttendanceProvider(widget.attendanceId));
      }

      // Fire-and-forget: update stored percentage for consistency
      ref.read(attendanceNotifierProvider.notifier)
          .recalculatePercentage(widget.attendanceId);
    } catch (e) {
      if (mounted) {
        if (previousStatus != null) {
          setState(() {
            _localStatuses[personId] = previousStatus;
          });
        }
        ToastHelper.showError(context, 'Fehler beim Speichern: $e');
      }
    } finally {
      _savingPersonIds.remove(personId);
    }
  }
}
