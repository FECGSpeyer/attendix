import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/auto_message/auto_message.dart';
import '../../data/repositories/auto_message_repository.dart';
import '../config/supabase_config.dart';
import 'attendance_type_providers.dart';
import 'tenant_providers.dart';

// ---------------------------------------------------------------------------
// Automatische Nachrichten (Ionic 4.18)
// ---------------------------------------------------------------------------

/// AutoMessage repository with tenant context
final autoMessageRepositoryWithTenantProvider = Provider<AutoMessageRepository>((ref) {
  final tenant = ref.watch(currentTenantIdProvider);
  return ref.watch(autoMessageRepositoryForTenantProvider(tenant));
});

/// TENANT_BIND: one immutable repository per tenant and account (see
/// `messageRepositoryForTenantProvider`).
final autoMessageRepositoryForTenantProvider = Provider.family<AutoMessageRepository, int?>((
  ref,
  tenantId,
) {
  final userId = ref.watch(currentAuthUserIdProvider);
  return ref.watch(_autoMessageRepositoryForAccountProvider((tenantId: tenantId, userId: userId)));
});

final _autoMessageRepositoryForAccountProvider =
    Provider.family<AutoMessageRepository, AccountScopeKey>((ref, key) {
      final repo = AutoMessageRepository(ref);
      if (key.tenantId != null) repo.bindTenantId(key.tenantId!);
      return repo;
    });

/// All rules of the current tenant (admins/responsibles; RLS).
final autoMessageRulesProvider = FutureProvider.autoDispose<List<AutoMessageRule>>((ref) async {
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return [];
  return repo.getRules();
});

/// Number of switched-on rules (Mitteilungen entry), null on error.
final activeAutoMessageRulesCountProvider = FutureProvider.autoDispose<int?>((ref) async {
  try {
    final rules = await ref.watch(autoMessageRulesProvider.future);
    return rules.where((r) => r.enabled).length;
  } catch (_) {
    return null; // non-critical (table may be missing on old DBs)
  }
});

/// People written to in the last 7 days ("Letzte 7 Tage: …").
final autoMessageLastWeekProvider = FutureProvider.autoDispose<({int sent, int people})>((
  ref,
) async {
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return (sent: 0, people: 0);
  final runs =
      (await repo.getRecentRuns(
        DateTime.now().subtract(const Duration(days: 7)),
      )).where((r) => r.status == 'sent').toList();
  return (sent: runs.length, people: runs.fold<int>(0, (s, r) => s + r.recipientCount));
});

/// One rule by id (null when not found / other tenant).
final autoMessageRuleByIdProvider = FutureProvider.autoDispose.family<AutoMessageRule?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  return repo.getRule(id);
});

/// Ionic 4.18 columns of a message; null when missing (old database) or
/// not visible.
final messageAutoInfoProvider = FutureProvider.autoDispose.family<MessageAutoInfo?, String>((
  ref,
  messageId,
) async {
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  try {
    return await repo.getMessageAutoInfo(messageId);
  } catch (_) {
    return null;
  }
});

/// The current user's own recipient row of a message (Termin row, language,
/// placeholder values); null for admins without a copy / old databases.
final ownRecipientAutoInfoProvider = FutureProvider.autoDispose.family<RecipientAutoInfo?, String>((
  ref,
  messageId,
) async {
  ref.watch(currentAuthUserIdProvider);
  final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
  if (!repo.hasTenantId) return null;
  try {
    return await repo.getOwnRecipientAutoInfo(messageId);
  } catch (_) {
    return null;
  }
});

/// One row of a rule's history (Verlauf).
class AutoMessageHistoryRow {
  const AutoMessageHistoryRow({
    required this.run,
    required this.title,
    required this.date,
    this.read = 0,
    this.responses = 0,
  });

  final AutoMessageRun run;
  final String title;

  /// Termin date (YYYY-MM-DD) or the run timestamp.
  final String date;
  final int read;
  final int responses;
}

/// History of a rule: runs with Termin, read count and answers (Ionic loadHistory).
final autoMessageHistoryProvider = FutureProvider.autoDispose
    .family<List<AutoMessageHistoryRow>, String>((ref, ruleId) async {
      final repo = ref.watch(autoMessageRepositoryWithTenantProvider);
      if (!repo.hasTenantId) return [];
      final runs = await repo.getRuns(ruleId);
      final atts = await repo.getAttendanceInfo(runs.map((r) => r.attendanceId).toSet().toList());
      final messageIds = runs.map((r) => r.messageId).whereType<String>().toList();
      final recipients = await repo.getRecipientsOf(messageIds);
      final responses = await repo.getResponsesForMessages(messageIds);
      final typeNames = {
        for (final t in await ref.watch(attendanceTypesProvider.future)) t.id: t.name,
      };
      return [
        for (final run in runs)
          () {
            final att = atts.where((a) => a.id == run.attendanceId).firstOrNull;
            final mine = recipients.where((r) => r.messageId == run.messageId);
            return AutoMessageHistoryRow(
              run: run,
              title:
                  (att?.typeInfo?.isNotEmpty ?? false)
                      ? att!.typeInfo!
                      : (typeNames[att?.typeId] ?? ''),
              date: att?.date ?? run.createdAt?.toIso8601String() ?? '',
              read: mine.where((r) => r.readAt != null || r.emailOpenedAt != null).length,
              responses: responses.where((x) => x.messageId == run.messageId).length,
            );
          }(),
      ];
    });
