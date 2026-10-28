import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/attendance_type_providers.dart';
import '../../../../core/providers/self_service_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/attendance/attendance.dart';
import '../../../../data/models/person/person.dart';
import '../widgets/plan_viewer_sheet.dart';
import '../widgets/upcoming_songs_sheet.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES
import '../widgets/self_service_absences.dart';

/// Self-Service Overview Page
///
/// Shows the current user's attendance overview across all tenants
/// Allows sign-in/sign-out operations
class SelfServiceOverviewPage extends ConsumerStatefulWidget {
  const SelfServiceOverviewPage({super.key});

  @override
  ConsumerState<SelfServiceOverviewPage> createState() =>
      _SelfServiceOverviewPageState();
}

class _SelfServiceOverviewPageState
    extends ConsumerState<SelfServiceOverviewPage> {
  String _groupingMode = 'chronological'; // or 'byTenant'

  @override
  Widget build(BuildContext context) {
    final attendancesAsync = ref.watch(allPersonAttendancesAcrossTenantsProvider);
    final stats = ref.watch(attendanceStatsProvider);
    final currentAttendance = ref.watch(currentAttendanceProvider);
    final upcoming = ref.watch(upcomingAttendancesAcrossTenantsProvider);
    final past = ref.watch(pastAttendancesAcrossTenantsProvider);
    final isApplicant = ref.watch(isApplicantProvider);
    final playerAsync = ref.watch(currentSelfServicePlayerProvider);

    // Show applicant view if user is an applicant
    if (isApplicant) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Übersicht'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Legende',
              onPressed: () => _showLegend(context),
            ),
          ],
        ),
        body: _ApplicantView(
          playerName: playerAsync.valueOrNull?.firstName,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Übersicht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Legende',
            onPressed: () => _showLegend(context),
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Aktuelle Stücke',
            onPressed: () => showUpcomingSongsSheet(context),
          ),
          const NotificationBell(), // MESSAGES
        ],
      ),
      body: attendancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text('Fehler: $error'),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(allPersonAttendancesAcrossTenantsProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (attendances) {
          if (attendances.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 64, color: AppColors.medium),
                  SizedBox(height: AppDimensions.paddingM),
                  Text('Keine Termine gefunden'),
                  SizedBox(height: AppDimensions.paddingS),
                  Text(
                    'Du bist keiner Gruppe zugeordnet\noder es sind keine Termine geplant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.medium),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allPersonAttendancesAcrossTenantsProvider);
              ref.invalidate(currentSelfServicePlayerProvider);
            },
            child: CustomScrollView(
              slivers: [
                // Stats Header with greeting
                SliverToBoxAdapter(
                  child: _StatsHeader(
                    stats: stats,
                    player: playerAsync.valueOrNull,
                    onShowSongs: () => showUpcomingSongsSheet(context),
                  ),
                ),

                // PEOPLE_IMPORT: planned absences + self pause
                const SliverToBoxAdapter(child: SelfServiceAbsenceSection()),

                // Current Attendance Card
                if (currentAttendance != null)
                  SliverToBoxAdapter(
                    child: _CurrentAttendanceCard(
                      attendance: currentAttendance,
                      onSignIn: () => _signIn(currentAttendance),
                      onSignOut: () => _showSignOutDialog(currentAttendance),
                      onShowPlan: currentAttendance.hasPlan
                          ? () => _showPlanViewer(currentAttendance)
                          : null,
                    ),
                  ),

                // Grouping mode toggle
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: AppDimensions.paddingS),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'chronological', label: Text('Chronologisch')),
                        ButtonSegment(value: 'byTenant', label: Text('Nach Gruppe')),
                      ],
                      selected: {_groupingMode},
                      onSelectionChanged: (value) {
                        setState(() => _groupingMode = value.first);
                      },
                    ),
                  ),
                ),

                // Upcoming/Past Lists
                if (_groupingMode == 'chronological') ...[
                  // Skip the first upcoming (already shown as current)
                  if (upcoming.length > 1) ...[
                    const SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Kommende Termine'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _AttendanceListTile(
                          attendance: upcoming[index + 1],
                          onTap: () => _showActionSheet(upcoming[index + 1]),
                        ),
                        childCount: upcoming.length - 1,
                      ),
                    ),
                  ],
                  if (past.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: _SectionHeader(title: 'Vergangene Termine'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _AttendanceListTile(
                          attendance: past[index],
                          onTap: () => _showActionSheet(past[index]),
                        ),
                        childCount: past.length,
                      ),
                    ),
                  ],
                ] else ...[
                  // Group by tenant
                  ..._buildTenantGroupedLists(attendances),
                ],

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.paddingXL),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTenantGroupedLists(
      List<CrossTenantPersonAttendance> attendances) {
    // Group by tenant
    final Map<int, List<CrossTenantPersonAttendance>> grouped = {};

    for (final att in attendances) {
      grouped.putIfAbsent(att.tenantId, () => []).add(att);
    }

    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      final tenantAttendances = entry.value;
      if (tenantAttendances.isEmpty) continue;

      final tenantName = tenantAttendances.first.tenantName;
      final tenantColor = tenantAttendances.first.tenantColor;

      widgets.add(SliverToBoxAdapter(
        child: _SectionHeader(
          title: tenantName,
          color: ColorUtils.parseNamedColor(tenantColor),
        ),
      ));

      widgets.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _AttendanceListTile(
            attendance: tenantAttendances[index],
            onTap: () => _showActionSheet(tenantAttendances[index]),
            showTenant: false,
          ),
          childCount: tenantAttendances.length,
        ),
      ));
    }

    return widgets;
  }

  Future<void> _signIn(CrossTenantPersonAttendance attendance) async {
    if (attendance.id == null) {
      ToastHelper.showError(context, 'Fehler: Keine gültige Anwesenheits-ID');
      return;
    }

    await ref.read(signInOutNotifierProvider.notifier).signIn(
          attendance.id!,
          SignInType.normal,
        );

    final state = ref.read(signInOutNotifierProvider);
    if (mounted) {
      if (state.hasError) {
        ToastHelper.showError(context, 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.');
      } else {
        final typeName = attendance.typeInfo ?? 'Termin';
        ToastHelper.showSuccess(context, 'Angemeldet bei $typeName');
      }
    }
  }

  Future<void> _showSignOutDialog(CrossTenantPersonAttendance attendance,
      {bool isLateComing = false}) async {
    if (attendance.id == null) {
      ToastHelper.showError(context, 'Fehler: Keine gültige Anwesenheits-ID');
      return;
    }

    final reasons = kSignOutReasons;

    String? selectedReason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                isLateComing ? 'Verspätung eintragen' : 'Abmelden',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(isLateComing
                  ? 'Bitte gib einen Grund für die Verspätung an'
                  : 'Bitte wähle einen Grund'),
            ),
            const Divider(),
            ...reasons.map((reason) => ListTile(
                  leading: const Icon(Icons.arrow_forward_ios, size: 16),
                  title: Text(reason),
                  onTap: () => Navigator.of(context).pop(reason),
                )),
            ListTile(
              leading: const Icon(Icons.edit, size: 16),
              title: const Text('Eigener Grund...'),
              onTap: () => _showCustomReasonDialog(context),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );

    if (selectedReason != null && mounted) {
      await ref.read(signInOutNotifierProvider.notifier).signOut(
            [attendance.id!],
            selectedReason,
            isLateComing: isLateComing,
          );

      final state = ref.read(signInOutNotifierProvider);
      if (mounted) {
        if (state.hasError) {
          ToastHelper.showError(context, 'Abmeldung fehlgeschlagen. Bitte versuche es erneut.');
        } else {
          final typeName = attendance.typeInfo ?? 'Termin';
          ToastHelper.showSuccess(
              context,
              isLateComing
                  ? 'Verspätung für $typeName eingetragen'
                  : 'Abgemeldet bei $typeName');
        }
      }
    }
  }

  Future<void> _showCustomReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Abmeldegrund'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Bitte gib einen Grund an (mind. 5 Zeichen)',
              ),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().length < 5) {
                  return 'Bitte mindestens 5 Zeichen eingeben';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Bestätigen'),
            ),
          ],
        ),
      );

      if (reason != null && reason.isNotEmpty && mounted) {
        if (context.mounted) {
          Navigator.of(context).pop(reason);
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showActionSheet(CrossTenantPersonAttendance attendance) async {
    if (attendance.id == null) {
      ToastHelper.showError(context, 'Dieser Termin kann nicht bearbeitet werden');
      return;
    }

    final isUpcoming = attendance.isUpcoming;
    final isPast = attendance.isPast;
    final isDeadlinePassed = attendance.isDeadlinePassed;
    final isSignedIn = attendance.status == AttendanceStatus.present ||
        attendance.status == AttendanceStatus.late;
    final isExcused = attendance.status == AttendanceStatus.excused ||
        attendance.status == AttendanceStatus.lateExcused;

    // Get attendance type to check available_statuses
    AttendanceType? attType;
    if (attendance.typeId != null) {
      attType = await ref.read(attendanceTypeByIdProvider(attendance.typeId!).future);
    }

    // Check which statuses are available
    final canExcuse = attType?.availableStatuses?.contains(AttendanceStatus.excused) ?? true;
    final canLate = attType?.availableStatuses?.contains(AttendanceStatus.late) ?? true;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                attendance.displayTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateHelper.getReadableDate(attendance.date ?? '')),
                  if (attendance.deadlineText != null && attendance.status.isNeutral)
                    Text(
                      attendance.deadlineText!,
                      style: TextStyle(
                        fontSize: 12,
                        color: attendance.isDeadlinePassed
                            ? AppColors.danger
                            : AppColors.medium,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            if (isUpcoming && !isDeadlinePassed && !isSignedIn && !isExcused) ...[
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.success),
                title: const Text('Anmelden'),
                onTap: () {
                  Navigator.pop(context);
                  _signIn(attendance);
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add, color: AppColors.success),
                title: const Text('Anmelden mit Notiz'),
                onTap: () {
                  Navigator.pop(context);
                  _signInWithNote(attendance);
                },
              ),
              if (canExcuse)
                ListTile(
                  leading: const Icon(Icons.cancel, color: AppColors.danger),
                  title: const Text('Abmelden'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSignOutDialog(attendance);
                  },
                ),
              if (canLate)
                ListTile(
                  leading: const Icon(Icons.schedule, color: AppColors.warning),
                  title: const Text('Verspätung eintragen'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSignOutDialog(attendance, isLateComing: true);
                  },
                ),
            ],
            if (isUpcoming && !isDeadlinePassed && isSignedIn) ...[
              ListTile(
                leading: const Icon(Icons.edit_note, color: AppColors.primary),
                title: const Text('Notiz anpassen'),
                onTap: () {
                  Navigator.pop(context);
                  _showNoteDialog(attendance);
                },
              ),
            ],
            if (isPast || isDeadlinePassed) ...[
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.medium),
                title: Text(
                  isPast
                      ? 'Dieser Termin liegt in der Vergangenheit'
                      : 'Die Abmeldefrist ist abgelaufen',
                  style: const TextStyle(color: AppColors.medium),
                ),
              ),
            ],
            if (!isSignedIn)
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('Notiz hinzufügen'),
                onTap: () {
                  Navigator.pop(context);
                  _showNoteDialog(attendance);
                },
              ),
            if (attendance.hasPlan)
              ListTile(
                leading: const Icon(Icons.list_alt, color: AppColors.primary),
                title: const Text('Ablaufplan anzeigen'),
                onTap: () {
                  Navigator.pop(context);
                  _showPlanViewer(attendance);
                },
              ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithNote(CrossTenantPersonAttendance attendance) async {
    if (attendance.id == null) {
      ToastHelper.showError(context, 'Fehler: Keine gültige Anwesenheits-ID');
      return;
    }

    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notiz für Anmeldung'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Gib hier deine Notiz ein',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );

    if (note != null && mounted) {
      await ref.read(signInOutNotifierProvider.notifier).signIn(
            attendance.id!,
            SignInType.normal,
            notes: note,
          );

      final state = ref.read(signInOutNotifierProvider);
      if (mounted) {
        if (state.hasError) {
          ToastHelper.showError(context, 'Anmeldung fehlgeschlagen. Bitte versuche es erneut.');
        } else {
          final typeName = attendance.typeInfo ?? 'Termin';
          ToastHelper.showSuccess(context, 'Angemeldet bei $typeName mit Notiz');
        }
      }
    }
  }

  Future<void> _showPlanViewer(CrossTenantPersonAttendance attendance) async {
    if (!attendance.hasPlan) {
      ToastHelper.showWarning(context, 'Kein Ablaufplan verfügbar');
      return;
    }

    await showPlanViewerSheet(
      context,
      attendance: attendance,
    );
  }

  Future<void> _showNoteDialog(CrossTenantPersonAttendance attendance) async {
    if (attendance.id == null) {
      ToastHelper.showError(context, 'Fehler: Keine gültige Anwesenheits-ID');
      return;
    }

    final controller = TextEditingController(text: attendance.notes);

    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notiz'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Notiz eingeben',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (note != null && mounted) {
      await ref
          .read(signInOutNotifierProvider.notifier)
          .updateNote(attendance.id!, note);

      final state = ref.read(signInOutNotifierProvider);
      if (mounted) {
        if (state.hasError) {
          ToastHelper.showError(context, 'Notiz konnte nicht gespeichert werden.');
        } else {
          ToastHelper.showSuccess(context, 'Notiz gespeichert');
        }
      }
    }
  }

  void _showLegend(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Legende',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const Divider(),
            _LegendItem(
              symbol: '✓',
              color: AttendanceStatus.present.color,
              label: 'Anwesend',
            ),
            _LegendItem(
              symbol: 'E',
              color: AttendanceStatus.excused.color,
              label: 'Entschuldigt',
            ),
            _LegendItem(
              symbol: 'A',
              color: AttendanceStatus.absent.color,
              label: 'Abwesend',
            ),
            _LegendItem(
              symbol: 'L',
              color: AttendanceStatus.late.color,
              label: 'Verspätet anwesend',
            ),
            _LegendItem(
              symbol: 'LE',
              color: AttendanceStatus.lateExcused.color,
              label: 'Verspätet entschuldigt',
            ),
            _LegendItem(
              symbol: 'N',
              color: AttendanceStatus.neutral.color,
              label: 'Neutral',
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );
  }
}

