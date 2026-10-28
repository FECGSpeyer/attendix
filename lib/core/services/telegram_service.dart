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

  /// DUTY: Dienste (Einteilung, Erinnerung, unterbesetzt); null counts as on
  final bool? duties;

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
    this.duties,
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
        enabledTenants: (json['enabled_tenants'] as List?)?.cast<int>(),
        duties: json['duties'] as bool?,
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
        'duties': duties,
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
    bool? duties,
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
        duties: duties ?? this.duties,
      );

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
      );

      await _supabase.from('notifications').insert(newConfig.toJson());
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
