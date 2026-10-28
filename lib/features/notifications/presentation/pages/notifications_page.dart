import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/notification_settings_providers.dart';
import '../../../../core/providers/tenant_providers.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/services/live_activity_service.dart'; // LIVE_ACTIVITY
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';
import '../../../../core/services/tracking/tracking_event.dart';
import '../../../../core/services/tracking/tracking_service.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/utils/error_message.dart';

/// Notifications settings page (Ionic notifications.page).
///
/// Telegram connection, master switch, notification categories and the
/// per-tenant toggles. Push / Live Activity toggles are native-only in Ionic
/// and are not available in the PWA (Live Activity: iOS app only).
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotificationConfig? _config;
  bool _isLoading = true;
  RealtimeChannel? _channel;
  late final SupabaseClient _supabase;

  @override
  void initState() {
    super.initState();
    _supabase = ref.read(supabaseClientProvider);
    _loadConfig();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _supabase.removeChannel(channel);
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;
      if (user != null) {
        final config =
            await ref.read(telegramServiceProvider).getNotificationConfig(user.id);
        if (mounted) setState(() => _config = config);
        _subscribe(user.id);
      }
    } catch (e) {
      if (mounted) ToastHelper.showError(context, context.l10n.notifFlutterLoadFailed(friendlyErrorMessage(e)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Live updates, e.g. when the Telegram bot links the chat id.
  void _subscribe(String userId) {
    if (_channel != null) return;
    _channel = _supabase
        .channel('noti-changes-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          // notifications has no tenantId: one row per user (id = auth uid)
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

  Future<void> _updateConfig(NotificationConfig newConfig) async {
    final previous = _config;
    setState(() => _config = newConfig);
    try {
      await ref.read(telegramServiceProvider).updateNotificationConfig(newConfig);
      ref.read(trackingServiceProvider).track(TrackingEvent.notificationSettingsChanged, properties: {'enabled': newConfig.enabled, 'pushEnabled': newConfig.pushEnabled});
    } catch (_) {
      if (mounted) {
        setState(() => _config = previous);
        ToastHelper.showError(
            context, context.l10n.notifFlutterUpdateFailed);
      }
    }
  }

  // LIVE_ACTIVITY: Ionic toggleLiveActivity (save setting, then end/sync activities)
  Future<void> _toggleLiveActivity(NotificationConfig config, bool enabled) async {
    await _updateConfig(config.copyWith(liveActivity: enabled));
    await ref.read(liveActivityServiceProvider).setEnabled(enabled);
  }

  Future<void> _connectTelegram() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final uri = Uri.parse(ref.read(telegramServiceProvider).getBotLink(userId));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, context.l10n.notifFlutterTelegramOpenFailed);
    }
  }

  Future<void> _disconnectTelegram() async {
    final current = _config;
    if (current == null) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: context.l10n.notifDisconnectConfirm,
      message: context.l10n.notifDisconnectHint,
      confirmText: context.l10n.commonYes,
      cancelText: context.l10n.commonCancel,
    );
    if (!confirmed) return;
    await _updateConfig(current.copyWith(telegramChatId: ''));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (_isLoading || config == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.notifTitle)),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(context.l10n.notifFlutterConfigNotFound),
        ),
      );
    }

    final isConnected = config.isConnected;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final hasDutyTypes = ref.watch(tenantHasDutyTypesProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.notifTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(context.l10n.notifEnable),
                  value: config.enabled,
                  onChanged: (v) => _updateConfig(config.copyWith(enabled: v)),
                ),
                if (!isConnected) ...[
                  const Divider(height: 1),
                  _UserIdTile(userId: config.id),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.telegram,
                    color: isConnected ? AppColors.success : const Color(0xFF0088CC),
                  ),
                  title: Text(context.l10n.notifTelegram),
                  subtitle: isConnected
                      ? Text(
                          context.l10n.notifLinked,
                          style: const TextStyle(color: AppColors.success),
                        )
                      : null,
                  trailing: isConnected
                      ? TextButton(
                          onPressed: _disconnectTelegram,
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          child: Text(context.l10n.notifDisconnect),
                        )
                      : ElevatedButton(
                          onPressed: _connectTelegram,
                          child: Text(context.l10n.notifConnect),
                        ),
                ),
                // LIVE_ACTIVITY: only app builds with the native Live Activity side (iOS)
                if (ref.read(liveActivityServiceProvider).hasNativePlugin) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(context.l10n.notifLiveActivity),
                    subtitle: Text(LiveActivityService.isSupportedPlatform
                        ? context.l10n.notifLiveActivityHelperIos
                        : context.l10n.notifLiveActivityHelper),
                    value: config.liveActivity != false,
                    onChanged: (v) => _toggleLiveActivity(config, v),
                  ),
                ],
                // LIVE_ACTIVITY end
                if (config.pushEnabled && isConnected) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(context.l10n.notifBothChannels),
                    subtitle: Text(context.l10n.notifBothChannelsHelper),
                    value: config.pushAndTelegram,
                    onChanged: (v) =>
                        _updateConfig(config.copyWith(pushAndTelegram: v)),
                  ),
                  if (!config.pushAndTelegram)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        context.l10n.notifPushPreferred,
                        style: const TextStyle(fontSize: 12, color: AppColors.medium),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (config.enabled) ...[
            _SectionTitle(context.l10n.notifTitle),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _toggle(
                    context.l10n.notifAppUpdates,
                    context.l10n.notifAppUpdatesHelper,
                    config.updates,
                    (v) => config.copyWith(updates: v),
                  ),
                  _toggle(
                    context.l10n.notifBirthdays,
                    context.l10n.notifBirthdaysHelper,
                    config.birthdays,
                    (v) => config.copyWith(birthdays: v),
                  ),
                  _toggle(
                    context.l10n.notifAnnouncements,
                    context.l10n.notifAnnouncementsHelper,
                    config.messages,
                    (v) => config.copyWith(messages: v),
                  ),
                  _toggle(
                    context.l10n.notifEventReminders,
                    null,
                    config.reminders,
                    (v) => config.copyWith(reminders: v),
                  ),
                  if (hasDutyTypes)
                    _toggle(
                      context.l10n.notifDuties,
                      context.l10n.notifDutiesHelper,
                      config.duties != false,
                      (v) => config.copyWith(duties: v),
                    ),
                  _toggle(
                    context.l10n.notifChecklist,
                    context.l10n.notifChecklistHelper,
                    config.checklist,
                    (v) => config.copyWith(checklist: v),
                  ),
                  _toggle(
                    context.l10n.notifTasks,
                    context.l10n.notifTasksHelper,
                    config.tasks,
                    (v) => config.copyWith(tasks: v),
                  ),
                  _toggle(
                    context.l10n.notifSignIns,
                    context.l10n.notifResponsibleOnly,
                    config.signins,
                    (v) => config.copyWith(signins: v),
                  ),
                  _toggle(
                    context.l10n.notifSignOuts,
                    context.l10n.notifResponsibleOnly,
                    config.signouts,
                    (v) => config.copyWith(signouts: v),
                  ),
                  _toggle(
                    context.l10n.notifNewProblemCases,
                    context.l10n.notifResponsibleOnly,
                    config.criticals,
                    (v) => config.copyWith(criticals: v),
                  ),
                  _toggle(
                    context.l10n.notifNewRegistrations,
                    context.l10n.notifResponsibleOnly,
                    config.registrations,
                    (v) => config.copyWith(registrations: v),
                    last: true,
                  ),
                ],
              ),
            ),
            if (tenants.isNotEmpty) ...[
              _SectionTitle(context.l10n.notifTenantSettings),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final tenant in tenants)
                      if (tenant.id != null)
                        SwitchListTile(
                          title: Text(tenant.longName.isNotEmpty
                              ? tenant.longName
                              : tenant.shortName),
                          value: config.isTenantEnabled(tenant.id!),
                          onChanged: (_) =>
                              _updateConfig(config.toggleTenant(tenant.id!)),
                        ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    );
  }

  Widget _toggle(
    String title,
    String? helper,
    bool value,
    NotificationConfig Function(bool) update, {
    bool last = false,
  }) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(title),
          subtitle: helper != null
              ? Text(helper, style: const TextStyle(fontSize: 12))
              : null,
          value: value,
          onChanged: (v) => _updateConfig(update(v)),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

class _UserIdTile extends StatelessWidget {
  const _UserIdTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(context.l10n.notifUserId, style: const TextStyle(fontSize: 12)),
      subtitle: SelectableText(
        userId,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        tooltip: context.l10n.songsCopy,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: userId));
          ToastHelper.showSuccess(context, context.l10n.notifFlutterUserIdCopied);
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingS,
        AppDimensions.paddingL,
        AppDimensions.paddingS,
        AppDimensions.paddingXS,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.medium,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
