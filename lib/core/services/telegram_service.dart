import 'dart:math';
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
    final fileName = encodeFilename(name, extension);

    // Upload to storage (Ionic: `upsert: true`)
    await _supabase.storage.from('attendances').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: asImage ? 'image/png' : 'application/pdf',
          ),
        );

    // Get public URL
    // Ionic 4.17.6: `?download=` so Telegram shows the readable name
    // (without the random collision suffix of the storage key).
    final url = downloadUrl(
      _supabase.storage.from('attendances').getPublicUrl(fileName),
      name,
      extension,
    );

    // Send via Telegram
    final functionName = asImage ? 'send-photo' : 'send-document';
    try {
      await _supabase.functions.invoke(functionName, body: {
        'url': url,
        'chat_id': chatId,
      });
    } finally {
      // Clean up after delay (Ionic: also when sending failed)
      Future.delayed(const Duration(seconds: 10), () async {
        try {
          await _supabase.storage.from('attendances').remove([fileName]);
        } catch (_) {}
      });
    }
  }

  /// Ionic `encodeFilename`: NFD + strip combining marks, every char outside
  /// `[A-Za-z0-9_\s-]` becomes `-`, collapse whitespace / dashes, trim dashes,
  /// then `_<100-999><extension>`.
  static String encodeFilename(String name, String extension, {Random? random}) {
    final sanitized = cleanName(name);
    final randomNumber = 100 + (random ?? Random()).nextInt(900);
    return '${sanitized}_$randomNumber$extension';
  }

  /// Ionic 4.17.6 `publicUrl?download=<cleanName + extension>`.
  static String downloadUrl(String publicUrl, String name, String extension) =>
      '$publicUrl?download=${Uri.encodeComponent(cleanName(name) + extension)}';

  /// Ionic `cleanName` / `encodeFilename` sanitising (without the suffix);
  /// empty results become `file`.
  static String cleanName(String name) {
    final buffer = StringBuffer();
    for (final rune in name.runes) {
      final char = String.fromCharCode(rune);
      // NFD: decomposable Latin letters lose their diacritic, combining marks vanish.
      if (rune >= 0x0300 && rune <= 0x036f) continue;
      buffer.write(_nfdBase[char] ?? char);
    }
    final sanitized = buffer
        .toString()
        .replaceAll(RegExp(r'[^A-Za-z0-9_\s-]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .trim();
    return sanitized.isEmpty ? 'file' : sanitized;
  }

  /// Base letters of the precomposed Latin letters that NFD decomposes
  /// (Latin-1 Supplement + Latin Extended-A). `ß`, `æ`, `ø`, `đ`, `ł` … have
  /// no decomposition and therefore stay (and become `-`), like in Ionic.
  static final Map<String, String> _nfdBase = () {
    const groups = {
      'A': 'ÀÁÂÃÄÅĀĂĄ', 'a': 'àáâãäåāăą', 'C': 'ÇĆĈĊČ', 'c': 'çćĉċč', 'D': 'Ď', 'd': 'ď',
      'E': 'ÈÉÊËĒĔĖĘĚ', 'e': 'èéêëēĕėęě', 'G': 'ĜĞĠĢ', 'g': 'ĝğġģ', 'H': 'Ĥ', 'h': 'ĥ',
      'I': 'ÌÍÎÏĨĪĬĮİ', 'i': 'ìíîïĩīĭį', 'J': 'Ĵ', 'j': 'ĵ', 'K': 'Ķ', 'k': 'ķ',
      'L': 'ĹĻĽ', 'l': 'ĺļľ', 'N': 'ÑŃŅŇ', 'n': 'ñńņň', 'O': 'ÒÓÔÕÖŌŎŐ', 'o': 'òóôõöōŏő',
      'R': 'ŔŖŘ', 'r': 'ŕŗř', 'S': 'ŚŜŞŠ', 's': 'śŝşš', 'T': 'ŢŤ', 't': 'ţť',
      'U': 'ÙÚÛÜŨŪŬŮŰŲ', 'u': 'ùúûüũūŭůűų', 'W': 'Ŵ', 'w': 'ŵ', 'Y': 'ÝŶŸ', 'y': 'ýÿŷ',
      'Z': 'ŹŻŽ', 'z': 'źżž',
    };
    return {
      for (final e in groups.entries)
        for (final ch in e.value.split('')) ch: e.key,
    };
  }();

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
  // SOL_FIX14: per-user data – reload when the account changes.
  final userId = ref.watch(currentAuthUserIdProvider);

  if (userId == null) return null;

  final telegramService = ref.watch(telegramServiceProvider);
  return telegramService.getNotificationConfig(userId);
});
