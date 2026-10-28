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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dialog_helper.dart';
import '../../../../core/utils/toast_helper.dart';
import '../../../../data/models/tenant/tenant.dart';

/// Notifications settings page (Ionic notifications.page).
///
/// Telegram connection, master switch, notification categories and the
/// per-tenant toggles. Push / Live Activity toggles are native-only in Ionic
/// and are not available in the PWA.
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
      if (mounted) ToastHelper.showError(context, 'Fehler beim Laden: $e');
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
    } catch (_) {
      if (mounted) {
        setState(() => _config = previous);
        ToastHelper.showError(
            context, 'Fehler beim Aktualisieren der Konfiguration');
      }
    }
  }

  Future<void> _connectTelegram() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final uri = Uri.parse(ref.read(telegramServiceProvider).getBotLink(userId));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ToastHelper.showError(context, 'Konnte Telegram nicht öffnen');
    }
  }

  Future<void> _disconnectTelegram() async {
    final current = _config;
    if (current == null) return;
    final confirmed = await DialogHelper.showConfirmation(
      context,
      title: 'Möchtest du die Verbindung wirklich trennen?',
      message: 'Die Verbindung kann jederzeit wiederhergestellt werden',
      confirmText: 'Ja',
      cancelText: 'Abbrechen',
    );
    if (!confirmed) return;
    await _updateConfig(current.copyWith(telegramChatId: ''));
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (_isLoading || config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Benachrichtigungen')),
        body: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Konfiguration nicht gefunden'),
        ),
      );
    }

    final isConnected = config.isConnected;
    final tenants = ref.watch(userTenantsProvider).valueOrNull ?? const <Tenant>[];
    final hasDutyTypes = ref.watch(tenantHasDutyTypesProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Benachrichtigungen aktivieren'),
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
                  title: const Text('Telegramverknüpfung'),
                  subtitle: isConnected
                      ? const Text(
                          'Konto erfolgreich verknüpft',
                          style: TextStyle(color: AppColors.success),
                        )
                      : null,
                  trailing: isConnected
                      ? TextButton(
                          onPressed: _disconnectTelegram,
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger),
                          child: const Text('Trennen'),
                        )
                      : ElevatedButton(
                          onPressed: _connectTelegram,
                          child: const Text('Verbinden'),
                        ),
                ),
                if (config.pushEnabled && isConnected) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Beide Kanäle gleichzeitig'),
                    subtitle: const Text(
                        'Push und Telegram werden parallel gesendet, nicht nur als Fallback.'),
                    value: config.pushAndTelegram,
                    onChanged: (v) =>
                        _updateConfig(config.copyWith(pushAndTelegram: v)),
                  ),
                  if (!config.pushAndTelegram)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        'Push wird bevorzugt. Telegram wird nur als Fallback genutzt, wenn keine Push-Zustellung möglich ist.',
                        style: TextStyle(fontSize: 12, color: AppColors.medium),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (config.enabled) ...[
            const _SectionTitle('Benachrichtigungen'),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _toggle(
                    'App-Updates',
                    'Erhalte Benachrichtigungen über App-Updates sobald verfügbar',
                    config.updates,
                    (v) => config.copyWith(updates: v),
                  ),
                  _toggle(
                    'Geburtstage',
                    'Erhalte täglich um 8:00 Uhr eine Benachrichtigung, falls jemand heute Geburtstag hat',
                    config.birthdays,
                    (v) => config.copyWith(birthdays: v),
                  ),
                  _toggle(
                    'Mitteilungen',
                    'Nachrichten von Admins und Verantwortlichen deiner Instanz',
                    config.messages,
                    (v) => config.copyWith(messages: v),
                  ),
                  _toggle(
                    'Terminerinnerungen',
                    null,
                    config.reminders,
                    (v) => config.copyWith(reminders: v),
                  ),
                  if (hasDutyTypes)
                    _toggle(
                      'Dienste',
                      'Wenn du für einen Dienst eingeteilt wirst, an die Bestätigung erinnert wirst oder jemand zum Einspringen gesucht wird. Dringende Anfragen kommen trotzdem an.',
                      config.duties != false,
                      (v) => config.copyWith(duties: v),
                    ),
                  _toggle(
                    'Checklisten-Erinnerungen',
                    'Erhalte Erinnerungen für fällige To-Dos in deiner Checkliste. Nur möglich, wenn du Verantwortlicher einer Gruppe bist.',
                    config.checklist,
                    (v) => config.copyWith(checklist: v),
                  ),
                  _toggle(
                    'Aufgaben-Erinnerungen',
                    'Erhalte Erinnerungen 2 Tage vor Fälligkeit von Aufgaben, für die du verantwortlich bist.',
                    config.tasks,
                    (v) => config.copyWith(tasks: v),
                  ),
                  _toggle(
                    'Anmeldungen',
                    _responsibleOnly,
                    config.signins,
                    (v) => config.copyWith(signins: v),
                  ),
                  _toggle(
                    'Abmeldungen',
                    _responsibleOnly,
                    config.signouts,
                    (v) => config.copyWith(signouts: v),
                  ),
                  _toggle(
                    'Neue Problemfälle',
                    _responsibleOnly,
                    config.criticals,
                    (v) => config.copyWith(criticals: v),
                  ),
                  _toggle(
                    'Neu-Registrierungen',
                    _responsibleOnly,
                    config.registrations,
                    (v) => config.copyWith(registrations: v),
                    last: true,
                  ),
                ],
              ),
            ),
            if (tenants.isNotEmpty) ...[
              const _SectionTitle('Instanz-Einstellungen'),
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

  static const _responsibleOnly =
      'Nur möglich, wenn du Verantwortlicher einer Gruppe bist.';

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
      title: const Text('Benutzer-Id', style: TextStyle(fontSize: 12)),
      subtitle: SelectableText(
        userId,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 18),
        tooltip: 'Kopieren',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: userId));
          ToastHelper.showSuccess(context, 'Benutzer-Id kopiert');
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
