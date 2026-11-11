// Help articles of features that exist only in the Flutter app (not in the
// Ionic content that help_content.dart is generated from). Edited by hand;
// tool/help/build_help.mjs does not touch this file.

import 'help_content.dart';
import 'help_content_en.dart';
import 'help_models.dart';

const List<HelpArticle> appHelpArticles = [
  HelpArticle(
    id: "set-assistant",
    title: "Chat-Assistent: fragen und an- oder abmelden per Chat",
    categoryId: "settings",
    keywords: [
      "assistent", "chat", "ki", "ai", "künstliche intelligenz", "fragen", "frag", "anwesenheit", "quote",
      "statistik", "wer kommt", "nächster termin", "geburtstag", "werk", "zuletzt gesungen", "chatbot",
      "abmelden", "anmelden", "status", "abwesenheit", "urlaub", "verspätung", "rückgängig",
    ],
    body: "Mit dem Chat-Assistenten stellst du Fragen in eigenen Worten, statt dich durch Listen zu klicken, und meldest dich mit einem Satz an oder ab. Du findest ihn als farbige Karte ganz oben unter „Mehr“ (im neuen Design unter „Ich“). Er ist noch in der Beta.\n\n**Das kannst du fragen:**\n- „Wie war meine Anwesenheit in den letzten 3 Monaten?“\n- „Wie oft war Jonas dieses Jahr da?“, „Wie war Jonas bei Vorträgen?“ oder „Wie ist die Quote im Tenor?“ (nur [[Administrator]], [[Verantwortlicher]] und [[Helfer]])\n- „Wer kommt am Sonntag?“, „Wer war letzten Sonntag da?“ oder „Wer hat sich für Mittwoch noch nicht gemeldet?“ (nur Leitung und [[Helfer]])\n- „Wann ist die nächste Probe?“\n- „Wer hat diesen Monat Geburtstag?“ (nur Leitung und [[Helfer]])\n- „Wann haben wir ‚Großer Gott‘ zuletzt gesungen?“\n- „Wie melde ich mich ab?“ (zeigt passende Hilfeartikel)\n\n**Das kannst du ändern:**\n- Dich selbst an- oder abmelden oder eine Verspätung melden: „Melde mich für Sonntag ab, ich bin krank“, „Ich komme Mittwoch später“, „Melde mich nächste Woche überall ab“. Es gelten dieselben Regeln wie unter „Meine Termine“ (Anmeldefrist, Anmeldefelder), und die Leitung bekommt wie gewohnt Bescheid.\n- Eine geplante Abwesenheit eintragen: „Ich bin vom 3. bis 10. März im Urlaub“, wenn deine Rolle das darf.\n- Als Leitung oder [[Helfer]] den Status anderer setzen: „Jonas und Marie waren am Mittwoch da“, „Tenor am Sonntag entschuldigt“. Als Leitung auch Abwesenheiten anderer: „Lena ist bis Ende Januar im Ausland“.\n\n**So bleibt es sicher:** Bevor etwas gespeichert wird, zeigt der Chat genau, welche Termine sich ändern, und du tippst auf „Speichern“ oder „Abbrechen“. Ab 11 Änderungen fragt er ein zweites Mal. Nach dem Speichern kannst du alles mit „Rückgängig“ zurücknehmen. Pro Nachricht gehen höchstens 30 Änderungen, nur Termine von 14 Tagen zurück bis 6 Monate voraus, und Abwesenheiten ab heute bis 6 Monate voraus. Löschen, Personen anlegen, Rollen oder Einstellungen ändern geht über den Chat nicht. Du kannst nie mehr ändern als sonst in der App.\n\nGibt es mehrere Personen mit dem Namen, fragt der Assistent nach, wen du meinst. Du kannst auf Deutsch, Englisch, Russisch oder Spanisch schreiben.\n\n**Einschalten:** Ein [[Administrator]] schaltet den Assistenten pro [[Instanz]] ein, unter „Mehr“ › „Einstellungen“ › „Chat-Assistent (Beta)“ (im neuen Design unter „Rollen und Rechte“ › „Was Mitglieder sehen“). Danach können ihn alle in der Instanz nutzen.\n\n**Datenschutz:** An den KI-Dienst geht nur deine getippte Nachricht, dazu das heutige Datum und die Namen der Gruppen und Termintypen. Personen, Anwesenheiten und andere Daten verlassen Attendix nicht: Die Antworten berechnet die App selbst, und du siehst dabei nur, was du auch sonst sehen darfst. Der Chat wird nicht gespeichert. Pro Person und pro Instanz gibt es ein Tageslimit.",
  ),
];

