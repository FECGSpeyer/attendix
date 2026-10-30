import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
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
  late final SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    _supabase = ref.read(supabaseClientProvider);
    _load();
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
    try {
      await ref.read(telegramServiceProvider).updateNotificationConfig(next);
      ref.read(trackingServiceProvider).track(
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notifDisconnectConfirm),
        content: Text(l10n.notifDisconnectHint),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.redesignNotifTelegramDisconnect)),
        ],
      ),
    );
    if (confirmed == true) await _update(config.copyWith(telegramChatId: ''));
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) {
    final p = context.rd;
    return RdListRow(
      title: title,
      subtitle: subtitle,
      showChevron: false,
      trailing: Switch.adaptive(value: value, activeTrackColor: p.primary, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
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
    NotificationConfig Function(bool) set(NotificationConfig Function(bool) f) => f;

    return RdPage(
      children: [
        ...header,
        RdGroupLabel(l10n.redesignNotifHow),
        RdGroupedList(
          children: [
            _switch(l10n.notifEnable, config.enabled, (v) => _update(config.copyWith(enabled: v))),
            if (isNativePushPlatform)
              _switch(l10n.notifPush, config.pushEnabled, (v) => _togglePush(config, v)),
            RdListRow(
              title: l10n.redesignNotifTelegram,
              subtitle: connected ? l10n.redesignNotifTelegramConnected : null,
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
            if (liveActivity)
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
        if (!connected) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SelectableText('${l10n.notifUserId}: ${config.id}', style: RdType.meta(p, size: 13)),
          ),
        ],
        if (config.enabled) ...[
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignNotifForMe),
          RdGroupedList(
            children: [
              for (final (title, value, update) in [
                (l10n.notifEventReminders, config.reminders, set((v) => config.copyWith(reminders: v))),
                (l10n.notifAnnouncements, config.messages, set((v) => config.copyWith(messages: v))),
                if (hasDutyTypes)
                  (l10n.notifDuties, config.duties != false, set((v) => config.copyWith(duties: v))),
                (l10n.notifTasks, config.tasks, set((v) => config.copyWith(tasks: v))),
                (l10n.notifChecklist, config.checklist, set((v) => config.copyWith(checklist: v))),
                (l10n.notifBirthdays, config.birthdays, set((v) => config.copyWith(birthdays: v))),
                (l10n.notifAppUpdates, config.updates, set((v) => config.copyWith(updates: v))),
              ])
                _switch(title, value, (v) => _update(update(v))),
            ],
          ),
          const SizedBox(height: 24),
          RdGroupLabel(l10n.redesignNotifLead),
          RdGroupedList(
            children: [
              for (final (title, value, update) in [
                (l10n.notifSignOuts, config.signouts, set((v) => config.copyWith(signouts: v))),
                (l10n.notifSignIns, config.signins, set((v) => config.copyWith(signins: v))),
                (l10n.notifNewRegistrations, config.registrations, set((v) => config.copyWith(registrations: v))),
                (l10n.notifNewProblemCases, config.criticals, set((v) => config.copyWith(criticals: v))),
              ])
                _switch(title, value, (v) => _update(update(v))),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l10n.notifResponsibleOnly, style: RdType.meta(p, size: 13)),
          ),
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
