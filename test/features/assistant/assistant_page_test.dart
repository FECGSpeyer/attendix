import 'package:attendix/core/constants/enums.dart';
import 'package:attendix/core/providers/assistant_providers.dart';
import 'package:attendix/core/providers/redesign_providers.dart';
import 'package:attendix/core/providers/tenant_providers.dart';
import 'package:attendix/data/models/attendance/attendance.dart';
import 'package:attendix/features/assistant/data/assistant_command.dart';
import 'package:attendix/features/assistant/data/assistant_reply.dart';
import 'package:attendix/features/assistant/presentation/assistant_voice.dart';
import 'package:attendix/features/assistant/presentation/pages/assistant_page.dart';
import 'package:attendix/features/assistant/presentation/widgets/assistant_entry_card.dart';
import 'package:attendix/features/attendance/presentation/widgets/songs_selection_sheet.dart';
import 'package:attendix/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVoice implements AssistantVoice {
  VoidCallback? end;
  bool stopped = false;

  @override
  Future<bool> start({required String language, required void Function(String text) onText, required VoidCallback onEnd}) async {
    end = onEnd;
    onText('Wann ist die nächste Probe');
    return true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    end?.call();
  }
}

class _FakeChat extends AssistantChatNotifier {
  _FakeChat(this.initial);
  final AssistantChatState initial;
  final sent = <String>[];

  @override
  AssistantChatState build() => initial;

  @override
  Future<void> send(String text) async => sent.add(text);
}

