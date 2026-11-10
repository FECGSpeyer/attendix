import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/providers/notification_settings_providers.dart';
import '../../../../core/providers/push_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/router/redesign_routes.dart';
import '../../../../core/services/live_activity_service.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../core/theme/redesign/rd_theme.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../l10n/l10n.dart';
import '../widgets/rd_widgets.dart';

/// REDESIGN: Ich › Benachrichtigungen (canvas "Benachrichtigungen"): the
/// settings of the old notifications page in three blocks (Wie, Für mich,
/// Als Leitung) plus the per-group switches. Same `notifications` row and
/// services as the old page; nothing new is stored.
class RdNotificationsPage extends ConsumerStatefulWidget {
  const RdNotificationsPage({super.key});

  @override
  ConsumerState<RdNotificationsPage> createState() => _RdNotificationsPageState();
}

class _RdNotificationsPageState extends ConsumerState<RdNotificationsPage> {
  NotificationConfig? _config;
  bool _loading = true;
  RealtimeChannel? _channel;

  /// The system (iOS/Android settings) blocks Attendix' notifications.
  bool _blocked = false;

  /// "Weitere" in "Für mich" is open.
  bool _showMore = false;
  late final SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    _supabase = ref.read(supabaseClientProvider);
    _load();
    _checkBlocked();
  }

  Future<void> _checkBlocked() async {
    final blocked = await ref.read(pushServiceProvider).isBlockedBySystem();
    if (mounted && blocked != _blocked) setState(() => _blocked = blocked);
  }

  /// iOS: opens Attendix in the Settings app (try-catch: PWA/other platforms).
  Future<void> _openSystemSettings() async {
    try {
      await launchUrl(Uri.parse('app-settings:'));
    } catch (_) {}
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _supabase.removeChannel(channel);
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final config = await ref.read(telegramServiceProvider).getNotificationConfig(user.id);
      if (!mounted) return;
      setState(() => _config = config);
      _subscribe(user.id);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.notifFlutterUpdateFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Live update when the Telegram bot links the chat (like the old page).
  void _subscribe(String userId) {
    _channel ??= _supabase
        .channel('rd-noti-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isNotEmpty && row['id'] == userId && mounted) {
              setState(() => _config = NotificationConfig.fromJson(row));
            }
          },
        )
        .subscribe();
  }

  Future<void> _update(NotificationConfig next) async {
    final previous = _config;
    setState(() => _config = next);
    // Read before the await: the page may be left while saving.
    final tracking = ref.read(trackingServiceProvider);
    try {
      await ref.read(telegramServiceProvider).updateNotificationConfig(next);
      tracking.track(
        TrackingEvent.notificationSettingsChanged,
        properties: {'enabled': next.enabled, 'pushEnabled': next.pushEnabled},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _config = previous);
      ToastHelper.showError(context, context.l10n.notifFlutterUpdateFailed);
    }
  }

  Future<void> _togglePush(NotificationConfig config, bool enabled) async {
    setState(() => _config = config.copyWith(pushEnabled: enabled));
    try {
      await ref.read(pushServiceProvider).togglePush(enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _config = config);
      ToastHelper.showError(context, context.l10n.notifFlutterUpdateFailed);
    }
  }

  Future<void> _toggleLiveActivity(NotificationConfig config, bool enabled) async {
    await _update(config.copyWith(liveActivity: enabled));
    // Only follow when the setting was stored (_update rolls back on error).
    if (_config?.liveActivity != enabled) return;
    try {
      await ref.read(liveActivityServiceProvider).setEnabled(enabled);
    } catch (_) {
      // The stored setting wins; the next app start syncs the activities.
    }
  }

  Future<void> _connectTelegram() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final uri = Uri.parse(ref.read(telegramServiceProvider).getBotLink(userId));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.notifFlutterTelegramOpenFailed);
    }
  }

  Future<void> _disconnectTelegram(NotificationConfig config) async {
    final l10n = context.l10n;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: l10n.notifDisconnectConfirm,
      message: l10n.notifDisconnectHint,
      confirmText: l10n.redesignNotifTelegramDisconnect,
      isDestructive: true,
    );
    if (confirmed) await _update(config.copyWith(telegramChatId: ''));
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) {
    return RdSwitchRow(title: title, subtitle: subtitle, value: value, onChanged: onChanged);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.rd;
    final l10n = context.l10n;
    final config = _config;
    final header = <Widget>[
      RdBackLink(
        label: l10n.redesignTabMe,
        onTap: () => context.canPop() ? context.pop() : context.go(RedesignRoutes.me),
      ),
      const SizedBox(height: 4),
      Semantics(header: true, child: Text(l10n.notifTitle, style: RdType.largeTitle(p))),
      const SizedBox(height: 18),
    ];
    if (_loading || config == null) {
      return RdPage(children: [
        ...header,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: _loading
                ? CircularProgressIndicator(color: p.primary)
                : Text(l10n.notifFlutterConfigNotFound, style: RdType.body(p)),
          ),
        ),
      ]);
    }

    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final hasDutyTypes = ref.watch(tenantHasDutyTypesProvider).valueOrNull ?? false;
    final liveActivity = ref.read(liveActivityServiceProvider).hasNativePlugin;
    final connected = config.isConnected;
    // Sign-in/out, registrations and problem cases only reach admins and
    // responsible persons (edge functions: role 1 or 5) – of any group.
    final isLead = tenants.any((t) => t.role == Role.admin.value || t.role == Role.responsible.value);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    NotificationConfig Function(bool) set(NotificationConfig Function(bool) f) => f;
    Widget row(String title, String? hint, bool value, NotificationConfig Function(bool) update) =>
        _switch(title, value, (v) => _update(update(v)), subtitle: hint);

    final more = <Widget>[
      row(l10n.notifTasks, l10n.redesignNotifTasksHint, config.tasks, set((v) => config.copyWith(tasks: v))),
      if (isLead)
        row(l10n.notifChecklist, l10n.redesignNotifChecklistHint, config.checklist,
            set((v) => config.copyWith(checklist: v))),
      row(l10n.notifAppUpdates, l10n.redesignNotifUpdatesHint, config.updates, set((v) => config.copyWith(updates: v))),
    ];

    return RdPage(
      children: [
        ...header,
        if (_blocked && config.enabled && config.pushEnabled) ...[
          Container(
            key: const Key('rd-notif-blocked'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            decoration: BoxDecoration(color: p.lateSoft, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.redesignNotifBlockedTitle,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.late)),
                const SizedBox(height: 2),
                Text(ios ? l10n.redesignNotifBlockedIos : l10n.redesignNotifBlockedAndroid,
                    style: TextStyle(fontSize: 14, color: p.text, height: 1.35)),
                if (ios)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RdTextLink(label: l10n.redesignNotifOpenSettings, onTap: _openSystemSettings),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        RdGroupedList(
          children: [
            _switch(l10n.redesignNotifMaster, config.enabled, (v) => _update(config.copyWith(enabled: v)),
                subtitle: config.enabled ? null : l10n.redesignNotifMasterHint),
          ],
        ),
        if (config.enabled) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignNotifHow),
          RdGroupedList(
            children: [
              if (isNativePushPlatform)
                _switch(l10n.redesignNotifPush, config.pushEnabled, (v) => _togglePush(config, v),
                    subtitle: l10n.redesignNotifPushHint),
              RdListRow(
                title: l10n.redesignNotifTelegram,
                subtitle: connected ? l10n.redesignNotifTelegramConnected : l10n.redesignNotifTelegramHint,
                showChevron: false,
                trailing: RdTextLink(
                  label: connected ? l10n.redesignNotifTelegramDisconnect : l10n.redesignNotifTelegramConnect,
                  onTap: connected ? () => _disconnectTelegram(config) : _connectTelegram,
                ),
              ),
              if (config.pushEnabled && connected)
                _switch(
                  l10n.notifBothChannels,
                  config.pushAndTelegram,
                  (v) => _update(config.copyWith(pushAndTelegram: v)),
                  subtitle: l10n.notifBothChannelsHelper,
                ),
            ],
          ),
        ],
        if (liveActivity) ...[
          const SizedBox(height: 24),
          RdGroupedList(
            children: [
              _switch(
                l10n.notifLiveActivity,
                config.liveActivity != false,
                (v) => _toggleLiveActivity(config, v),
                subtitle: LiveActivityService.isSupportedPlatform
                    ? l10n.notifLiveActivityHelperIos
                    : l10n.notifLiveActivityHelper,
              ),
            ],
          ),
        ],
        if (config.enabled) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignNotifForMe),
          RdGroupedList(
            children: [
              row(l10n.notifEventReminders, l10n.redesignNotifRemindersHint, config.reminders,
                  set((v) => config.copyWith(reminders: v))),
              row(l10n.notifAnnouncements, l10n.redesignNotifMessagesHint, config.messages,
                  set((v) => config.copyWith(messages: v))),
              if (hasDutyTypes)
                row(l10n.notifDuties, l10n.redesignNotifDutiesHint, config.duties != false,
                    set((v) => config.copyWith(duties: v))),
              row(l10n.notifBirthdays, l10n.redesignNotifBirthdaysHint, config.birthdays,
                  set((v) => config.copyWith(birthdays: v))),
              if (_showMore)
                ...more
              else
                RdListRow(
                  key: const Key('rd-notif-more'),
                  title: l10n.redesignNotifMore,
                  value: '${more.length}',
                  onTap: () => setState(() => _showMore = true),
                ),
            ],
          ),
          if (isLead) ...[
            const SizedBox(height: 24),
            RdGroupLabel(l10n.redesignNotifLead),
            RdGroupedList(
              children: [
                row(l10n.redesignNotifSignouts, l10n.redesignNotifSignoutsHint, config.signouts,
                    set((v) => config.copyWith(signouts: v))),
                row(l10n.redesignNotifSignins, l10n.redesignNotifSigninsHint, config.signins,
                    set((v) => config.copyWith(signins: v))),
                row(l10n.redesignNotifRegistrations, l10n.redesignNotifRegistrationsHint, config.registrations,
                    set((v) => config.copyWith(registrations: v))),
                row(l10n.redesignNotifCriticals, l10n.redesignNotifCriticalsHint, config.criticals,
                    set((v) => config.copyWith(criticals: v))),
              ],
            ),
          ],
          if (tenants.length > 1) ...[
            const SizedBox(height: 24),
            RdGroupLabel(l10n.redesignNotifGroups),
            RdGroupedList(
              children: [
                for (final tenant in tenants)
                  if (tenant.id != null)
                    _switch(
                      tenant.longName.isNotEmpty ? tenant.longName : tenant.shortName,
                      config.isTenantEnabled(tenant.id!),
                      (_) => _update(config.toggleTenant(tenant.id!)),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(l10n.redesignNotifGroupsHint, style: RdType.meta(p, size: 13)),
            ),
          ],
        ],
      ],
    );
  }
}
