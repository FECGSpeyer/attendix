// Help articles of features that exist only in the Flutter app (not in the
// Ionic content that help_content.dart is generated from). Edited by hand;
// tool/help/build_help.mjs does not touch this file.

import 'help_content.dart';
import 'help_content_en.dart';
import 'help_models.dart';

const List<HelpArticle> appHelpArticles = [
  HelpArticle(
    id: "set-assistant",
    title: "Chat-Assistent: Fragen per Chat stellen",
    categoryId: "settings",
    keywords: [
      "assistent", "chat", "ki", "ai", "künstliche intelligenz", "fragen", "frag", "anwesenheit", "quote",
      "statistik", "wer kommt", "nächster termin", "geburtstag", "werk", "zuletzt gesungen", "chatbot",
    ],
    body: "Mit dem Chat-Assistenten stellst du Fragen in eigenen Worten, statt dich durch Listen zu klicken. Du findest ihn als farbige Karte ganz oben unter „Mehr“ (im neuen Design unter „Ich“). Er ist noch in der Beta und beantwortet nur Fragen, ändern kann er noch nichts.\n\n**Das kannst du fragen:**\n- „Wie war meine Anwesenheit in den letzten 3 Monaten?“\n- „Wie oft war Jonas im Oktober da?“ oder „Wie ist die Quote im Tenor?“ (nur [[Administrator]], [[Verantwortlicher]] und [[Helfer]])\n- „Wer kommt am Sonntag?“ oder „Wer hat sich für Mittwoch noch nicht gemeldet?“ (nur Leitung und [[Helfer]])\n- „Wann ist die nächste Probe?“\n- „Wer hat diesen Monat Geburtstag?“ (nur Leitung und [[Helfer]])\n- „Wann haben wir ‚Großer Gott‘ zuletzt gesungen?“\n- „Wie melde ich mich ab?“ (zeigt passende Hilfeartikel)\n\nGibt es mehrere Personen mit dem Namen, fragt der Assistent nach, wen du meinst. Du kannst auf Deutsch, Englisch, Russisch oder Spanisch schreiben.\n\n**Einschalten:** Ein [[Administrator]] schaltet den Assistenten pro [[Instanz]] ein, unter „Mehr“ › „Einstellungen“ › „Chat-Assistent (Beta)“ (im neuen Design unter „Rollen und Rechte“ › „Was Mitglieder sehen“). Danach können ihn alle in der Instanz nutzen.\n\n**Datenschutz:** An den KI-Dienst geht nur deine getippte Nachricht, dazu das heutige Datum und die Namen der Gruppen und Termintypen. Personen, Anwesenheiten und andere Daten verlassen Attendix nicht: Die Antworten berechnet die App selbst, und du siehst dabei nur, was du auch sonst sehen darfst. Der Chat wird nicht gespeichert. Pro Person und pro Instanz gibt es ein Tageslimit.",
  ),
  HelpArticle(
    id: "people-rate-period",
    title: "Anwesenheitsquote für einen Zeitraum oder eine Terminart",
    categoryId: "people",
    keywords: [
      "quote", "anwesenheit", "prozent", "zeitraum", "dieses jahr", "letzte monate", "saison", "terminart",
      "termintyp", "probe", "vortrag", "auftritt", "filter", "anwesenheitsquote", "durchschnitt",
    ],
    body: "In der Mitgliederliste steht neben jeder Person ihre Anwesenheit in Prozent. Normal zählt sie alle Termine seit Saisonbeginn, deren Terminart zur Anwesenheitsquote zählt. Du kannst die Quote auch für einen kürzeren Zeitraum oder nur eine Terminart sehen, zum Beispiel „Dieses Jahr“ oder nur Vorträge.\n\n**Im neuen Design:** Tippe in „Mitglieder“ auf „Filter“. Unter „Anwesenheit zählen“ wählst du „Saison“, „Dieses Jahr“, „3 Monate“, „12 Monate“ oder „Eigener …“ für Von und Bis. Darunter legst du bei „Terminart“ fest, ob alle zählenden Termine oder nur eine Terminart zählen.\n\n**Im alten Design:** Öffne in der Personenliste das Optionen-Menü neben der Suche. Dort findest du den Zeitraum (Kalender-Symbol) und die Terminart.\n\nDie Prozente, der Durchschnitt pro Register und die Sortierung nach Anwesenheit richten sich dann nach deiner Auswahl. Oben steht die Auswahl als „Quote: …“; im neuen Design entfernst du sie mit dem X, im alten Design stellst du wieder „Saison“ und „Alle, die zählen“ ein. Hatte eine Person im gewählten Zeitraum keine passenden Termine, steht bei ihr keine Zahl. Die Auswahl gilt nur für dich und bleibt, bis du die App schließt oder die [[Instanz]] wechselst.\n\nDie Liste sehen [[Administrator]], [[Verantwortlicher]] und [[Helfer]]. Dieselbe Frage kannst du auch dem Chat-Assistenten stellen, z. B. „Wie war die Anwesenheit im Tenor dieses Jahr?“.",
  ),
];

