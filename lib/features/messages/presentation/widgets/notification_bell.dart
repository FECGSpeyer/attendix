import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/message_providers.dart';
import '../../../../core/providers/redesign_providers.dart';
import '../../../../core/providers/signout_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/ionic_route_mapper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../data/models/user_notification/user_notification.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../redesign/presentation/widgets/rd_widgets.dart';
import '../../../../shared/widgets/layout/ion_modal_handle.dart';
import '../../../../shared/widgets/layout/side_nav/side_nav_layout.dart';

/// Notification bell for page app bars (port of Ionic `NotificationBellComponent`).
///
/// Shows the unread count of the current instance and opens the notification
/// center (current instance / all instances) as a bottom sheet.
class NotificationBell extends ConsumerWidget implements HiddenWithSidePanel {
  const NotificationBell({super.key, this.inSideNav = false});

  /// SIDE_NAV: the bell in the side panel's head. While the side panel is
  /// shown, the bells of the pages are hidden (Ionic
  /// `body.side-panel-active app-notification-bell:not(.in-side-nav)`).
  final bool inSideNav;

  /// REDESIGN: opens the notification centre from another button (the
  /// bell on "Heute" of the new design).
  static Future<void> open(BuildContext context, WidgetRef ref) =>
      const NotificationBell()._open(context, ref);

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

