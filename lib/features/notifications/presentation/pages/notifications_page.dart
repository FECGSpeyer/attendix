import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/notification_settings_providers.dart';
import '../../../../core/providers/push_providers.dart'; // PUSH
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
import '../../../settings/presentation/widgets/ion_condense.dart'; // UX_SETTINGS (WAVE 8)
import '../../../settings/presentation/widgets/settings_list.dart'; // UX_SETTINGS (WAVE 8)
import '../../../../core/utils/error_message.dart';
import 'package:attendix/shared/widgets/layout/ios_tab_bar.dart'; // IOS_SHELL2
import '../../../../shared/widgets/adaptive/adaptive.dart'; // IOS_LOOK

/// Notifications settings page (Ionic notifications.page).
///
/// Telegram connection, master switch, push switch (native apps only, like
/// Ionic `isNative`), Live Activity switch (iOS app only), notification
/// categories and the per-tenant toggles.
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

  /// PUSH: Ionic togglePush – sets `push_enabled` and registers the device.
  Future<void> _togglePush(NotificationConfig current, bool enabled) async {
    setState(() => _config = current.copyWith(pushEnabled: enabled));
    await ref.read(pushServiceProvider).togglePush(enabled);
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
              ? const AppSpinner()
              : Text(context.l10n.notifFlutterConfigNotFound),
        ),
      );
    }

    final isConnected = config.isConnected;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final hasDutyTypes = ref.watch(tenantHasDutyTypesProvider).valueOrNull ?? false;

    final ios = ionIsIos(context);
    // UX_SETTINGS (WAVE 8): notifications.page.html — condense title, an
    // ion-card per block (ios26 radius 24 + shadow), uppercase
    // ion-card-subtitle above the category and tenant cards.
    return IonCondense(builder: (context, collapsed) => Scaffold(
      appBar: AppBar(title: IonCondenseTitle(context.l10n.notifTitle, collapsed: collapsed)),
      body: ListView(
        padding: ios
            ? EdgeInsets.fromLTRB(16, 0, 16, scrollEndPadding(context, base: 24))
            : EdgeInsets.fromLTRB(AppDimensions.paddingM, AppDimensions.paddingM,
                AppDimensions.paddingM,
                scrollEndPadding(context, base: AppDimensions.paddingM)),
        children: [
          IonLargeTitle(context.l10n.notifTitle, padding: const EdgeInsets.only(bottom: 4)),
          _group(
            context,
            top: true,
            [
                SwitchListTile.adaptive(
                  title: Text(context.l10n.notifEnable),
                  value: config.enabled,
                  onChanged: (v) => _updateConfig(config.copyWith(enabled: v)),
                ),
                if (!isConnected) _UserIdTile(userId: config.id),
                ListTile(
                  leading: ios
                      ? null
                      : Icon(
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
                      // Ionic: solid ion-button color="danger"
                      ? ElevatedButton(
                          onPressed: _disconnectTelegram,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(context.l10n.notifDisconnect),
                        )
                      : ElevatedButton(
                          onPressed: _connectTelegram,
                          child: Text(context.l10n.notifConnect),
                        ),
                ),
                // PUSH: Ionic `@if (isNative)` – push switch in the native apps
                if (isNativePushPlatform)
                  SwitchListTile.adaptive(
                    title: Text(context.l10n.notifPush),
                    value: config.pushEnabled,
                    onChanged: (v) => _togglePush(config, v),
                  ),
                // LIVE_ACTIVITY: only app builds with the native Live Activity side (iOS)
                if (ref.read(liveActivityServiceProvider).hasNativePlugin)
                  IonToggleItem(
                    title: context.l10n.notifLiveActivity,
                    helper: LiveActivityService.isSupportedPlatform
                        ? context.l10n.notifLiveActivityHelperIos
                        : context.l10n.notifLiveActivityHelper,
                    value: config.liveActivity != false,
                    onChanged: (v) => _toggleLiveActivity(config, v),
                  ),
                // LIVE_ACTIVITY end
                if (config.pushEnabled && isConnected)
                  IonToggleItem(
                    title: context.l10n.notifBothChannels,
                    helper: context.l10n.notifBothChannelsHelper,
                    value: config.pushAndTelegram,
                    onChanged: (v) =>
                        _updateConfig(config.copyWith(pushAndTelegram: v)),
                  ),
                if (config.pushEnabled && isConnected && !config.pushAndTelegram)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      context.l10n.notifPushPreferred,
                      style: const TextStyle(fontSize: 12, color: AppColors.medium),
                    ),
                  ),
            ],
          ),
          if (config.enabled) ...[
            _SectionTitle(context.l10n.notifTitle),
            _group(
              context,
              [
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
                  ),
              ],
            ),
            if (tenants.isNotEmpty) ...[
              _SectionTitle(context.l10n.notifTenantSettings),
              _group(
                context,
                [
                    for (final tenant in tenants)
                      if (tenant.id != null)
                        SwitchListTile.adaptive(
                          title: Text(tenant.longName.isNotEmpty
                              ? tenant.longName
                              : tenant.shortName),
                          value: config.isTenantEnabled(tenant.id!),
                          onChanged: (_) =>
                              _updateConfig(config.toggleTenant(tenant.id!)),
                        ),
              ],
            ),
          ],
          ],
          if (!ios) const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    ));
  }

  /// One Ionic `ion-card` holding items. iOS: ios26 card (radius 24,
  /// shadow, margin-bottom 24) with inset hairlines; md: Material card.
  Widget _group(BuildContext context, List<Widget> children, {bool top = false}) {
    if (ionIsIos(context)) {
      return IonCardBox(
        margin: EdgeInsets.only(top: top ? 8 : 0, bottom: 24),
        child: IonInsetGroup(children: children),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _toggle(
    String title,
    String? helper,
    bool value,
    NotificationConfig Function(bool) update,
  ) {
    return IonToggleItem(
      title: title,
      helper: helper,
      value: value,
      onChanged: (v) => _updateConfig(update(v)),
    );
  }
}

class _UserIdTile extends StatelessWidget {
  const _UserIdTile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        context.l10n.notifUserId,
        style: TextStyle(fontSize: ionIsIos(context) ? 14 : 12),
      ),
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
    if (ionIsIos(context)) {
      // ion-card-subtitle (ios): 12px bold uppercase, letter-spacing .4,
      // step-600 grey; margin-left 1.5rem from the screen edge.
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF999999)
                : const Color(0xFF666666),
          ),
        ),
      );
    }
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