/// Stats header showing attendance percentage and late count
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats, this.player, this.onShowSongs});

  final AttendanceStats stats;
  final Person? player;
  final VoidCallback? onShowSongs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Personal greeting
          if (player != null) ...[
            Text(
              player!.paused
                  ? 'Shalom ${player!.firstName}! Du pausierst gerade.'
                  : 'Shalom ${player!.firstName}!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: player!.paused ? AppColors.warning : null,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          // Stats circles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCircle(
                value: '${stats.percentage}%',
                label: 'Anwesenheit',
                color: _getPercentageColor(stats.percentage),
              ),
              _StatCircle(
                value: '${stats.lateCount}',
                label: 'Verspätungen',
                color: stats.lateCount > 3 ? AppColors.warning : AppColors.medium,
              ),
            ],
          ),
          if (onShowSongs != null) ...[
            const SizedBox(height: AppDimensions.paddingM),
            ActionChip(
              avatar: const Icon(Icons.library_music, size: 18),
              label: const Text('Aktuelle Stücke'),
              onPressed: onShowSongs,
            ),
          ],
        ],
      ),
    );
  }

  Color _getPercentageColor(int percentage) {
    if (percentage >= 80) return AppColors.success;
    if (percentage >= 60) return AppColors.warning;
    return AppColors.danger;
  }
}

