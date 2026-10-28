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
import '../../../../core/providers/attendance_providers.dart';
import '../../../../core/providers/conductor_providers.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/realtime_providers.dart';
import '../../../../core/providers/song_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/services/offline_queue_service.dart'; // PROFILE_OFFLINE
import '../../../../core/services/telegram_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/models/song/song.dart';
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
                _personNotes[pa.personId!] = pa.notes;
                _changedBy[pa.personId!] = pa.changedBy;
                _changedAt[pa.personId!] = pa.changedAt;
                // Status nur setzen wenn nicht gerade lokal geändert
                if (!_savingPersonIds.contains(pa.personId!)) {
                  _localStatuses[pa.personId!] = pa.status;
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
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Anwesenheit')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text('Fehler: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(attendanceDetailProvider(widget.attendanceId)),
                child: const Text('Erneut versuchen'),
              ),
            ],
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
                itemBuilder: (context) => [
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
            error: (error, stack) => Center(child: Text('Fehler: $error')),
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
              final hasChecklist = _localChecklist.isNotEmpty || (attendanceType?.checklist?.isNotEmpty ?? false);
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
                          ),

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

                        const SizedBox(height: AppDimensions.paddingS),
                      ],
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: AttendanceGrid(
                      persons: persons,
                      localStatuses: _localStatuses,
                      personNotes: _personNotes,
                      availableStatuses: availableStatuses,
                      clickMode: _clickMode,
                      onStatusChanged: (personId, status) {
                        final previousStatus = _localStatuses[personId];
                        setState(() {
                          _localStatuses[personId] = status;
                        });
                        _savePersonStatus(personId, status, previousStatus: previousStatus);
                      },
                      onNoteChanged: _updatePersonNote,
                      onShowModifierInfo: _showModifierInfo,
                      onRemoveFromAttendance: _removePersonFromAttendance,
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: AttendanceStatusBar(
            persons: personsAsync.valueOrNull ?? [],
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

    final isValid = await _validatePersonAttendanceTenant(personAttendanceId);
    if (!isValid) {
      if (mounted) {
        ToastHelper.showError(context, 'Keine Berechtigung');
      }
      return;
    }

    try {
      final repo = ref.read(attendanceRepositoryWithTenantProvider);
      await repo.updatePersonAttendance(personAttendanceId, {'notes': notes});

      setState(() {
        _personNotes[personId] = notes;
      });

      if (mounted) {
        ToastHelper.showSuccess(context, notes?.isNotEmpty == true ? 'Notiz gespeichert' : 'Notiz gelöscht');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Fehler: $e');
      }
    }
  }

  /// Show modifier info (who changed, when)
  Future<void> _showModifierInfo(int personId) async {
    final changedBy = _changedBy[personId];
    final changedAt = _changedAt[personId];

    String message;
    if (changedBy == null) {
      message = 'Der Status wurde bisher nicht verändert.';
    } else {
      final persons = ref.read(allPersonsForAttendanceProvider).valueOrNull ?? [];
      final modifier = persons.firstWhere(
        (p) => p.appId == changedBy,
        orElse: () => Person(firstName: 'Unbekannt', lastName: ''),
      );

      final modifierName = modifier.fullName.isNotEmpty ? modifier.fullName : 'Unbekannt';
      message = 'Zuletzt geändert von $modifierName';

      if (changedAt != null) {
        final date = DateTime.tryParse(changedAt);
        if (date != null) {
          message += '\nam ${DateFormat('dd.MM.yyyy').format(date)} um ${DateFormat('HH:mm').format(date)} Uhr';
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Info'),
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
    }
  }

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

  Future<void> _addChecklistItem() async {
    final result = await DialogHelper.showTextInput(
      context,
      title: 'To-Do hinzufügen',
      hint: 'Beschreibung eingeben...',
      confirmText: 'Hinzufügen',
    );

    if (result != null && result.trim().isNotEmpty && mounted) {
      final newItem = ChecklistItem(
        id: const Uuid().v4(),
        text: result.trim(),
        completed: false,
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

  Future<void> _restoreChecklist() async {
    final attendanceType = ref.read(attendanceTypeForAttendanceProvider(widget.attendanceId)).valueOrNull;
    if (attendanceType?.checklist == null || attendanceType!.checklist!.isEmpty) {
      ToastHelper.showInfo(context, 'Keine Standard-Checkliste für diesen Typ verfügbar');
      return;
    }

    final confirmed = await DialogHelper.showConfirmation(
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
          if (attendance != null) {
            final attendanceDate = DateTime.tryParse(attendance.date);
            if (attendanceDate != null) {
              final deadline = attendanceDate.subtract(Duration(hours: item.deadlineHours!));
              dueDate = deadline.toIso8601String();
            }
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
          'song_id': entry.songId,
          'attendance_id': widget.attendanceId,
          'date': date,
          'tenantId': tenant.id,
          'conductorName': entry.conductorName,
          'otherConductor': entry.otherConductor,
        };
      }).toList();

      await supabase.from('history').insert(entries);
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
