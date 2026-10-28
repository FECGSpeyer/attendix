import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/person/person.dart';
import '../../../../data/repositories/sign_in_out_repository.dart';
import '../../../self_service/presentation/widgets/plan_viewer_sheet.dart';
import '../../data/providers/parents_providers.dart';
import '../../../messages/presentation/widgets/notification_bell.dart'; // MESSAGES

/// Parents Portal Page
///
/// Allows parents to view and manage their children's attendance
class ParentsPortalPage extends ConsumerStatefulWidget {
  const ParentsPortalPage({super.key});

  @override
  ConsumerState<ParentsPortalPage> createState() => _ParentsPortalPageState();
}

class _ParentsPortalPageState extends ConsumerState<ParentsPortalPage> {
  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(parentChildrenProvider);
    final attendancesAsync = ref.watch(childrenAttendancesProvider);
    final currentAttendance = ref.watch(currentParentAttendanceProvider);
    final upcoming = ref.watch(upcomingParentAttendancesProvider);
    final past = ref.watch(pastParentAttendancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Legende',
            onPressed: () => _showLegend(context),
          ),
          const NotificationBell(), // MESSAGES
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: AppDimensions.paddingM),
              Text('Fehler: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(parentChildrenProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 64, color: AppColors.medium),
                  SizedBox(height: AppDimensions.paddingM),
                  Text('Keine Kinder gefunden'),
                  SizedBox(height: AppDimensions.paddingS),
                  Text(
                    'Es wurden keine Kinder mit Ihrem\nEltern-Account verknüpft.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.medium),
                  ),
                ],
              ),
            );
          }

          return attendancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: AppColors.danger),
                  const SizedBox(height: AppDimensions.paddingM),
                  Text('Fehler: $error'),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(childrenAttendancesProvider),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
            data: (attendances) {
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(parentChildrenProvider);
                  ref.invalidate(childrenAttendancesProvider);
                  await ref.read(childrenAttendancesProvider.future);
                },
                child: CustomScrollView(
                  slivers: [
                    // Children Overview Card
                    SliverToBoxAdapter(
                      child: _ChildrenOverviewCard(children: children),
                    ),

                    // Current Attendance
                    if (currentAttendance != null) ...[
                      const SliverToBoxAdapter(
                        child: _SectionHeader(title: 'Aktueller Termin'),
                      ),
                      SliverToBoxAdapter(
                        child: _AttendanceGroupCard(
                          group: currentAttendance,
                          onTap: () =>
                              _showAttendanceActions(currentAttendance),
                          isHighlighted: true,
                        ),
                      ),
                    ],

                    // Upcoming Attendances
                    if (upcoming.length > 1) ...[
                      const SliverToBoxAdapter(
                        child: _SectionHeader(title: 'Anstehende Termine'),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _AttendanceGroupCard(
                            group: upcoming[index + 1],
                            onTap: () =>
                                _showAttendanceActions(upcoming[index + 1]),
                          ),
                          childCount: upcoming.length - 1,
                        ),
                      ),
                    ],

                    // Past Attendances
                    if (past.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: _SectionHeader(title: 'Vergangene Termine'),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _AttendanceGroupCard(
                            group: past[index],
                            onTap: null,
                            isPast: true,
                          ),
                          childCount: past.length,
                        ),
                      ),
                    ],

                    // Empty state
                    if (attendances.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingL),
                          child: Center(
                            child: Text(
                              'Keine Termine gefunden',
                              style: TextStyle(color: AppColors.medium),
                            ),
                          ),
                        ),
                      ),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppDimensions.paddingXL),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
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
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            _legendItem(Icons.check, AttendanceStatus.present.color, 'Anwesend'),
            _legendItem(Icons.event_busy, AttendanceStatus.excused.color, 'Entschuldigt'),
            _legendItem(Icons.close, AttendanceStatus.absent.color, 'Abwesend'),
            _legendItem(Icons.schedule, AttendanceStatus.late.color, 'Verspätet'),
            _legendItem(Icons.remove, AttendanceStatus.neutral.color, 'Neutral'),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label),
      dense: true,
    );
  }

  Future<void> _showAttendanceActions(ParentAttendanceGroup group) async {
    final childAttendances = group.childAttendances;
    if (childAttendances.isEmpty) return;

    final hasMultipleChildren = childAttendances.length > 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              ListTile(
                title: Text(
                  group.displayTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateHelper.getReadableDate(group.date ?? '')),
                    if (group.deadlineText != null && !group.allChildrenResponded)
                      Text(
                        group.deadlineText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: group.isDeadlinePassed
                              ? AppColors.danger
                              : AppColors.medium,
                        ),
                      ),
                  ],
                ),
                trailing: group.hasPlan
                    ? IconButton(
                        icon: const Icon(Icons.list_alt,
                            color: AppColors.primary),
                        tooltip: 'Ablaufplan',
                        onPressed: () {
                          Navigator.pop(context);
                          _showPlanViewer(group);
                        },
                      )
                    : null,
              ),
              // Bulk action for multiple children
              if (hasMultipleChildren && !group.isDeadlinePassed) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.group, color: AppColors.primary),
                  title: const Text(
                    'Alle Kinder An- bzw. Abmelden',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showBulkActions(group);
                  },
                ),
              ],
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: childAttendances.length,
                  itemBuilder: (context, index) {
                    final childAtt = childAttendances[index];
                    return _ChildAttendanceActionTile(
                      childAttendance: childAtt,
                      isDeadlinePassed: group.isDeadlinePassed,
                      onSignIn: () {
                        Navigator.pop(context);
                        _signIn(childAtt);
                      },
                      onSignOut: () {
                        Navigator.pop(context);
                        _showSignOutDialog(childAtt);
                      },
                      onLateComing: () {
                        Navigator.pop(context);
                        _showSignOutDialog(childAtt, isLateComing: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBulkActions(ParentAttendanceGroup group) async {
    final actionableChildren = group.childAttendances
        .where((c) =>
            c.id != null &&
            c.status != AttendanceStatus.present &&
            c.status != AttendanceStatus.excused &&
            c.status != AttendanceStatus.late &&
            c.status != AttendanceStatus.lateExcused)
        .toList();

    final allIds = group.childAttendances
        .where((c) => c.id != null)
        .map((c) => c.id!)
        .toList();

    if (allIds.isEmpty) {
      ToastHelper.showWarning(context, 'Keine gültigen Einträge gefunden');
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Alle ${group.childAttendances.length} Kinder',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(group.displayTitle),
            ),
            const Divider(),
            if (actionableChildren.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.check, color: AppColors.success),
                title: Text('Alle anmelden (${actionableChildren.length})'),
                onTap: () => Navigator.pop(context, 'signIn'),
              ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.danger),
              title: const Text('Alle abmelden'),
              onTap: () => Navigator.pop(context, 'signOut'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: AppColors.warning),
              title: const Text('Alle verspätet'),
              onTap: () => Navigator.pop(context, 'lateComing'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Abbrechen'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'signIn':
        for (final child in actionableChildren) {
          await ref.read(parentSignInOutNotifierProvider.notifier).signIn(
                child.id!,
                SignInType.normal,
              );
        }
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            '${actionableChildren.length} Kinder angemeldet',
          );
        }
      case 'signOut':
        _showBulkSignOutDialog(allIds, group.displayTitle);
      case 'lateComing':
        _showBulkSignOutDialog(allIds, group.displayTitle, isLateComing: true);
    }
  }

  Future<void> _showBulkSignOutDialog(
    List<String> ids,
    String title, {
    bool isLateComing = false,
  }) async {
    final reasons = kSignOutReasons;

    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                isLateComing
                    ? 'Verspätung für alle Kinder'
                    : 'Alle Kinder abmelden',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(isLateComing
                  ? 'Bitte gib einen Grund für die Verspätung an'
                  : 'Bitte wähle einen Grund'),
            ),
            const Divider(),
            ...reasons.map((r) => ListTile(
                  leading: const Icon(Icons.arrow_forward_ios, size: 16),
                  title: Text(r),
                  onTap: () {
                    if (r == 'Sonstiger Grund') {
                      Navigator.pop(context);
                      _showBulkCustomReasonDialog(ids, isLateComing: isLateComing);
                    } else {
                      Navigator.pop(context, r);
                    }
                  },
                )),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );

    if (reason != null && mounted) {
      await ref.read(parentSignInOutNotifierProvider.notifier).signOut(
            ids,
            reason,
            isLateComing: isLateComing,
          );
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          isLateComing
              ? 'Verspätung für alle Kinder eingetragen'
              : 'Alle Kinder abgemeldet',
        );
      }
    }
  }

  Future<void> _showBulkCustomReasonDialog(
    List<String> ids, {
    bool isLateComing = false,
  }) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isLateComing ? 'Grund für Verspätung' : 'Abmeldegrund'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Mindestens 5 Zeichen eingeben',
            ),
            autofocus: true,
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.length >= 5) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: const Text('Bestätigen'),
            ),
          ],
        ),
      );

      if (reason != null && reason.length >= 5 && mounted) {
        await ref.read(parentSignInOutNotifierProvider.notifier).signOut(
              ids,
              reason,
              isLateComing: isLateComing,
            );
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            isLateComing
                ? 'Verspätung für alle Kinder eingetragen'
                : 'Alle Kinder abgemeldet',
          );
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showPlanViewer(ParentAttendanceGroup group) async {
    if (!group.hasPlan) {
      ToastHelper.showWarning(context, 'Kein Ablaufplan verfügbar');
      return;
    }

    // BL-001: Safe access to first child attendance
    final first = group.childAttendances.firstOrNull;
    if (first == null) {
      ToastHelper.showError(context, 'Keine Kinder-Anwesenheit gefunden');
      return;
    }

    // Convert to CrossTenantPersonAttendance for plan viewer
    final crossTenant = CrossTenantPersonAttendance(
      id: first.id,
      date: group.date,
      typeInfo: group.typeInfo,
      startTime: group.startTime,
      endTime: group.endTime,
      plan: group.plan,
      sharePlan: group.sharePlan,
      tenantId: 0,
      tenantName: '',
      tenantColor: '#000000',
    );

    await showPlanViewerSheet(context, attendance: crossTenant);
  }

  Future<void> _signIn(ChildPersonAttendance childAttendance) async {
    if (childAttendance.id == null) {
      ToastHelper.showError(context, 'Fehler: Keine gültige Anwesenheits-ID');
      return;
    }

    await ref.read(parentSignInOutNotifierProvider.notifier).signIn(
          childAttendance.id!,
          SignInType.normal,
        );

    if (mounted) {
      ToastHelper.showSuccess(
          context, '${childAttendance.childName} wurde angemeldet');
    }
  }

  Future<void> _showSignOutDialog(
    ChildPersonAttendance childAttendance, {
    bool isLateComing = false,
  }) async {
    if (childAttendance.id == null) {
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
                isLateComing
                    ? 'Verspätung für ${childAttendance.childName}'
                    : 'Abmelden: ${childAttendance.childName}',
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
                  onTap: () {
                    if (reason == 'Sonstiger Grund') {
                      Navigator.pop(context);
                      _showCustomReasonDialog(childAttendance,
                          isLateComing: isLateComing);
                    } else {
                      Navigator.of(context).pop(reason);
                    }
                  },
                )),
            const SizedBox(height: AppDimensions.paddingM),
          ],
        ),
      ),
    );

    if (selectedReason != null && mounted) {
      await ref.read(parentSignInOutNotifierProvider.notifier).signOut(
            [childAttendance.id!],
            selectedReason,
            isLateComing: isLateComing,
          );

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          isLateComing
              ? 'Verspätung für ${childAttendance.childName} eingetragen'
              : '${childAttendance.childName} wurde abgemeldet',
        );
      }
    }
  }

  Future<void> _showCustomReasonDialog(
    ChildPersonAttendance childAttendance, {
    bool isLateComing = false,
  }) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isLateComing ? 'Grund für Verspätung' : 'Abmeldegrund'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Mindestens 5 Zeichen eingeben',
          ),
          autofocus: true,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length >= 5) {
                Navigator.of(context).pop(controller.text);
              }
            },
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );

    if (reason != null && reason.length >= 5 && mounted) {
      await ref.read(parentSignInOutNotifierProvider.notifier).signOut(
            [childAttendance.id!],
            reason,
            isLateComing: isLateComing,
          );

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          isLateComing
              ? 'Verspätung für ${childAttendance.childName} eingetragen'
              : '${childAttendance.childName} wurde abgemeldet',
        );
      }
    }
  }
}

