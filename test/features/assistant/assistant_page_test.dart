import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/assistant_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/features/assistant/data/assistant_command.dart';
import 'package:attendix/features/assistant/data/assistant_reply.dart';
import 'package:attendix/features/assistant/presentation/pages/assistant_page.dart';
import 'package:attendix/features/assistant/presentation/widgets/assistant_entry_card.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChat extends AssistantChatNotifier {
  _FakeChat(this.initial);
  final AssistantChatState initial;
  final sent = <String>[];

  @override
  AssistantChatState build() => initial;

  @override
  Future<void> send(String text) async => sent.add(text);
}

Widget _app(Widget home, {required bool enabled, Role role = Role.admin, AssistantChatState? chat, _FakeChat? fake}) =>
    ProviderScope(
      overrides: [
        assistantEnabledProvider.overrideWithValue(enabled),
        currentRoleProvider.overrideWithValue(role),
        redesignEnabledProvider.overrideWithValue(false),
        assistantChatNotifierProvider.overrideWith(() => fake ?? _FakeChat(chat ?? const AssistantChatState())),
      ],
      child: MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );

void main() {
  group('AssistantEntryCard', () {
    testWidgets('members see it only when switched on', (tester) async {
      await tester.pumpWidget(_app(const AssistantEntryCard(), enabled: false, role: Role.player));
      expect(find.text('Frag den Assistenten'), findsNothing);
      await tester.pumpWidget(_app(const AssistantEntryCard(), enabled: true, role: Role.player));
      expect(find.text('Frag den Assistenten'), findsOneWidget);
    });

    testWidgets('admins see the hint to switch it on', (tester) async {
      await tester.pumpWidget(_app(const AssistantEntryCard(), enabled: false));
      expect(find.text('Frag den Assistenten'), findsOneWidget);
      expect(find.textContaining('noch aus'), findsOneWidget);
    });
  });

  group('AssistantPage', () {
    testWidgets('suggestions send the question', (tester) async {
      final fake = _FakeChat(const AssistantChatState());
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, fake: fake));
      await tester.tap(find.text('Wann ist der nächste Termin?'));
      expect(fake.sent, ['Wann ist der nächste Termin?']);
    });

    testWidgets('members get no suggestions about others', (tester) async {
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, role: Role.player));
      expect(find.text('Wer kommt zum nächsten Termin?'), findsNothing);
      expect(find.text('Wie war meine Anwesenheit in den letzten 3 Monaten?'), findsOneWidget);
    });

    testWidgets('switched off: input locked, hint shown', (tester) async {
      await tester.pumpWidget(_app(const AssistantPage(), enabled: false));
      expect(find.textContaining('ausgeschaltet'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('answers are cards filled by the app', (tester) async {
      final chat = AssistantChatState(messages: [
        const AssistantMessage.user('Wie war Jonas in den letzten 3 Monaten?'),
        AssistantMessage.assistant(RateReply(
          subjectName: 'Jonas Müller',
          isMe: false,
          range: (from: DateTime(2026, 8, 11), to: DateTime(2026, 11, 11)),
          rate: (attended: 9, total: 12, percent: 75),
          personId: 4,
        )),
        const AssistantMessage.assistant(ChoiceReply(query: 'Jonas', options: [
          (label: 'Jonas Müller · Tenor', command: NextEventCommand()),
          (label: 'Jonas Klein · Bass', command: NextEventCommand()),
        ])),
        const AssistantMessage.assistant(NoticeReply(AssistantNotice.changeLater)),
      ]);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Anwesenheit von Jonas Müller'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('9 von 12 Terminen besucht'), findsOneWidget);
      expect(find.text('Wen meinst du mit „Jonas“?'), findsOneWidget);
      expect(find.text('Jonas Klein · Bass'), findsOneWidget);
      expect(find.textContaining('Ändern kann ich noch nichts'), findsOneWidget);
    });
  });
}
