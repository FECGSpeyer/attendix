import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Notification configuration model
class NotificationConfig {
  final String id;
  final DateTime? createdAt;
  final bool enabled;
  final String? telegramChatId;
  final bool birthdays;
  final bool signins;
  final bool signouts;
  final bool updates;
  final bool registrations;
  final bool criticals;
  final bool reminders;
  final bool checklist;
  final List<int>? enabledTenants;
  final bool tasks;
  final bool messages;
  final bool pushEnabled;
  final bool pushAndTelegram;

  /// Dienste notifications; null counts as on (Ionic).
  final bool? duties;

  /// Live Activity (native only); null counts as on (Ionic).
  final bool? liveActivity;

  NotificationConfig({
    required this.id,
    this.createdAt,
    this.enabled = false,
    this.telegramChatId,
    this.birthdays = true,
    this.signins = true,
    this.signouts = true,
    this.updates = true,
    this.registrations = true,
    this.criticals = true,
    this.reminders = true,
    this.checklist = true,
    this.enabledTenants,
    this.tasks = true,
    this.messages = true,
    this.pushEnabled = false,
    this.pushAndTelegram = false,
    this.duties,
    this.liveActivity,
  });

  factory NotificationConfig.fromJson(Map<String, dynamic> json) => NotificationConfig(
        id: json['id'] as String,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        enabled: json['enabled'] as bool? ?? false,
        telegramChatId: json['telegram_chat_id'] as String?,
        birthdays: json['birthdays'] as bool? ?? true,
        signins: json['signins'] as bool? ?? true,
        signouts: json['signouts'] as bool? ?? true,
        updates: json['updates'] as bool? ?? true,
        registrations: json['registrations'] as bool? ?? true,
        criticals: json['criticals'] as bool? ?? true,
        reminders: json['reminders'] as bool? ?? true,
        checklist: json['checklist'] as bool? ?? true,
        // Ionic maps enabled_tenants with Number() (may be stored as strings)
        enabledTenants: (json['enabled_tenants'] as List?)
            ?.map((e) => e is int ? e : int.tryParse(e.toString()))
            .whereType<int>()
            .toList(),
        tasks: json['tasks'] as bool? ?? true,
        messages: json['messages'] as bool? ?? true,
        pushEnabled: json['push_enabled'] as bool? ?? false,
        pushAndTelegram: json['push_and_telegram'] as bool? ?? false,
        duties: json['duties'] as bool?,
        liveActivity: json['live_activity'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'telegram_chat_id': telegramChatId,
        'birthdays': birthdays,
        'signins': signins,
        'signouts': signouts,
        'updates': updates,
        'registrations': registrations,
        'criticals': criticals,
        'reminders': reminders,
        'checklist': checklist,
        'enabled_tenants': enabledTenants,
        'tasks': tasks,
        'messages': messages,
        'push_enabled': pushEnabled,
        'push_and_telegram': pushAndTelegram,
        if (duties != null) 'duties': duties,
        if (liveActivity != null) 'live_activity': liveActivity,
      };

  NotificationConfig copyWith({
    String? id,
    DateTime? createdAt,
    bool? enabled,
    String? telegramChatId,
    bool clearTelegramChatId = false,
    bool? birthdays,
    bool? signins,
    bool? signouts,
    bool? updates,
    bool? registrations,
    bool? criticals,
    bool? reminders,
    bool? checklist,
    List<int>? enabledTenants,
    bool clearEnabledTenants = false,
    bool? tasks,
    bool? messages,
    bool? pushEnabled,
    bool? pushAndTelegram,
    bool? duties,
    bool? liveActivity,
  }) =>
      NotificationConfig(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        enabled: enabled ?? this.enabled,
        telegramChatId: clearTelegramChatId ? null : (telegramChatId ?? this.telegramChatId),
        birthdays: birthdays ?? this.birthdays,
        signins: signins ?? this.signins,
        signouts: signouts ?? this.signouts,
        updates: updates ?? this.updates,
        registrations: registrations ?? this.registrations,
        criticals: criticals ?? this.criticals,
        reminders: reminders ?? this.reminders,
        checklist: checklist ?? this.checklist,
        enabledTenants: clearEnabledTenants ? null : (enabledTenants ?? this.enabledTenants),
        tasks: tasks ?? this.tasks,
        messages: messages ?? this.messages,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        pushAndTelegram: pushAndTelegram ?? this.pushAndTelegram,
        duties: duties ?? this.duties,
        liveActivity: liveActivity ?? this.liveActivity,
      );

  /// Ionic isTenantEnabled: empty / missing list means no tenant enabled.
  bool isTenantEnabled(int tenantId) =>
      enabledTenants?.contains(tenantId) ?? false;

  /// Ionic toggleTenant: add or remove the tenant from enabled_tenants.
  NotificationConfig toggleTenant(int tenantId) {
    final current = List<int>.of(enabledTenants ?? const []);
    if (current.contains(tenantId)) {
      current.remove(tenantId);
    } else {
      current.add(tenantId);
    }
    return copyWith(enabledTenants: current);
  }

  bool get isConnected => telegramChatId != null && telegramChatId!.isNotEmpty;
}

/// Service for Telegram notifications
class TelegramService {
  final SupabaseClient _supabase;