/// Circular stat display
class _StatCircle extends StatelessWidget {
  const _StatCircle({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.paddingS),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.medium),
        ),
      ],
    );
  }
}

/// Current attendance card with sign in/out buttons
class _CurrentAttendanceCard extends StatelessWidget {
  const _CurrentAttendanceCard({
    required this.attendance,
    required this.onSignIn,
    required this.onSignOut,
    this.onShowPlan,
  });

  final CrossTenantPersonAttendance attendance;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback? onShowPlan;

  @override
  Widget build(BuildContext context) {
    final isPresent = attendance.status == AttendanceStatus.present ||
        attendance.status == AttendanceStatus.late;
    final isExcused = attendance.status == AttendanceStatus.excused ||
        attendance.status == AttendanceStatus.lateExcused;

    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingM),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _parseColor(attendance.tenantColor),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Text(
                  'Nächster Termin',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.medium,
                  ),
                ),
                const Spacer(),
                if (attendance.hasPlan)
                  IconButton(
                    icon: const Icon(Icons.list_alt, color: AppColors.primary),
                    tooltip: 'Ablaufplan anzeigen',
                    onPressed: onShowPlan,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              DateHelper.getReadableDate(attendance.date ?? ''),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (attendance.typeInfo != null) ...[
              const SizedBox(height: 4),
              Text(
                attendance.typeInfo!,
                style: TextStyle(color: AppColors.medium),
              ),
            ],
            Text(
              attendance.tenantName,
              style: TextStyle(color: AppColors.medium, fontSize: 12),
            ),
            if (attendance.startTime != null) ...[
              const SizedBox(height: 4),
              Text(
                '${attendance.startTime}${attendance.endTime != null ? ' - ${attendance.endTime}' : ''}',
                style: TextStyle(color: AppColors.medium, fontSize: 12),
              ),
            ],
            if (attendance.deadlineText != null && attendance.status.isNeutral) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    attendance.isDeadlinePassed
                        ? Icons.warning_amber
                        : Icons.schedule,
                    size: 14,
                    color: attendance.isDeadlinePassed
                        ? AppColors.danger
                        : AppColors.medium,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    attendance.deadlineText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: attendance.isDeadlinePassed
                          ? AppColors.danger
                          : AppColors.medium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.paddingM),
            if (isPresent)
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 20),
                    SizedBox(width: AppDimensions.paddingS),
                    Text(
                      'Du bist angemeldet',
                      style: TextStyle(color: AppColors.success),
                    ),
                  ],
                ),
              )
            else if (isExcused)
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, color: AppColors.info, size: 20),
                    SizedBox(width: AppDimensions.paddingS),
                    Text(
                      'Du bist entschuldigt',
                      style: TextStyle(color: AppColors.info),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSignIn,
                      icon: const Icon(Icons.check),
                      label: const Text('Anmelden'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.close),
                      label: const Text('Abmelden'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      debugPrint('Warning: Failed to parse color "$hexColor", using primary color');
      return AppColors.primary;
    }
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.color,
  });

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingS,
      ),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: AppDimensions.paddingS),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Attendance list tile