Widget _app(Widget home,
        {required bool enabled, Role role = Role.admin, AssistantChatState? chat, _FakeChat? fake, AssistantVoice? voice}) =>
    ProviderScope(
      overrides: [
        if (voice != null) assistantVoiceProvider.overrideWithValue(voice),
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
      final chat = AssistantChatState(
        messages: [
          const AssistantMessage.user('Wie war Jonas in den letzten 3 Monaten?'),
          AssistantMessage.assistant(
            RateReply(
              subjectName: 'Jonas Müller',
              isMe: false,
              range: (from: DateTime(2026, 8, 11), to: DateTime(2026, 11, 11)),
              rate: (attended: 9, total: 12, percent: 75),
              personId: 4,
            ),
          ),
          const AssistantMessage.assistant(
            ChoiceReply(
              query: 'Jonas',
              options: [
                (label: 'Jonas Müller · Tenor', command: NextEventCommand()),
                (label: 'Jonas Klein · Bass', command: NextEventCommand()),
              ],
            ),
          ),
          const AssistantMessage.assistant(NoticeReply(AssistantNotice.changeLater)),
        ],
      );
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
      final chat = AssistantChatState(
        messages: [AssistantMessage.assistant(StatusPreviewReply(plan(12, self: false)))],
      );
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Status ändern'), findsOneWidget);
      expect(find.text('Jonas Müller · Probe 0'), findsOneWidget);
      expect(find.text('und 4 weitere'), findsOneWidget);
    });

    testWidgets('saved change offers undo once', (tester) async {
      final chat = AssistantChatState(
        messages: [
          AssistantMessage.assistant(StatusPreviewReply(plan(1), state: ActionState.done)),
          AssistantMessage.assistant(ActionDoneReply(statusPlan: plan(1), count: 1)),
          AssistantMessage.assistant(ActionDoneReply(statusPlan: plan(1), count: 1, undo: UndoState.undone)),
        ],
      );
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat, role: Role.player));
      expect(find.text('Speichern'), findsNothing);
      expect(find.text('1 Änderung gespeichert.'), findsNWidgets(2));
      expect(find.text('Rückgängig'), findsOneWidget);
      expect(find.text('Rückgängig gemacht.'), findsOneWidget);
    });

    test('cancel and the second confirmation never save', () async {
      final container = ProviderContainer(
        overrides: [
          assistantChatNotifierProvider.overrideWith(
            () => _Seeded(
              AssistantChatState(
                messages: [
                  AssistantMessage.assistant(StatusPreviewReply(plan(12, self: false))),
                  AssistantMessage.assistant(StatusPreviewReply(plan(1))),
                ],
              ),
            ),
          ),
        ],
      );
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
      final chat = AssistantChatState(
        messages: [
          AssistantMessage.assistant(
            CreatePreviewReply(
              CreatePlan(
                type: probe,
                days: [DateTime(2026, 12, 2), DateTime(2026, 12, 9)],
                title: 'Extraprobe',
                place: 'Gemeindehaus',
                skippedExisting: [DateTime(2026, 12, 16)],
              ),
            ),
          ),
        ],
      );
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('2 Termine anlegen?'), findsOneWidget);
      expect(find.text('Probe · Extraprobe'), findsOneWidget);
      expect(find.text('19:00 – 21:00 Uhr'), findsOneWidget);
      expect(find.text('Ort: Gemeindehaus'), findsOneWidget);
      expect(find.textContaining('schon einen Termin dieses Typs'), findsOneWidget);
      expect(find.text('Speichern'), findsOneWidget);
    });

    testWidgets('move and Werke previews', (tester) async {
      final chat = AssistantChatState(
        messages: [
          AssistantMessage.assistant(
            MovePreviewReply(
              MovePlan(
                before: const Attendance(id: 7, date: '2026-11-18T11:00:00.000Z', typeId: 'p'),
                title: 'Probe',
                oldDay: DateTime(2026, 11, 18),
                newDay: DateTime(2026, 11, 19),
                oldStart: '19:00',
                newStart: '19:00',
              ),
            ),
          ),
          AssistantMessage.assistant(
            SongsPreviewReply(
              SongsPlan(
                attendanceId: 7,
                title: 'Probe',
                date: DateTime(2026, 11, 18),
                historyDate: '2026-11-18T11:00:00.000Z',
                before: const [],
                after: const [SongHistoryEntry(songId: 1, songName: 'Großer Gott')],
                added: const ['Großer Gott'],
                removed: const [],
                notFound: const ['Nr. 999'],
              ),
            ),
          ),
        ],
      );
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Termin verschieben'), findsOneWidget);
      expect(find.textContaining('Bisher:'), findsOneWidget);
      expect(find.textContaining('Neu: Donnerstag'), findsOneWidget);
      expect(find.textContaining('Die Status bleiben'), findsOneWidget);
      expect(find.text('Werke für den Termin'), findsOneWidget);
      expect(find.text('Neu: Großer Gott'), findsOneWidget);
      expect(find.text('Nicht gefunden: Nr. 999'), findsOneWidget);
      expect(find.text('Speichern'), findsNWidgets(2));
    });

    testWidgets('created Termine can be undone', (tester) async {
      final chat = AssistantChatState(
        messages: [
          AssistantMessage.assistant(
            ActionDoneReply(
              createPlan: CreatePlan(type: probe, days: [DateTime(2026, 12, 2)]),
              createdIds: const [41],
              count: 1,
            ),
          ),
        ],
      );
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('1 Termin angelegt.'), findsOneWidget);
      expect(find.textContaining('löscht genau diese neuen Termine'), findsOneWidget);
      expect(find.text('Rückgängig'), findsOneWidget);
    });

    testWidgets('a type question offers the types', (tester) async {
      final chat = AssistantChatState(
        messages: [
          AssistantMessage.assistant(
            ChoiceReply(
              kind: ChoiceKind.type,
              query: '',
              options: [
                (label: 'Probe', command: CreateEventsCommand(dates: [DateTime(2026, 12, 2)], typeId: 'p')),
                (label: 'Gottesdienst', command: CreateEventsCommand(dates: [DateTime(2026, 12, 2)], typeId: 'g')),
              ],
            ),
          ),
          const AssistantMessage.assistant(NoticeReply(AssistantNotice.excuseNeedsReason)),
        ],
      );
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Welcher Termintyp?'), findsOneWidget);
      expect(find.text('Gottesdienst'), findsOneWidget);
      expect(find.textContaining('geht nur mit Grund'), findsOneWidget);
    });

    testWidgets('package 4: tasks, Werke, task and duty previews', (tester) async {
      final chat = AssistantChatState(
        messages: [
          const AssistantMessage.assistant(
            TasksReply([
              (id: 't1', title: 'Raum klären', dueDate: '2026-11-13', priority: 'high', inProgress: false),
              (id: 't2', title: 'Noten kopieren', dueDate: null, priority: 'medium', inProgress: true),
            ]),
          ),
          AssistantMessage.assistant(
            EventSongsReply(
              attendanceId: 7,
              title: 'Gottesdienst',
              date: DateTime(2026, 11, 15),
              songs: const ['12. Großer Gott', 'Lobe den Herren'],
            ),
          ),
          const AssistantMessage.assistant(
            TaskPreviewReply(
              TaskPlan(
                title: 'Raum klären',
                priority: 'high',
                personId: 3,
                personName: 'Thomas Weber',
                dueDate: '2026-11-13',
              ),
            ),
          ),
          AssistantMessage.assistant(
            DutyPreviewReply(
              DutyPlan(
                attendanceId: 9,
                personAttendanceId: 'pa',
                title: 'Aufbau',
                date: DateTime(2026, 11, 15),
                startTime: '09:00:00',
                required: 3,
                occupied: 1,
                oldStatus: AttendanceStatus.neutral,
              ),
            ),
          ),
        ],
      );
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Deine offenen Aufgaben'), findsOneWidget);
      expect(find.text('Raum klären'), findsNWidgets(2));
      expect(find.text('fällig 13.11.2026'), findsOneWidget);
      expect(find.text('in Arbeit'), findsOneWidget);
      expect(find.text('12. Großer Gott'), findsOneWidget);
      expect(find.text('Neue Aufgabe anlegen?'), findsOneWidget);
      expect(find.text('Zuständig: Thomas Weber'), findsOneWidget);
      expect(find.text('Priorität: hoch'), findsOneWidget);
      expect(find.textContaining('erst eine Nachricht, wenn du nach dem Speichern'), findsOneWidget);
      expect(find.text('Dienst übernehmen?'), findsOneWidget);
      expect(find.text('1 von 3 Plätzen besetzt'), findsOneWidget);
      expect(find.text('Speichern'), findsNWidgets(2));
    });

    testWidgets('package 4: person and message only as drafts', (tester) async {
      final chat = AssistantChatState(
        messages: [
          AssistantMessage.assistant(
            PersonDraftReply(
              firstName: 'Anna',
              lastName: 'Müller',
              groupId: 2,
              groupName: 'Sopran',
              birthday: DateTime(2008, 4, 3),
            ),
          ),
          AssistantMessage.assistant(
            MessageDraftReply(
              playerIds: const [1, 2, 3],
              groupName: 'Tenor',
              attendanceId: 7,
              eventTitle: 'Gottesdienst',
              eventDate: DateTime(2026, 11, 15),
              eventTime: '10:00',
              note: 'Bitte schwarze Kleidung.',
            ),
          ),
        ],
      );
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Neue Person (Entwurf)'), findsOneWidget);
      expect(find.text('Gruppe: Sopran'), findsOneWidget);
      expect(find.text('Geburtstag: 03.04.2008'), findsOneWidget);
      expect(find.text('Im Formular öffnen'), findsOneWidget);
      expect(find.text('Mitteilung (Entwurf)'), findsOneWidget);
      expect(find.text('An: Tenor · 3 Personen'), findsOneWidget);
      expect(find.text('Erinnerung: Gottesdienst'), findsOneWidget);
      expect(find.textContaining('Bitte schwarze Kleidung.'), findsOneWidget);
      expect(find.textContaining('Ich sende nichts'), findsOneWidget);
      expect(find.text('Entwurf öffnen'), findsOneWidget);
      // Drafts never offer "Speichern".
      expect(find.text('Speichern'), findsNothing);
    });

    testWidgets('a new task offers notify and undo', (tester) async {
      final chat = AssistantChatState(
        messages: [
          const AssistantMessage.assistant(
            ActionDoneReply(
              taskPlan: TaskPlan(title: 'Raum klären', priority: 'medium', personId: 3, personName: 'Thomas'),
              taskId: 'abc',
              notify: NotifyState.available,
              count: 1,
            ),
          ),
        ],
      );
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, chat: chat));
      expect(find.text('Aufgabe angelegt.'), findsOneWidget);
      expect(find.text('Thomas benachrichtigen'), findsOneWidget);
      expect(find.text('Rückgängig'), findsOneWidget);
    });

    testWidgets('voice input writes into the field and sends nothing', (tester) async {
      final voice = _FakeVoice();
      final fake = _FakeChat(const AssistantChatState());
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, fake: fake, voice: voice));
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      expect(find.text('Wann ist die nächste Probe'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(fake.sent, isEmpty);
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(voice.stopped, isTrue);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(fake.sent, isEmpty);
    });

    testWidgets('parents: own suggestion and title for their children', (tester) async {
      final chat = AssistantChatState(messages: [
        AssistantMessage.assistant(StatusPreviewReply(StatusPlan(
          self: false,
          parents: true,
          status: AttendanceStatus.excused,
          reason: 'krank',
          changes: [
            StatusChange(
              personAttendanceId: 'a',
              attendanceId: 1,
              personName: 'Lena Müller',
              title: 'Kinderchor',
              date: DateTime(2026, 11, 15),
              oldStatus: AttendanceStatus.neutral,
              oldNotes: null,
              newStatus: AttendanceStatus.excused,
            ),
          ],
        ))),
      ]);
      _tall(tester);
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, role: Role.parent, chat: chat));
      expect(find.text('Deine Kinder an- oder abmelden?'), findsOneWidget);
      expect(find.text('Lena Müller · Kinderchor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(const AssistantPage(), enabled: true, role: Role.parent));
      expect(find.text('Melde meine Kinder für den nächsten Termin ab, sie sind krank'), findsOneWidget);
      expect(find.text('Wie war meine Anwesenheit in den letzten 3 Monaten?'), findsNothing);
    });
  });
}

class _Seeded extends AssistantChatNotifier {
  _Seeded(this.initial);
  final AssistantChatState initial;

  @override
  AssistantChatState build() => initial;
}
