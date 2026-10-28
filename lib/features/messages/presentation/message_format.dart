import 'package:intl/intl.dart';

import '../../../data/models/message/message.dart';
import '../../../l10n/l10n.dart';

/// Text helpers for Mitteilungen (texts from Ionic i18n `messages.*`).
/// Follow the active UI language via [l10nWithoutContext].
class MessageFormat {
  MessageFormat._();

  static String date(DateTime? d) => d == null ? '' : DateFormat(dateFmt()).format(d.toLocal());

  static String dateTime(DateTime? d) =>
      d == null ? '' : DateFormat('${dateFmt()}, HH:mm').format(d.toLocal());

  /// Time for chips: "HH:mm" today, otherwise "dd.MM. HH:mm".
  static String chipTime(DateTime d, {DateTime? now}) {
    final local = d.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    final sameDay = local.year == n.year && local.month == n.month && local.day == n.day;
    final hm = DateFormat('HH:mm').format(local);
    return sameDay ? hm : '${DateFormat(dateFmt(DateFmtKind.dayMonth)).format(local)} $hm';
  }

  /// "# Person" / "# Personen"
  static String persons(int count) => l10nWithoutContext.commonPersons(count);

  static String toPeople(int count) => l10nWithoutContext.messagesToPeople(count);

  static String problems(int count) => l10nWithoutContext.messagesFlutterProblems(count);
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
  final l10n = l10nWithoutContext;
  final unreachable = r.isUnreachable;
  if (unreachable && r.readAt == null) {
    return [
      RecipientChip(
        r.userId != null ? l10n.messagesUnreachable : l10n.messagesNoAccountNoEmail,
        ChipTone.warn,
      ),
    ];
  }
  final chips = <RecipientChip>[];
  chips.add(
    r.readAt != null
        ? RecipientChip(
            l10n.messagesReadAt(MessageFormat.chipTime(r.readAt!, now: now)),
            ChipTone.ok,
          )
        : RecipientChip(l10n.messagesUnread, ChipTone.neutral),
  );

  if (r.userId == null) {
    chips.add(RecipientChip(l10n.messagesNoAccount, ChipTone.neutral));
  } else if (r.pushSentAt != null) {
    chips.add(RecipientChip(l10n.messagesPush, ChipTone.ok));
  } else if (!r.pushEnabled) {
    chips.add(RecipientChip(l10n.messagesPushOff, ChipTone.neutral));
  } else if (r.pushFailed) {
    chips.add(RecipientChip(l10n.messagesPushFailed, ChipTone.bad));
  }
  if (r.telegramSentAt != null) {
    chips.add(RecipientChip(l10n.messagesTelegram, ChipTone.ok));
  }

  if (r.email == null) {
    chips.add(RecipientChip(l10n.messagesNoEmail, ChipTone.neutral));
  } else if (r.emailBouncedAt != null) {
    chips.add(RecipientChip(l10n.messagesEmailBounced, ChipTone.bad));
  } else if (r.emailFailed) {
    chips.add(RecipientChip(l10n.messagesEmailFailed, ChipTone.bad));
  } else if (r.emailOpenedAt != null) {
    chips.add(
      RecipientChip(
        l10n.messagesEmailOpened(MessageFormat.chipTime(r.emailOpenedAt!, now: now)),
        ChipTone.ok,
      ),
    );
  } else if (r.emailDeliveredAt != null) {
    chips.add(RecipientChip(l10n.messagesEmailDeliveredChip, ChipTone.ok));
  } else if (r.emailSentAt != null) {
    chips.add(RecipientChip(l10n.messagesEmailSent, ChipTone.neutral));
  } else {
    chips.add(RecipientChip(l10n.messagesEmailPending, ChipTone.neutral));
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