class _AttendanceListTile extends StatelessWidget {
  const _AttendanceListTile({
    required this.attendance,
    required this.onTap,
    this.showTenant = true,
  });

  final CrossTenantPersonAttendance attendance;
  final VoidCallback onTap;
  final bool showTenant;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _parseColor(attendance.tenantColor),
        child: Text(
          attendance.tenantName.isNotEmpty
              ? attendance.tenantName.substring(0, 1).toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(DateHelper.getReadableDate(attendance.date ?? '')),
          ),
          if (attendance.hasPlan)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.list_alt,
                size: 16,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attendance.typeInfo != null)
            Text(
              attendance.typeInfo!,
              style: const TextStyle(fontSize: 12),
            ),
          if (showTenant)
            Text(
              attendance.tenantName,
              style: TextStyle(fontSize: 12, color: AppColors.medium),
            ),
          if (attendance.deadlineText != null && attendance.isUpcoming && attendance.status.isNeutral)
            Text(
              attendance.deadlineText!,
              style: TextStyle(
                fontSize: 11,
                color: attendance.isDeadlinePassed
                    ? AppColors.danger
                    : AppColors.medium,
              ),
            ),
        ],
      ),
      trailing: _StatusBadge(status: attendance.status),
      onTap: onTap,
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      debugPrint('Warning: Failed to parse color "$hexColor", using primary color');
      return AppColors.primary;
    }
  }
}

