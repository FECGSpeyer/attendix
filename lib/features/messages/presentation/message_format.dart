import 'package:intl/intl.dart';

import '../../../data/models/message/message.dart';

/// German text helpers for Mitteilungen (texts from Ionic i18n de.json `messages.*`).
class MessageFormat {
  MessageFormat._();

  static String date(DateTime? d) => d == null ? '' : DateFormat('dd.MM.yyyy').format(d.toLocal());

  static String dateTime(DateTime? d) =>
      d == null ? '' : DateFormat('dd.MM.yyyy, HH:mm').format(d.toLocal());

  /// Time for chips: "HH:mm" today, otherwise "dd.MM. HH:mm".
  static String chipTime(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    final sameDay = local.year == n.year && local.month == n.month && local.day == n.day;
    final hm = DateFormat('HH:mm').format(local);
    return sameDay ? hm : '${DateFormat('dd.MM.').format(local)} $hm';
  }

  /// "# Person" / "# Personen"
  static String persons(int count) => count == 1 ? '1 Person' : '$count Personen';

  static String toPeople(int count) => 'an ${persons(count)}';

  static String problems(int count) => count == 1 ? '1 Problem' : '$count Probleme';
}

/// Tone of a recipient status chip.
enum ChipTone { ok, bad, warn, neutral }

class RecipientChip {
  const RecipientChip(this.text, this.tone);

  final String text;
  final ChipTone tone;

  @override
  bool operator ==(Object other) =>
      other is RecipientChip && other.text == text && other.tone == tone;

  @override
  int get hashCode => Object.hash(text, tone);

  @override
  String toString() => 'RecipientChip($text, $tone)';
}

/// Delivery/read chips of one recipient (port of Ionic `chipsFor`).
List<RecipientChip> recipientChips(MessageRecipient r, {DateTime? now}) {
  final unreachable = r.isUnreachable;
  if (unreachable && r.readAt == null) {
    return [
      RecipientChip(
        r.userId != null ? 'Nicht erreichbar' : 'Kein App-Konto, keine E-Mail',
        ChipTone.warn,
      ),
    ];
  }
  final chips = <RecipientChip>[];
  chips.add(
    r.readAt != null
        ? RecipientChip('✓ Gelesen ${MessageFormat.chipTime(r.readAt!, now: now)}', ChipTone.ok)
        : const RecipientChip('Ungelesen', ChipTone.neutral),
  );

  if (r.userId == null) {
    chips.add(const RecipientChip('Kein App-Konto', ChipTone.neutral));
  } else if (r.pushSentAt != null) {
    chips.add(const RecipientChip('Push', ChipTone.ok));
  } else if (!r.pushEnabled) {
    chips.add(const RecipientChip('Push aus', ChipTone.neutral));
  } else if (r.pushFailed) {
    chips.add(const RecipientChip('Push fehlgeschlagen', ChipTone.bad));
  }
  if (r.telegramSentAt != null) {
    chips.add(const RecipientChip('Telegram', ChipTone.ok));
  }

  if (r.email == null) {
    chips.add(const RecipientChip('Keine E-Mail', ChipTone.neutral));
  } else if (r.emailBouncedAt != null) {
    chips.add(const RecipientChip('E-Mail unzustellbar', ChipTone.bad));
  } else if (r.emailFailed) {
    chips.add(const RecipientChip('E-Mail fehlgeschlagen', ChipTone.bad));
  } else if (r.emailOpenedAt != null) {
    chips.add(
      RecipientChip(
        'E-Mail geöffnet ${MessageFormat.chipTime(r.emailOpenedAt!, now: now)}',
        ChipTone.ok,
      ),
    );
  } else if (r.emailDeliveredAt != null) {
    chips.add(const RecipientChip('E-Mail zugestellt', ChipTone.ok));
  } else if (r.emailSentAt != null) {
    chips.add(const RecipientChip('E-Mail gesendet', ChipTone.neutral));
  } else {
    chips.add(const RecipientChip('E-Mail ausstehend', ChipTone.neutral));
  }
  return chips;
}

/// Overview counters of the message detail page (admin view).
class RecipientOverview {
  const RecipientOverview({
    this.read = 0,
    this.total = 0,
    this.pushDelivered = 0,
    this.pushTotal = 0,
    this.emailDelivered = 0,
    this.emailTotal = 0,
    this.emailOpened = 0,
    this.readAny = 0,
    this.open = 0,
    this.problems = 0,
  });

  factory RecipientOverview.from(List<MessageRecipient> rows) {
    var read = 0, pushDelivered = 0, pushTotal = 0, emailDelivered = 0;
    var emailTotal = 0, emailOpened = 0, readAny = 0, open = 0, problems = 0;
    for (final r in rows) {
      if (r.readAt != null) read++;
      if (r.pushEnabled) pushTotal++;
      if (r.pushSentAt != null || r.telegramSentAt != null) pushDelivered++;
      if (r.email != null) emailTotal++;
      if (r.emailDeliveredAt != null) emailDelivered++;
      if (r.emailOpenedAt != null) emailOpened++;
      if (r.isRead) {
        readAny++;
      } else {
        open++;
      }
      if (r.hasProblem) problems++;
    }
    return RecipientOverview(
      read: read,
      total: rows.length,
      pushDelivered: pushDelivered,
      pushTotal: pushTotal,
      emailDelivered: emailDelivered,
      emailTotal: emailTotal,
      emailOpened: emailOpened,
      readAny: readAny,
      open: open,
      problems: problems,
    );
  }

  final int read;
  final int total;
  final int pushDelivered;
  final int pushTotal;
  final int emailDelivered;
  final int emailTotal;
  final int emailOpened;
  final int readAny;
  final int open;
  final int problems;
}
