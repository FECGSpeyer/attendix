import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/signout_providers.dart'; // INTEGRATION
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/ionic_route_mapper.dart'; // INTEGRATION
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/models/user_notification/user_notification.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Notification bell for page app bars (port of Ionic `NotificationBellComponent`).
///
/// Shows the unread count of the current instance and opens the notification
/// center (current instance / all instances) as a bottom sheet.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    var allTenants = false;
    List<UserNotification> list;
    try {
      list = await ref.read(userNotificationsProvider(false).future);
      if (list.isEmpty) {
        // Fall back to the all-instances view so notifications from other
        // instances are still visible.
        allTenants = true;
        list = await ref.read(userNotificationsProvider(true).future);
      }
    } catch (_) {
      list = const [];
    }
    ref.invalidate(unreadNotificationCountProvider);
    if (!context.mounted) return;
    if (list.isEmpty) {
      ToastHelper.showInfo(context, context.l10n.bellNoneAvailable);
      return;
    }

    final target = await showModalBottomSheet<_BellTarget>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      // ion-content color="light" behind the inset list
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 1,
            builder:
                (context, scrollController) => _NotificationCenter(
                  initialAllTenants: allTenants,
                  scrollController: scrollController,
                ),
          ),
    );
    if (target != null && context.mounted) {
      await _navigate(context, ref, target.notification);
    }
  }

  /// Opens the target of a tapped notification (switches instance if needed).
  Future<void> _navigate(BuildContext context, WidgetRef ref, UserNotification n) async {
    final router = GoRouter.of(context);
    final targetTenant = n.targetTenantId;
    if (targetTenant != ref.read(currentTenantIdProvider)) {
      final tenants = await ref.read(userTenantsProvider.future);
      Tenant? tenant;
      for (final t in tenants) {
        if (t.id == targetTenant) tenant = t;
      }
      if (tenant == null) return;
      await ref.read(currentTenantProvider.notifier).setTenant(tenant);
    }

    final messageId = n.messageId;
    if (n.type == 'message' && messageId != null) {
      router.push('/messages/$messageId');
      return;
    }

    final route = n.route;
    if (route != null) {
      // Ionic routes are prefixed with /tabs; only navigate when the route
      // exists in this app.
      final path = mapIonicRoute(route); // INTEGRATION
      try {
        if (router.configuration.findMatch(Uri.parse(path)).isNotEmpty) {
          router.push(path);
        }
      } catch (_) {
        // Unknown route: nothing to open.
      }
      return;
    }

    final attendanceId = n.attendanceId;
    if (attendanceId == null) return; // criticals / birthday: nothing to open

    final tenantUser = await ref.read(currentTenantUserProvider.future);
    final role = tenantUser?.roleEnum;
    if (role != null &&
        (role.isAdmin || role.isResponsible || role.isHelper || role.isVoiceLeaderHelper)) {
      router.push('/attendance/$attendanceId');
    } else if (role != null && role.isParent) {
      // LOGIC_SELF: the parents portal opens the Termin's action sheet
      // (Ionic navigateToAttendance sets pendingAttendanceId for PARENT too).
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go('/parents');
    } else {
      // INTEGRATION: Ionic navigateToAttendance – "Meine Termine" opens the
      // Termin's action sheet via the pending attendance id.
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go('/signout');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userNotificationsRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return IconButton(
      tooltip: context.l10n.bellTitle,
      onPressed: () => _open(context, ref),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _BellTarget {
  const _BellTarget(this.notification);
  final UserNotification notification;
}

class _NotificationCenter extends ConsumerStatefulWidget {
  const _NotificationCenter({required this.initialAllTenants, required this.scrollController});

  final bool initialAllTenants;
  final ScrollController scrollController;

  @override
  ConsumerState<_NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends ConsumerState<_NotificationCenter> {
  late bool _allTenants = widget.initialAllTenants;

  /// Local read-state overrides so toggled rows update in place.
  final Map<String, bool> _readOverrides = {};

  UserNotificationNotifier get _notifier => ref.read(userNotificationNotifierProvider.notifier);

  bool _isRead(UserNotification n) => _readOverrides[n.id] ?? n.read;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.svcSaveFailed);
    }
  }

  Future<void> _markAll() async {
    if (_allTenants) {
      final ok = await _confirm(
        title: context.l10n.bellMarkAllHeader,
        message: context.l10n.bellMarkAllMessage,
        confirmText: context.l10n.bellMark,
      );
      if (!ok) return;
    }
    _readOverrides.clear();
    await _guard(() => _notifier.markAllRead(allTenants: _allTenants));
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      title: context.l10n.bellDeleteAllHeader,
      message:
          _allTenants ? context.l10n.bellDeleteAllMessage : context.l10n.commonCannotUndo,
      confirmText: context.l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await _guard(() => _notifier.deleteAll(allTenants: _allTenants));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    bool destructive = false,
  }) async {
    final result = await showAppDialog<bool>(
      context: context,
      builder:
          (ctx) => AppAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    destructive
                        ? TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error)
                        : null,
                child: Text(confirmText),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _toggleRead(UserNotification n) async {
    final newRead = !_isRead(n);
    setState(() => _readOverrides[n.id] = newRead);
    await _guard(() => _notifier.setRead(n, newRead));
  }

  Future<void> _onTap(UserNotification n) async {
    if (!_isRead(n)) {
      setState(() => _readOverrides[n.id] = true);
      await _guard(() => _notifier.setRead(n, true));
    }
    if (!mounted) return;
    Navigator.of(context).pop(_BellTarget(n));
  }

  String _tenantName(UserNotification n, List<Tenant> tenants) {
    for (final t in tenants) {
      if (t.id == n.tenantId) return t.shortName.isNotEmpty ? t.shortName : t.longName;
    }
    return '';
  }

  List<Widget> _headerButtons(int unread, List<UserNotification> list) => [
        if (unread > 0)
          IconButton(
            tooltip: context.l10n.bellMarkAllRead,
            color: AppColors.primary,
            icon: const Icon(Icons.done_all),
            onPressed: _markAll,
          ),
        if (list.isNotEmpty)
          IconButton(
            tooltip: context.l10n.bellDeleteAll,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: _deleteAll,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final listAsync = ref.watch(userNotificationsProvider(_allTenants));
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final list = listAsync.valueOrNull ?? const <UserNotification>[];

    return Column(
      children: [
        // ion-toolbar: ion-title (centred on iOS) + end buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
          child: Row(
            children: [
              if (ios) const SizedBox(width: 96),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    context.l10n.bellTitle,
                    textAlign: ios ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontSize: ios ? 17 : 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (ios)
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _headerButtons(unread, list),
                  ),
                )
              else
                ..._headerButtons(unread, list),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          child: AppSegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(context.l10n.bellCurrentInstance)),
              ButtonSegment(value: true, label: Text(context.l10n.commonAll)),
            ],
            selected: {_allTenants},
            onSelectionChanged:
                (s) => setState(() {
                  _allTenants = s.first;
                  _readOverrides.clear();
                }),
          ),
        ),
        Expanded(
          child: RefreshIndicator.adaptive(
            onRefresh: () async {
              _readOverrides.clear();
              ref.invalidate(unreadNotificationCountProvider);
              ref.invalidate(userNotificationsProvider(_allTenants));
              await ref.read(userNotificationsProvider(_allTenants).future);
            },
            child:
                listAsync.isLoading && list.isEmpty
                    ? ListView(
                      controller: widget.scrollController,
                      children: const [
                        SizedBox(height: 80),
                        Center(child: AppSpinner()),
                      ],
                    )
                    : list.isEmpty
                    ? ListView(
                      controller: widget.scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.medium),
                        const SizedBox(height: AppDimensions.paddingS),
                        Center(child: Text(context.l10n.bellNone)),
                      ],
                    )
                    : ListView(
                      controller: widget.scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        // ion-list [inset]: one rounded group
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: ios ? 20 : 16),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color ?? theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(ios ? 28 : 16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < list.length; i++) ...[
                                if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 16),
                                _buildRow(list[i], tenants, ios),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ],
    );
  }

  /// ion-item-sliding: start = read/unread (primary), end = delete (danger);
  /// unread dot (danger) at the start, tenant tag, body, date note, detail
  /// chevron for navigable rows.
  Widget _buildRow(UserNotification n, List<Tenant> tenants, bool ios) {
    final read = _isRead(n);
    final tenantName = _allTenants ? _tenantName(n, tenants) : '';
    final theme = Theme.of(context);
    return Slidable(
      key: ValueKey(n.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _toggleRead(n),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: read ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _guard(() => _notifier.deleteOne(n)),
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _onTap(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              if (!read) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tenantName.isNotEmpty)
                      Text(
                        tenantName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.medium,
                        ),
                      ),
                    Text(
                      n.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.createdAt == null
                          ? ''
                          : DateFormat('${dateFmt()} HH:mm').format(n.createdAt!.toLocal()),
                      style: const TextStyle(fontSize: 11, color: AppColors.medium),
                    ),
                  ],
                ),
              ),
              if (n.isNavigable)
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.medium.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
