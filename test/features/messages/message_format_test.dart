import 'package:attendix/data/models/message/message.dart';
import 'package:attendix/data/models/user_notification/user_notification.dart';
import 'package:attendix/features/messages/presentation/message_format.dart';
import 'package:flutter_test/flutter_test.dart';

MessageRecipient _r({
  String? userId = 'u1',
  String? email = 'a@b.de',
  bool pushEnabled = true,
  DateTime? readAt,
  DateTime? pushSentAt,
  bool pushFailed = false,
  bool emailFailed = false,
  DateTime? emailOpenedAt,
  DateTime? emailDeliveredAt,
}) =>
    MessageRecipient(
      id: 'r',
      messageId: 'm',
      userId: userId,
      email: email,
      pushEnabled: pushEnabled,
      readAt: readAt,
      pushSentAt: pushSentAt,
      pushFailed: pushFailed,
      emailFailed: emailFailed,
      emailOpenedAt: emailOpenedAt,
      emailDeliveredAt: emailDeliveredAt,
    );

void main() {
  final now = DateTime(2026, 3, 10, 18);

  group('recipientChips', () {
    test('unreachable without account', () {
      expect(
        recipientChips(_r(userId: null, email: null, pushEnabled: false), now: now),
        [const RecipientChip('Kein App-Konto, keine E-Mail', ChipTone.warn)],
      );
    });

    test('unreachable with account', () {
      expect(
        recipientChips(_r(email: null, pushEnabled: false), now: now),
        [const RecipientChip('Nicht erreichbar', ChipTone.warn)],
      );
    });

    test('read today + push + email delivered', () {
      final chips = recipientChips(
        _r(
          readAt: DateTime(2026, 3, 10, 9, 5),
          pushSentAt: DateTime(2026, 3, 10, 9),
          emailDeliveredAt: DateTime(2026, 3, 10, 9),
        ),
        now: now,
      );
      expect(chips, [
        const RecipientChip('✓ Gelesen 09:05', ChipTone.ok),
        const RecipientChip('Push', ChipTone.ok),
        const RecipientChip('E-Mail zugestellt', ChipTone.ok),
      ]);
    });

    test('push failed + email pending', () {
      final chips = recipientChips(_r(pushFailed: true), now: now);
      expect(chips, [
        const RecipientChip('Ungelesen', ChipTone.neutral),
        const RecipientChip('Push fehlgeschlagen', ChipTone.bad),
        const RecipientChip('E-Mail ausstehend', ChipTone.neutral),
      ]);
    });
  });

  test('RecipientOverview aggregates counters', () {
    final o = RecipientOverview.from([
      _r(readAt: now, pushSentAt: now),
      _r(emailOpenedAt: now, emailDeliveredAt: now),
      _r(email: null, pushEnabled: false),
    ]);
    expect(o.total, 3);
    expect(o.read, 1);
    expect(o.readAny, 2);
    expect(o.open, 1);
    expect(o.problems, 1);
    expect(o.pushTotal, 2);
    expect(o.pushDelivered, 1);
    expect(o.emailTotal, 2);
    expect(o.emailDelivered, 1);
    expect(o.emailOpened, 1);
  });

  test('persons plural', () {
    expect(MessageFormat.persons(1), '1 Person');
    expect(MessageFormat.persons(3), '3 Personen');
  });

  group('UserNotification JSON', () {
    test('parses row and message target', () {
      final n = UserNotification.fromJson({
        'id': 'x',
        'user_id': 'u',
        'tenantId': 4,
        'type': 'message',
        'title': 'T',
        'body': 'B',
        'channels': ['push'],
        'data': {'messageId': 'abc', 'tenantId': '7'},
        'read': false,
        'created_at': '2026-03-10T10:00:00Z',
      });
      expect(n.messageId, 'abc');
      expect(n.targetTenantId, 7);
      expect(n.isNavigable, isTrue);
    });

    test('criticals entry is not navigable', () {
      final n = UserNotification.fromJson({
        'id': 'x',
        'tenantId': 4,
        'type': 'criticals',
        'data': <String, dynamic>{},
      });
      expect(n.isNavigable, isFalse);
      expect(n.targetTenantId, 4);
    });
  });

  test('Message JSON parses list columns', () {
    final m = Message.fromJson({
      'id': 'm1',
      'tenantId': 1,
      'title': 'Probe',
      'channels': ['push', 'email'],
      'group_ids': null,
      'recipient_count': 12,
      'status': 'sending',
      'created_at': '2026-03-10T10:00:00Z',
    });
    expect(m.isSending, isTrue);
    expect(m.recipientCount, 12);
    expect(const MessageWithStats(message: Message(id: 'a', tenantId: 1, recipientCount: 4), stats: MessageStats(read: 1)).readPercent, 25);
    expect(m.channels, ['push', 'email']);
  });
}