    // IOS_SHEETS: Ionic sheet modal (breakpoints [0, 0.75, 1]). On iOS the
    // sheet is `100% - 10px` high below the safe area and the grabber is drawn
    // over the header (no extra 48pt drag-handle row), so the sheet top sits
    // where Ionic's does.
    // REDESIGN (canvas K1 "Glocke"): Beta sheet like "Gruppe wechseln".
    final beta = ref.read(redesignEnabledProvider);
    final ios = !beta && useIosLook(context);
    // PARITY_R3: Ionic sheet modal on desktop/tablet (min 768 × 600) = a
    // 600 px wide sheet at the bottom (ion-modal `--width: 600px`, sheet
    // height kept) – sized centrally by IonModalTheme.
    final available =
        MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top;
    final full = ios && available > 100 ? (available - 10) / available : 1.0;
    final target = await showModalBottomSheet<_BellTarget>(
      context: context,
      useRootNavigator: true, // IOS_SHELL2: above the tab bar
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: !ios,
      // ion-content color="light" behind the inset list
      backgroundColor: beta ? context.rd.bg : Theme.of(context).scaffoldBackgroundColor,
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75 * full,
            minChildSize: 0.4 * full,
            maxChildSize: full,
            builder:
                (context, scrollController) => _NotificationCenter(
                  initialAllTenants: allTenants,
                  scrollController: scrollController,
                  beta: beta,
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
    final isMessage = n.type == 'message' && n.messageId != null;
    // Ionic onTap: entries without a target (criticals / birthdays) only
    // close the sheet; route and Termin entries switch the instance only
    // when data.tenantId is set.
    if (!isMessage && n.route == null && n.attendanceId == null) return;
    final explicitTenant = int.tryParse(n.data['tenantId']?.toString() ?? '');
    // A Termin id only exists in its own instance: in "Alle Instanzen" an
    // entry of another instance without data.tenantId still has to switch to
    // the row's instance, otherwise the Termin is not found.
    final int? targetTenant = isMessage || (n.route == null && n.attendanceId != null)
        ? n.targetTenantId
        : explicitTenant;
    if (targetTenant != null && targetTenant != ref.read(currentTenantIdProvider)) {
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
      // In the new design (Beta) Termine open on their new pages.
      final path = RedesignRoutes.betaTarget(mapIonicRoute(route));
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
      router.push(RedesignRoutes.betaTarget('/attendance/$attendanceId'));
    } else if (role != null && role.isParent) {
      // LOGIC_SELF: the parents portal opens the Termin's action sheet
      // (Ionic navigateToAttendance sets pendingAttendanceId for PARENT too).
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go('/parents');
    } else {
      // INTEGRATION: Ionic navigateToAttendance – "Meine Termine" opens the
      // Termin's action sheet via the pending attendance id.
      ref.read(pendingAttendanceIdProvider.notifier).state = attendanceId;
      router.go(RedesignRoutes.betaTarget('/signout'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!inSideNav && SideNavScope.isActive(context)) return const SizedBox.shrink();
    ref.watch(userNotificationsRealtimeProvider);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return IconButton(
      tooltip: context.l10n.bellTitle,
      onPressed: () => _open(context, ref),
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text(unread > 99 ? '99+' : '$unread'),
        // ICONS: classic design uses the Ionic app's ionicon, Beta keeps Material.
        child: Icon(ref.watch(redesignEnabledProvider)
            ? Icons.notifications_outlined
            : Ionicons.notificationsOutline),
      ),
    );
  }
}

class _BellTarget {
  const _BellTarget(this.notification);
  final UserNotification notification;
}

class _NotificationCenter extends ConsumerStatefulWidget {
  const _NotificationCenter({required this.initialAllTenants, this.scrollController, this.beta = false});

  final bool initialAllTenants;
  final ScrollController? scrollController;

  /// REDESIGN: title with "•••", "Diese Gruppe / Alle Gruppen", rows grouped
  /// in "Neu" and "Früher".
  final bool beta;

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

  List<Widget> _headerButtons(int unread, List<UserNotification> list, bool ios) => [
        if (unread > 0)
          IconButton(
            tooltip: ios ? null : context.l10n.bellMarkAllRead,
            // iOS: plain ion-button in the glass capsule → black icon.
            color: ios ? null : AppColors.primary,
            icon: Icon(
              Icons.done_all,
              semanticLabel: ios ? context.l10n.bellMarkAllRead : null,
            ),
            onPressed: _markAll,
          ),
        if (list.isNotEmpty)
          IconButton(
            tooltip: ios ? null : context.l10n.bellDeleteAll,
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.danger,
              semanticLabel: ios ? context.l10n.bellDeleteAll : null,
            ),
            onPressed: _deleteAll,
          ),
      ];

  /// `ion-segment` (current instance / all instances).
  Widget _segment(bool ios) => IonSegment<bool>(
        // IOS_SHEETS: segment without color inside an ion-toolbar → neutral
        // iOS control, only as wide as its labels and centred.
        neutral: ios,
        fitContent: ios,
        items: [
          IonSegmentItem(value: false, label: Text(context.l10n.bellCurrentInstance)),
          IonSegmentItem(value: true, label: Text(context.l10n.commonAll)),
        ],
        value: _allTenants,
        onChanged:
            (v) => setState(() {
              _allTenants = v;
              _readOverrides.clear();
            }),
      );

  /// IOS_SHEETS: `ion-header` of the Ionic sheet modal on iOS: grabber over
  /// the title toolbar (centred title, end buttons in one Liquid Glass
  /// capsule), second toolbar with the centred segment, hairline below.
  Widget _iosHeader(int unread, List<UserNotification> list) {
    final theme = Theme.of(context);
    final buttons = _headerButtons(unread, list, true);
    return Container(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: IonModalHandleOverlay(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
              child: SizedBox(
                height: 56,
                child: NavigationToolbar(
                  centerMiddle: true,
                  middleSpacing: 8,
                  middle: Text(
                    context.l10n.bellTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  trailing:
                      buttons.isEmpty ? null : ToolbarButtonGroup(children: buttons),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Center(child: _segment(true)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _betaMore(int unread, List<UserNotification> list) async {
    final l10n = context.l10n;
    final action = await showAppActionSheet<String>(
      context,
      actions: [
        if (unread > 0) AppActionSheetAction(value: 'read', icon: Icons.done_all, label: l10n.bellMarkAllRead),
        if (list.isNotEmpty)
          AppActionSheetAction(value: 'delete', icon: Icons.delete_outline, label: l10n.bellDeleteAll, destructive: true),
      ],
    );
    if (!mounted) return;
    if (action == 'read') await _markAll();
    if (action == 'delete') await _deleteAll();
  }

  Widget _buildBeta(
    AsyncValue<List<UserNotification>> listAsync,
    List<UserNotification> list,
    int unread,
    List<Tenant> tenants,
  ) {
    final p = context.rd;
    final l10n = context.l10n;
    final fresh = [for (final n in list) if (!_isRead(n)) n];
    final older = [for (final n in list) if (_isRead(n)) n];
    Widget group(String label, List<UserNotification> rows) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdGroupLabel(label),
        RdGroupedList(children: [for (final n in rows) _buildBetaRow(n, tenants)]),
        const SizedBox(height: 18),
      ],
    );
    final List<Widget> body;
    if (listAsync.isLoading && list.isEmpty) {
      body = [
        const SizedBox(height: 60),
        Center(child: CircularProgressIndicator(color: p.primary)),
      ];
    } else if (list.isEmpty) {
      body = [
        const SizedBox(height: 60),
        Icon(Icons.notifications_off_outlined, size: 44, color: p.text2),
        const SizedBox(height: 8),
        Text(l10n.bellNone, textAlign: TextAlign.center, style: RdType.meta(p, size: 15)),
      ];
    } else {
      body = [
        if (fresh.isNotEmpty) group(l10n.redesignMessagesBellNew, fresh),
        if (older.isNotEmpty) group(l10n.redesignMessagesBellEarlier, older),
      ];
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(l10n.bellTitle, style: RdType.section(p))),
              ),
              if (unread > 0 || list.isNotEmpty)
                RdCircleButton(
                  key: const Key('rd-bell-more'),
                  icon: Icons.more_horiz,
                  label: l10n.redesignManageListMore,
                  onPressed: () => _betaMore(unread, list),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RdSegmented<bool>(
            values: const [false, true],
            selected: _allTenants,
            labelOf: (all) => all ? l10n.redesignMessagesBellAllGroups : l10n.redesignMessagesBellThisGroup,
            onChanged: (v) => setState(() {
              _allTenants = v;
              _readOverrides.clear();
            }),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: p.primary,
            backgroundColor: p.surface,
            onRefresh: () async {
              _readOverrides.clear();
              ref.invalidate(unreadNotificationCountProvider);
              ref.invalidate(userNotificationsProvider(_allTenants));
              await ref.read(userNotificationsProvider(_allTenants).future);
            },
            child: ListView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: body,
            ),
          ),
        ),
      ],
    );
  }

  /// Beta row: unread dot, the group (in "Alle Gruppen"), text and date;
  /// swipe right = read/unread, swipe left = delete (as before).
  Widget _buildBetaRow(UserNotification n, List<Tenant> tenants) {
    final p = context.rd;
    final read = _isRead(n);
    final tenantName = _allTenants ? _tenantName(n, tenants) : '';
    final body = n.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final when = n.createdAt == null ? '' : DateFormat('${dateFmt()} HH:mm').format(n.createdAt!.toLocal());
    return Slidable(
      key: ValueKey(n.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => _toggleRead(n),
            backgroundColor: p.primary,
            foregroundColor: p.onPrimary,
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
            backgroundColor: p.absent,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
          ),
        ],
      ),
      child: RdListRow(
        leading: SizedBox(
          width: 10,
          child: read
              ? null
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
                ),
        ),
        title: body,
        subtitle: [if (tenantName.isNotEmpty) tenantName, if (when.isNotEmpty) when].join(' · '),
        showChevron: n.isNavigable,
        onTap: () => _onTap(n),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ios = useIosLook(context);
    final listAsync = ref.watch(userNotificationsProvider(_allTenants));
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final list = listAsync.valueOrNull ?? const <UserNotification>[];
    if (widget.beta) return _buildBeta(listAsync, list, unread, tenants);

    return Column(
      children: [
        if (ios)
          _iosHeader(unread, list)
        else ...[
          // ion-toolbar: ion-title + end buttons (md mode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      context.l10n.bellTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                ..._headerButtons(unread, list, false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingS),
            child: _segment(false),
          ),
        ],
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
                            // IOS_SHEETS: white rows on the grey content.
                            color:
                                ios
                                    ? theme.colorScheme.surface
                                    : (theme.cardTheme.color ?? theme.colorScheme.surface),
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
    final onSurface = theme.colorScheme.onSurface;
    // IOS_SHEETS: the body is rendered as HTML in Ionic, so line breaks and
    // repeated spaces collapse ("Allgemein Treffen am …" on one line).
    final body = n.body.replaceAll(RegExp(r'\s+'), ' ').trim();
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
          // iOS ion-item: 16 start padding, label margin 10 top/bottom, detail
          // icon 8 after the label and 10 from the end.
          padding: EdgeInsets.fromLTRB(16, 10, ios ? 10 : 12, 10),
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
                // `.unread-dot { margin-inline-end: 4px }`
                SizedBox(width: ios ? 4 : 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tenantName.isNotEmpty)
                      Text(
                        tenantName,
                        style: TextStyle(
                          // ion-note: max(14px, 1rem)
                          fontSize: ios ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.medium,
                        ),
                      ),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        // iOS `ion-label p`: text-color-step-600 (#999)
                        height: ios ? 1.5 : null,
                        color: onSurface.withValues(alpha: ios ? 0.4 : 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.createdAt == null
                          ? ''
                          : DateFormat('${dateFmt()} HH:mm').format(n.createdAt!.toLocal()),
                      style: TextStyle(
                        fontSize: 11,
                        // iOS ion-note: text-color-step-650 (#a6a6a6)
                        color: ios ? onSurface.withValues(alpha: 0.35) : AppColors.medium,
                      ),
                    ),
                  ],
                ),
              ),
              if (n.isNavigable) ...[
                if (ios) const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: ios ? 20 : 22,
                  // iOS detail icon: opacity .25
                  color:
                      ios
                          ? onSurface.withValues(alpha: 0.25)
                          : AppColors.medium.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