/// Card showing all children with their attendance percentage
class _ChildrenOverviewCard extends ConsumerWidget {
  const _ChildrenOverviewCard({required this.children});

  final List<Person> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: AppColors.primary),
                const SizedBox(width: AppDimensions.paddingS),
                const Text(
                  'Meine Kinder',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Wrap(
              spacing: AppDimensions.paddingS,
              runSpacing: AppDimensions.paddingS,
              children: children.map((child) {
                final stats = ref.watch(childStatsProvider(child.id ?? 0));
                return _ChildChip(
                  name: '${child.firstName} ${child.lastName}',
                  percentage: stats.percentage,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip showing child name and attendance percentage
class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.percentage,
  });

  final String name;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 75
        ? AppColors.success
        : percentage >= 50
            ? AppColors.warning
            : AppColors.danger;

    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$percentage',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(name),
    );
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingS,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Card showing an attendance with all children's status
class _AttendanceGroupCard extends StatelessWidget {
  const _AttendanceGroupCard({
    required this.group,
    required this.onTap,
    this.isHighlighted = false,
    this.isPast = false,
  });

  final ParentAttendanceGroup group;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      elevation: isHighlighted ? 4 : 1,
      color: isHighlighted
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateHelper.getReadableDate(group.date ?? ''),
                          style: TextStyle(
                            fontSize: isHighlighted ? 18 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (group.typeInfo != null &&
                            group.typeInfo!.isNotEmpty)
                          Text(
                            group.typeInfo!,
                            style: TextStyle(
                              color: AppColors.medium,
                              fontSize: isHighlighted ? 14 : 12,
                            ),
                          ),
                        if (group.startTime != null)
                          Text(
                            '${group.startTime}${group.endTime != null ? ' - ${group.endTime}' : ''}',
                            style: const TextStyle(
                              color: AppColors.medium,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (group.hasPlan)
                    Icon(
                      Icons.list_alt,
                      size: 20,
                      color: AppColors.primary,
                    ),
                ],
              ),
              if (group.deadlineText != null && !isPast && !group.allChildrenResponded) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      group.isDeadlinePassed
                          ? Icons.warning_amber
                          : Icons.schedule,
                      size: 14,
                      color: group.isDeadlinePassed
                          ? AppColors.danger
                          : AppColors.medium,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      group.deadlineText!,
                      style: TextStyle(
                        fontSize: 11,
                        color: group.isDeadlinePassed
                            ? AppColors.danger
                            : AppColors.medium,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppDimensions.paddingS),
              // Child status badges
              Wrap(
                spacing: AppDimensions.paddingS,
                runSpacing: AppDimensions.paddingXS,
                children: group.childAttendances.map((childAtt) {
                  return _ChildStatusBadge(
                    name: childAtt.childName.split(' ').first,
                    status: childAtt.status,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge showing child name and status
class _ChildStatusBadge extends StatelessWidget {
  const _ChildStatusBadge({
    required this.name,
    required this.status,
  });

  final String name;
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getColor().withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Icon(_getIcon(), size: 14, color: _getColor()),
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
}

/// Tile for child attendance action in bottom sheet
class _ChildAttendanceActionTile extends StatelessWidget {
  const _ChildAttendanceActionTile({
    required this.childAttendance,
    required this.isDeadlinePassed,
    required this.onSignIn,
    required this.onSignOut,
    required this.onLateComing,
  });

  final ChildPersonAttendance childAttendance;
  final bool isDeadlinePassed;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback onLateComing;

  @override
  Widget build(BuildContext context) {
    final isPresent = childAttendance.status == AttendanceStatus.present ||
        childAttendance.status == AttendanceStatus.late;
    final isExcused = childAttendance.status == AttendanceStatus.excused ||
        childAttendance.status == AttendanceStatus.lateExcused;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingXS,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    childAttendance.childName.isNotEmpty
                        ? childAttendance.childName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.paddingS),
                Expanded(
                  child: Text(
                    childAttendance.childName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                _ChildStatusBadge(
                  name: '',
                  status: childAttendance.status,
                ),
              ],
            ),
            if (childAttendance.notes != null &&
                childAttendance.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Notiz: ${childAttendance.notes}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.medium,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingS),
            if (isPresent)
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text(
                      'Angemeldet',
                      style: TextStyle(color: AppColors.success, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (isExcused)
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, color: AppColors.info, size: 18),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text(
                      'Entschuldigt',
                      style: TextStyle(color: AppColors.info, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (isDeadlinePassed)
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.medium.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusS),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_clock, color: AppColors.medium, size: 18),
                    SizedBox(width: AppDimensions.paddingXS),
                    Text(
                      'Anmeldefrist abgelaufen',
                      style: TextStyle(color: AppColors.medium, fontSize: 13),
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
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Anmelden'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Abmelden'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.paddingS),
                  IconButton(
                    onPressed: onLateComing,
                    icon: const Icon(Icons.schedule),
                    tooltip: 'Verspätung',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.1),
                      foregroundColor: AppColors.warning,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