const Map<String, HelpArticleTranslation> appHelpArticlesEn = {
  "set-assistant": HelpArticleTranslation(
    title: "Chat assistant: ask and sign in or out by chat",
    keywords: [
      "assistant", "chat", "ai", "artificial intelligence", "questions", "ask", "attendance", "rate",
      "statistics", "who is coming", "next event", "birthday", "work", "last sung", "chatbot",
      "sign out", "sign in", "status", "absence", "holiday", "late", "undo",
    ],
    body: "With the chat assistant you ask questions in your own words instead of clicking through lists, and sign in or out with one sentence. You find it as a coloured card at the top of “More” (in the new design under “Me”). It is still in beta.\n\n**You can ask:**\n- “How was my attendance in the last 3 months?”\n- “How often did Jonas come this year?”, “How was Jonas at talks?” or “What is the rate of the tenors?” (only [[Administrator|administrators]], [[Verantwortlicher|responsible persons]] and [[Helfer|helpers]])\n- “Who is coming on Sunday?”, “Who was there last Sunday?” or “Who hasn't answered for Wednesday yet?” (only leaders and helpers)\n- “When is the next rehearsal?”\n- “Who has a birthday this month?” (only leaders and helpers)\n- “When did we last sing ‘Holy God’?”\n- “How do I sign out?” (shows matching help articles)\n\n**You can change:**\n- Sign yourself in or out or report being late: “Sign me out for Sunday, I'm ill”, “I'll be late on Wednesday”, “Sign me out of everything next week”. The same rules as in “My events” apply (deadline, registration fields), and the leaders are notified as usual.\n- Enter a planned absence: “I'm on holiday from 3 to 10 March”, if your role may do so.\n- As a leader or [[Helfer|helper]], set the status of others: “Jonas and Marie were there on Wednesday”, “Tenors excused on Sunday”. Leaders can also enter absences of others: “Lena is abroad until the end of January”.\n\n**How it stays safe:** Before anything is saved, the chat shows exactly which events change, and you tap “Save” or “Cancel”. From 11 changes on it asks a second time. After saving you can take everything back with “Undo”. At most 30 changes per message, only events from 14 days back to 6 months ahead, and absences from today up to 6 months ahead. Deleting, adding people, changing roles or settings is not possible in the chat. You can never change more than you can elsewhere in the app.\n\nIf several people have that name, the assistant asks whom you mean. You can write in German, English, Russian or Spanish.\n\n**Switching it on:** An [[Administrator|administrator]] switches the assistant on per [[Instanz|instance]], under “More” › “Settings” › “Chat assistant (beta)” (in the new design under “Roles and rights” › “What members see”). Then everyone in the instance can use it.\n\n**Privacy:** Only your typed message goes to the AI service, together with today's date and the names of the groups and event types. People, attendance and other data do not leave Attendix: the app works out the answers itself, and you only see what you may see anyway. The chat is not stored. There is a daily limit per person and per instance.",
  ),
};

/// Ionic articles plus the Flutter-only ones.
const List<HelpArticle> allHelpArticles = [...helpArticles, ...appHelpArticles];

/// English translations of [allHelpArticles].
const Map<String, HelpArticleTranslation> allHelpArticlesEn = {...helpArticlesEn, ...appHelpArticlesEn};
