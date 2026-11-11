import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/assistant_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/assistant/data/assistant_command.dart';
import 'package:attendix/features/assistant/data/assistant_reply.dart';
import 'package:attendix/features/assistant/presentation/pages/assistant_page.dart';
import 'package:attendix/features/assistant/presentation/widgets/assistant_entry_card.dart';
import 'package:attendix/features/attendance/presentation/widgets/songs_selection_sheet.dart';
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

/// Tall window so every chat card is built (the list is lazy).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

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
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Anwesenheit von Jonas Müller'), findsOneWidget);
      expect(find.text('75 %'), findsOneWidget);
      expect(find.text('9 von 12 Terminen besucht'), findsOneWidget);
      expect(find.text('Wen meinst du mit „Jonas“?'), findsOneWidget);
      expect(find.text('Jonas Klein · Bass'), findsOneWidget);
      expect(find.textContaining('Das kann ich noch nicht ändern'), findsOneWidget);
    });
  });

  group('changes (package 2)', () {
    StatusPlan plan(int n, {bool self = true}) => StatusPlan(
          self: self,
          status: AttendanceStatus.excused,
          reason: 'Krank',
          changes: [
            for (var i = 0; i < n; i++)
              StatusChange(
                personAttendanceId: 'pa$i',
                attendanceId: i,
                personName: 'Jonas Müller',
                title: 'Probe $i',
                date: DateTime(2026, 11, 15 + i),
                oldStatus: AttendanceStatus.neutral,
                oldNotes: null,
                newStatus: AttendanceStatus.excused,
              ),
          ],
          skippedLocked: 1,
        );

    testWidgets('a preview shows what changes and saves nothing by itself', (tester) async {
      final chat = AssistantChatState(messages: [AssistantMessage.assistant(StatusPreviewReply(plan(2)))]);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Soll ich das so eintragen?'), findsOneWidget);
      expect(find.text('Neu: Entschuldigt'), findsOneWidget);
      expect(find.text('Grund: Krank'), findsOneWidget);
      expect(find.text('Probe 0'), findsOneWidget);
      expect(find.textContaining('1 Termin bleibt'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
    });

    testWidgets('many rows: list is cut, leaders see names', (tester) async {
      final chat = AssistantChatState(messages: [AssistantMessage.assistant(StatusPreviewReply(plan(12, self: false)))]);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Status ändern'), findsOneWidget);
      expect(find.text('Jonas Müller · Probe 0'), findsOneWidget);
      expect(find.text('und 4 weitere'), findsOneWidget);
    });

    testWidgets('saved change offers undo once', (tester) async {
      final chat = AssistantChatState(messages: [
        AssistantMessage.assistant(StatusPreviewReply(plan(1), state: ActionState.done)),
        AssistantMessage.assistant(ActionDoneReply(statusPlan: plan(1), count: 1)),
        AssistantMessage.assistant(ActionDoneReply(statusPlan: plan(1), count: 1, undo: UndoState.undone)),
      ]);
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat, role: Role.player));
      expect(find.text('Speichern'), findsNothing);
      expect(find.text('1 Änderung gespeichert.'), findsNWidgets(2));
      expect(find.text('Rückgängig'), findsOneWidget);
      expect(find.text('Rückgängig gemacht.'), findsOneWidget);
    });

    test('cancel and the second confirmation never save', () async {
      final container = ProviderContainer(overrides: [
        assistantChatNotifierProvider.overrideWith(() => _Seeded(AssistantChatState(messages: [
              AssistantMessage.assistant(StatusPreviewReply(plan(12, self: false))),
              AssistantMessage.assistant(StatusPreviewReply(plan(1))),
            ]))),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(assistantChatNotifierProvider.notifier);
      // 12 rows: the first tap only asks again.
      await notifier.confirm(0);
      var replies = container.read(assistantChatNotifierProvider).messages.map((m) => m.reply).toList();
      expect((replies[0] as StatusPreviewReply).state, ActionState.confirmAgain);
      expect(replies.length, 2);
      notifier.cancel(0);
      notifier.cancel(1);
      replies = container.read(assistantChatNotifierProvider).messages.map((m) => m.reply).toList();
      expect((replies[0] as StatusPreviewReply).state, ActionState.cancelled);
      expect((replies[1] as StatusPreviewReply).state, ActionState.cancelled);
      // A cancelled preview cannot be saved any more.
      await notifier.confirm(1);
      expect(container.read(assistantChatNotifierProvider).messages.length, 2);
    });
  });

  group('Termine (package 3)', () {
    const probe = AttendanceType(id: 'p', name: 'Probe', startTime: '19:00', endTime: '21:00');

    testWidgets('new Termine: list of days, skipped days, save', (tester) async {
      final chat = AssistantChatState(messages: [
        AssistantMessage.assistant(CreatePreviewReply(CreatePlan(
          type: probe,
          days: [DateTime(2026, 12, 2), DateTime(2026, 12, 9)],
          title: 'Extraprobe',
          place: 'Gemeindehaus',
          skippedExisting: [DateTime(2026, 12, 16)],
        ))),
      ]);
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('2 Termine anlegen?'), findsOneWidget);
      expect(find.text('Probe · Extraprobe'), findsOneWidget);
      expect(find.text('19:00 – 21:00 Uhr'), findsOneWidget);
      expect(find.text('Ort: Gemeindehaus'), findsOneWidget);
      expect(find.textContaining('schon einen Termin dieses Typs'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('move, Werke and cancel previews', (tester) async {
      final chat = AssistantChatState(messages: [
        AssistantMessage.assistant(MovePreviewReply(MovePlan(
          before: const Attendance(id: 7, date: '2026-11-18T11:00:00.000Z', typeId: 'p'),
          title: 'Probe',
          oldDay: DateTime(2026, 11, 18),
          newDay: DateTime(2026, 11, 19),
          oldStart: '19:00',
          newStart: '19:00',
        ))),
        AssistantMessage.assistant(SongsPreviewReply(SongsPlan(
          attendanceId: 7,
          title: 'Probe',
          date: DateTime(2026, 11, 18),
          historyDate: '2026-11-18T11:00:00.000Z',
          before: const [],
          after: const [SongHistoryEntry(songId: 1, songName: 'Großer Gott')],
          added: const ['Großer Gott'],
          removed: const [],
          notFound: const ['Nr. 999'],
        ))),
        AssistantMessage.assistant(StatusPreviewReply(StatusPlan(
          self: false,
          status: AttendanceStatus.excused,
          reason: 'Saal belegt',
          cancelTitle: 'Probe',
          changes: [
            for (var i = 0; i < 3; i++)
              StatusChange(
                personAttendanceId: 'pa$i',
                attendanceId: 7,
                personName: 'P$i',
                title: 'Probe',
                date: DateTime(2026, 11, 18),
                oldStatus: AttendanceStatus.neutral,
                oldNotes: null,
                newStatus: AttendanceStatus.excused,
              ),
          ],
        ))),
      ]);
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Termin verschieben'), findsOneWidget);
      expect(find.textContaining('Bisher:'), findsOneWidget);
      expect(find.textContaining('Neu: Donnerstag'), findsOneWidget);
      expect(find.textContaining('Die Status bleiben'), findsOneWidget);
      expect(find.text('Werke für den Termin'), findsOneWidget);
      expect(find.text('Neu: Großer Gott'), findsOneWidget);
      expect(find.text('Nicht gefunden: Nr. 999'), findsOneWidget);
      expect(find.text('Termin absagen'), findsOneWidget);
      expect(find.text('Grund: Saal belegt'), findsOneWidget);
      expect(find.text('3 Personen werden auf Entschuldigt gesetzt.'), findsOneWidget);
      expect(find.text('Speichern'), findsNWidgets(3));
    });

    testWidgets('created Termine can be undone', (tester) async {
      final chat = AssistantChatState(messages: [
        AssistantMessage.assistant(ActionDoneReply(
          createPlan: CreatePlan(type: probe, days: [DateTime(2026, 12, 2)]),
          createdIds: const [41],
          count: 1,
        )),
      ]);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('1 Termin angelegt.'), findsOneWidget);
      expect(find.textContaining('löscht genau diese neuen Termine'), findsOneWidget);
      expect(find.text('Rückgängig'), findsOneWidget);
    });

    testWidgets('a type question offers the types', (tester) async {
      final chat = AssistantChatState(messages: [
        AssistantMessage.assistant(ChoiceReply(kind: ChoiceKind.type, query: '', options: [
          (label: 'Probe', command: CreateEventsCommand(dates: [DateTime(2026, 12, 2)], typeId: 'p')),
          (label: 'Gottesdienst', command: CreateEventsCommand(dates: [DateTime(2026, 12, 2)], typeId: 'g')),
        ])),
        const AssistantMessage.assistant(NoticeReply(AssistantNotice.cancelNeedsReason)),
      ]);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Welcher Termintyp?'), findsOneWidget);
      expect(find.text('Gottesdienst'), findsOneWidget);
      expect(find.textContaining('nur mit Grund'), findsOneWidget);
    });
  });
}

class _Seeded extends AssistantChatNotifier {
  _Seeded(this.initial);
  final AssistantChatState initial;

  @override
  AssistantChatState build() => initial;
}