  TelegramService(this._supabase);

  static const String botUsername = 'attendix_bot';

  /// Get the Telegram bot link for connecting
  String getBotLink(String userId) {
    return 'https://t.me/$botUsername?start=$userId';
  }

  /// Get notification config for user
  Future<NotificationConfig> getNotificationConfig(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      // Create default config
      final newConfig = NotificationConfig(
        id: userId,
        createdAt: DateTime.now(),
        telegramChatId: '',
      );

      await _supabase.from('notifications').insert({
        ...newConfig.toJson(),
        'created_at': newConfig.createdAt!.toIso8601String(),
      });
      return newConfig;
    }

    return NotificationConfig.fromJson(response);
  }

  /// Update notification config
  Future<void> updateNotificationConfig(NotificationConfig config) async {
    await _supabase
        .from('notifications')
        .update(config.toJson())
        .eq('id', config.id);
  }

  /// Disconnect Telegram
  Future<void> disconnectTelegram(String configId) async {
    await _supabase
        .from('notifications')
        .update({'telegram_chat_id': ''})
        .eq('id', configId);
  }

  /// Notify via Telegram (sign in/out, etc.)
  Future<void> notifyPerTelegram({
    required String attId,
    String type = 'signin',
    String? reason,
    bool isParents = false,
    String notes = '',
  }) async {
    await _supabase.functions.invoke('quick-processor', body: {
      'attId': attId,
      'type': type,
      'reason': reason,
      'isParents': isParents,
      'notes': notes,
    });
  }

  /// LOGIC_SELF: Ionic TelegramService.notifyPlayerPaused — tells the
  /// leaders that a member paused themselves.
  Future<void> notifyPlayerPaused({
    required int playerId,
    required int tenantId,
    required String reason,
    String? pauseUntil,
  }) async {
    await _supabase.functions.invoke('quick-processor', body: {
      'type': 'playerPaused',
      'playerId': playerId,
      'tenantId': tenantId,
      'reason': reason,
      if (pauseUntil != null) 'pauseUntil': pauseUntil,
    });
  }

  /// Send plan as PDF or image via Telegram
  Future<void> sendPlanPerTelegram({
    required Uint8List fileBytes,
    required String name,
    required String chatId,
    bool asImage = false,
  }) async {
    final extension = asImage ? '.png' : '.pdf';
    final fileName = '${name}_${DateTime.now().millisecondsSinceEpoch}$extension';

    // Upload to storage
    await _supabase.storage.from('attendances').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: FileOptions(
            contentType: asImage ? 'image/png' : 'application/pdf',
          ),
        );

    // Get public URL
    final url = _supabase.storage.from('attendances').getPublicUrl(fileName);

    // Send via Telegram
    final functionName = asImage ? 'send-photo' : 'send-document';
    await _supabase.functions.invoke(functionName, body: {
      'url': url,
      'chat_id': chatId,
    });

    // Clean up after delay
    Future.delayed(const Duration(seconds: 10), () async {
      await _supabase.storage.from('attendances').remove([fileName]);
    });
  }

  /// Send document/song via Telegram
  Future<void> sendDocumentPerTelegram({
    required String url,
    required String chatId,
  }) async {
    await _supabase.functions.invoke('send-document', body: {
      'url': url,
      'sendAsUrl': !url.contains('.pdf'),
      'chat_id': chatId,
    });
  }
}

/// Provider for TelegramService
final telegramServiceProvider = Provider<TelegramService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TelegramService(supabase);
});

/// Provider for notification config
final notificationConfigProvider = FutureProvider<NotificationConfig?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final user = supabase.auth.currentUser;

  if (user == null) return null;

  final telegramService = ref.watch(telegramServiceProvider);
  return telegramService.getNotificationConfig(user.id);
});
