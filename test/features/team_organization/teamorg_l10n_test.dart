import 'dart:io';

import 'package:attendix/data/models/message/message.dart';
import 'package:attendix/data/models/team_org/team_org.dart';
import 'package:attendix/features/messages/presentation/message_format.dart';
import 'package:attendix/features/team_organization/team_org_utils.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

/// WAVE 5 i18n: Teamorganisation + Mitteilungen follow the active language,
/// German output stays as before.
void main() {
  tearDown(() => setActiveLanguage('de'));

  test('German stays the default', () {
    expect(priorityLabels['high'], 'Hoch');
    expect(taskStatusLabels['in_progress'], 'In Arbeit');
    expect(outcomeLabels['postponed'], 'Vertagt');
    expect(monthLabel(DateTime(2026, 3)), 'März 2026');
    expect(joinNames(['Anna', 'Jonas', 'Paul']), 'Anna, Jonas und Paul');
    expect(MessageFormat.problems(2), '2 Probleme');
    expect(MessageFormat.toPeople(1), 'an 1 Person');
    expect(
      formatTaskDue(const TeamTask(title: 't', dueDate: '2026-10-28'), '2026-10-28'),
      'Heute',
    );
  });

  test('English when the UI language is English', () {
    setActiveLanguage('en');
    expect(priorityLabels['high'], 'High');
    expect(monthLabel(DateTime(2026, 3)), 'March 2026');
    expect(weekdayShort(DateTime(2026, 10, 26)), 'Mo');
    expect(joinNames(['Anna', 'Jonas']), 'Anna and Jonas');
    expect(MessageFormat.problems(1), '1 problem');
    expect(
      recipientChips(const MessageRecipient(id: 'r', messageId: 'm', userId: 'u', pushEnabled: false))
          .first
          .text,
      isNot(contains('Gelesen')),
    );
  });

  test('lane sources contain no hard-coded German UI texts', () {
    // Quick guard for the most common words; data/format strings are allowed.
    final words = RegExp(r"Text\('(Speichern|Abbrechen|Löschen|Aufgabe|Thema|Protokoll|Mitteilung)");
    for (final path in [
      'lib/features/team_organization/presentation/pages/protocol_page.dart',
      'lib/features/team_organization/presentation/widgets/topics_tab.dart',
      'lib/features/messages/presentation/pages/message_compose_page.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(words.hasMatch(src), isFalse, reason: path);
    }
  });
}