const Map<String, HelpArticleTranslation> appHelpArticlesEn = {
  "set-assistant": HelpArticleTranslation(
    title: "Chat assistant: ask questions in a chat",
    keywords: [
      "assistant", "chat", "ai", "artificial intelligence", "questions", "ask", "attendance", "rate",
      "statistics", "who is coming", "next event", "birthday", "work", "last sung", "chatbot",
    ],
    body: "With the chat assistant you ask questions in your own words instead of clicking through lists. You find it as a coloured card at the top of “More” (in the new design under “Me”). It is still in beta and only answers questions, it can't change anything yet.\n\n**You can ask:**\n- “How was my attendance in the last 3 months?”\n- “How often did Jonas come in October?” or “What is the rate of the tenors?” (only [[Administrator|administrators]], [[Verantwortlicher|responsible persons]] and [[Helfer|helpers]])\n- “Who is coming on Sunday?” or “Who hasn't answered for Wednesday yet?” (only leaders and helpers)\n- “When is the next rehearsal?”\n- “Who has a birthday this month?” (only leaders and helpers)\n- “When did we last sing ‘Holy God’?”\n- “How do I sign out?” (shows matching help articles)\n\nIf several people have that name, the assistant asks whom you mean. You can write in German, English, Russian or Spanish.\n\n**Switching it on:** An [[Administrator|administrator]] switches the assistant on per [[Instanz|instance]], under “More” › “Settings” › “Chat assistant (beta)” (in the new design under “Roles and rights” › “What members see”). Then everyone in the instance can use it.\n\n**Privacy:** Only your typed message goes to the AI service, together with today's date and the names of the groups and event types. People, attendance and other data do not leave Attendix: the app works out the answers itself, and you only see what you may see anyway. The chat is not stored. There is a daily limit per person and per instance.",
  ),
  "people-rate-period": HelpArticleTranslation(
    title: "Attendance rate for a period or an event type",
    keywords: [
      "rate", "attendance", "percent", "period", "this year", "last months", "season", "event type",
      "rehearsal", "talk", "performance", "filter", "attendance rate", "average",
    ],
    body: "In the members list each person shows their attendance in percent. By default it counts all events since the start of the season whose event type counts for the attendance rate. You can also see the rate for a shorter period or for one event type only, for example “This year” or only talks.\n\n**In the new design:** In “Members”, tap “Filter”. Under “Count attendance” choose “Season”, “This year”, “3 months”, “12 months” or “Custom …” for From and To. Below, at “Event type”, choose whether all counting events or only one event type count.\n\n**In the old design:** In the list of people, open the options menu next to the search. There you find the period (calendar icon) and the event type.\n\nThe percentages, the average per register and the sort by attendance then follow your choice. At the top the choice shows as “Rate: …”; in the new design you remove it with the X, in the old design you set “Season” and “All that count” again. If a person had no matching events in the chosen period, no number is shown. The choice is only for you and stays until you close the app or switch [[Instanz|instance]].\n\n[[Administrator|Administrators]], [[Verantwortlicher|responsible persons]] and [[Helfer|helpers]] see the list. You can also ask the chat assistant the same question, e.g. “How was the attendance of the tenors this year?”.",
  ),
};

/// Ionic articles plus the Flutter-only ones.
const List<HelpArticle> allHelpArticles = [...helpArticles, ...appHelpArticles];

/// English translations of [allHelpArticles].
const Map<String, HelpArticleTranslation> allHelpArticlesEn = {...helpArticlesEn, ...appHelpArticlesEn};