/// Status badge
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getIcon(), size: 14, color: _getColor()),
          const SizedBox(width: 4),
          Text(
            _getText(),
            style: TextStyle(
              color: _getColor(),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() => status.color;

  IconData _getIcon() {
    return switch (status) {
      AttendanceStatus.present => Icons.check,
      AttendanceStatus.absent => Icons.close,
      AttendanceStatus.excused => Icons.event_busy,
      AttendanceStatus.late => Icons.schedule,
      AttendanceStatus.lateExcused => Icons.schedule,
      AttendanceStatus.neutral => Icons.remove,
    };
  }

  String _getText() {
    return switch (status) {
      AttendanceStatus.present => 'DA',
      AttendanceStatus.absent => 'AB',
      AttendanceStatus.excused => 'EN',
      AttendanceStatus.late => 'SP',
      AttendanceStatus.lateExcused => 'SE',
      AttendanceStatus.neutral => '?',
    };
  }
}

/// Legend item widget for the legend sheet
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.symbol,
    required this.color,
    required this.label,
  });

  final String symbol;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
      title: Text(label),
    );
  }
}

/// Applicant view shown when user has APPLICANT role
class _ApplicantView extends StatelessWidget {
  const _ApplicantView({this.playerName});

  final String? playerName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_empty,
                  size: 64,
                  color: AppColors.warning,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                if (playerName != null) ...[
                  Text(
                    'Shalom $playerName!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                ],
                const Text(
                  'Deine Registrierung wurde erfolgreich übermittelt.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                const Text(
                  'Du wirst benachrichtigt, sobald diese bearbeitet wurde.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.medium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
