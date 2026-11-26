import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/person/person.dart';
import '../../l10n/l10n.dart';
import '../../l10n/languages.dart';
import '../../shared/widgets/adaptive/adaptive.dart';

/// Toggle for showing all history entries instead of only the current season.
final showAllHistoryProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Entries of `personHistoryProvider` from [seasonStart] on (all with
/// [showAll] or without a season start; entries without a date stay).
List<Map<String, dynamic>> filterHistoryBySeason(
  List<Map<String, dynamic>> history,
  DateTime? seasonStart, {
  required bool showAll,
}) {
  if (seasonStart == null || showAll) return history;
  return history.where((item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    return date == null || !date.isBefore(seasonStart);
  }).toList();
}

/// The person's history as JSON without the entry [item] of
/// `personHistoryProvider` (matched by date, type and text).
List<Map<String, dynamic>> historyWithoutEntry(
  List<PlayerHistoryEntry> history,
  Map<String, dynamic> item,
) {
  final itemDate = item['date']?.toString();
  final itemType = item['type'] as int?;
  final itemText = item['text']?.toString() ?? '';
  return history
      .where((h) => !(h.date == itemDate && h.type == itemType && (h.text ?? '') == itemText))
      .map((h) => h.toJson())
      .toList();
}

/// Ionic onHisItemClicked for NOTES entries.
Future<void> showOldHistoryNote(BuildContext context, DateTime date, String note) {
  return showAppDialog<void>(
    context: context,
    builder: (ctx) => AppAlertDialog(
      title: Text(context.l10n.personNoteChanged),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat(dateFmt()).format(date),
            style: Theme.of(ctx).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(context.l10n.personOldNote(note)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.commonOk),
        ),
      ],
    ),
  );
}

/// Title of a player history entry (Ionic person.page.html history section).
String historyEntryTitle(int? type, DateTime date) {
  final l10n = l10nWithoutContext;
  final d = DateFormat(dateFmt()).format(date);
  final dt = DateFormat('${dateFmt()} HH:mm').format(date);
  return switch (type) {
    2 || 3 => l10n.personTalkedToAt(dt),
    5 => l10n.personNoteChangedAt(dt),
    1 => l10n.personPausedAt(dt),
    6 => l10n.personActiveSince(dt),
    8 => l10n.personArchivedAt(d),
    9 => l10n.personReactivatedAt(d),
    10 || 11 => l10n.personTransferredAt(d),
    12 || 13 => l10n.personCopiedAt(d),
    7 => d,
    // Ionic: no <h2> for the other types (e.g. 14 genehmigt, 15 abgelehnt).
    _ => '',
  };
}

/// Body text of a player history entry (Ionic getPlayerHistoryTypeText).
String historyEntryBody(int? type, String text) {
  switch (type) {
    case 4:
    case 6:
    case 9:
      return '';
    case 5: // Ionic: <h3>{{ att.text }}</h3> (old note, details on tap)
    case 8:
    case 10:
    case 11:
    case 12:
    case 13:
      return text;
  }
  final l10n = l10nWithoutContext;
  final typeText = switch (type) {
    1 => l10n.commonHistoryPaused,
    2 => l10n.commonHistoryUnexcused,
    3 => '',
    7 => l10n.commonHistoryGroupChange,
    _ => l10n.commonOther,
  };
  final body = text.isNotEmpty ? text : l10n.personNoComment;
  return typeText.isEmpty ? body : '$typeText: $body';
}
