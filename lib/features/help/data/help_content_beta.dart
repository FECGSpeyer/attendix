// Help articles that describe where things are, in the wording of the new
// design (Beta: Heute, Termine, Mitglieder, Werke, Ich). They replace the
// article with the same id while the Beta is on; every other article stays
// as it is. Edited by hand; tool/help/build_help.mjs does not touch this
// file.

import 'help_models.dart';

/// Beta versions (German) by article id.
const Map<String, HelpArticleTranslation> betaHelpArticles = {
  "gs-navigation": HelpArticleTranslation(
    title: "Wie ist die App aufgebaut?",
    keywords: ["tabs", "navigation", "menü", "übersicht", "reiter", "heute", "ich", "verwaltung", "wo finde ich", "einstellungen", "neues design", "beta"],
    body: "Auf dem Handy stehen unten bis zu fünf Reiter. Welche du siehst, hängt von deiner [[Rolle]] ab. Am Computer und auf dem Tablet im Querformat stehen sie in einer Seitenleiste links (siehe „Seitenleiste auf Tablet und Computer“).\n\n- **Heute**: der nächste Termin. Die Leitung sieht dort die Rückmeldungen und was ihre Aufmerksamkeit braucht, zum Beispiel neue Anmeldungen. Mitglieder sagen dort zu oder ab. Oben rechts ist die Glocke mit deinen Benachrichtigungen.\n- **Termine**: Die Leitung sieht alle Termine der Gruppe, legt neue an und erfasst die Anwesenheit. Mitglieder sehen ihre eigenen Termine.\n- **Mitglieder**: die Personen der Gruppe mit ihren [[Stammdaten]].\n- **Werke**: die Notenbibliothek der Gruppe.\n- **Ich**: alles zu dir, zum Beispiel Abwesenheit eintragen, Benachrichtigungen, Darstellung, Sprache, Hilfe und dein Konto.\n\n**Wo finde ich was?**\n- Die Einstellungen der Gruppe stehen unter „Ich“ › „Verwaltung“ (nur [[Administrator]] und [[Verantwortlicher]]). Die Verwaltung ist in Bereiche geteilt: Mitglieder, Zugänge und Rechte, Termine, Auswertung und Mitteilungen, Gruppe und Organisation.\n- Die Gruppe wechselst du unter „Ich“ › „Meine Gruppen“.\n- Ausloggen und Passwort ändern stehen unter „Ich“ › „Konto“.\n- Das neue Design schaltest du unter „Ich“ › „Neues Design (Beta)“ wieder aus. Die Einstellung gilt nur für dieses Gerät.",
  ),
  "gs-side-panel": HelpArticleTranslation(
    title: "Seitenleiste auf Tablet und Computer",
    keywords: ["seitenleiste", "sidepanel", "sidebar", "menü", "navigation", "tablet", "ipad", "computer", "abmelden", "ausloggen", "tabbar", "leitung", "persönlich"],
    body: "Am Computer und auf dem Tablet im Querformat ersetzt eine Seitenleiste links die Reiter unten. Welche Einträge du siehst, hängt von deiner [[Rolle]] ab.\n\n- **Oben** steht die aktuelle [[Instanz|Gruppe]]. Tippe darauf, um die Gruppe zu wechseln.\n- **Übersicht**: dieselben Bereiche wie die Reiter am Handy, also Heute, Termine, Mitglieder und Werke.\n- **Leitung** (nur [[Administrator]] und [[Verantwortlicher]]): Auswertung, Mitteilungen und Verwaltung.\n- **Persönlich**: „Ich“, „Team“ (wenn die [[Teamorganisation]] eingeschaltet ist) und die Hilfe.\n- **Eine Zahl an „Mitglieder“** zeigt der Leitung, wie viele neue Anmeldungen auf die Freigabe warten.\n\nDie Glocke mit deinen Benachrichtigungen ist oben rechts auf „Heute“. Ausloggen kannst du dich unter „Ich“ › „Konto“.\n\nHältst du ein Tablet hochkant, stehen die Bereiche als schmale Leiste mit Symbolen am linken Rand. Auf dem Handy bleiben die Reiter unten.",
  ),
  "gs-switch-instance": HelpArticleTranslation(
    title: "Zwischen mehreren Gruppen wechseln",
    keywords: ["instanz wechseln", "gruppe wechseln", "verein wechseln", "mehrere vereine", "mehrere gruppen", "meine gruppen"],
    body: "Wenn dein Konto zu mehreren [[Instanz|Gruppen]] gehört (z. B. weil du in mehreren Vereinen aktiv bist), wechselst du unter „Ich“ › „Meine Gruppen“: Tippe auf die Gruppe, die du öffnen möchtest. Am Computer geht das auch oben in der Seitenleiste: Tippe auf den Namen der Gruppe und wähle eine andere aus.\n\nAlle angezeigten Daten (Personen, Termine, Werke) gehören immer nur zur aktuell gewählten Gruppe.",
  ),
  "settings-switch-instance": HelpArticleTranslation(
    title: "Gruppe wechseln, favorisieren oder löschen",
    keywords: ["instanz wechseln", "gruppe wechseln", "instanz löschen", "gruppe löschen", "verein löschen", "favorit", "beitreten", "neue gruppe"],
    body: "Unter „Ich“ › „Meine Gruppen“ siehst du alle [[Instanz|Gruppen]], zu denen dein Konto gehört. Ein Tipp auf eine Gruppe wechselt dorthin.\n\nÜber „Gruppen verwalten“ öffnest du die Seite „Gruppen“. Neben jeder Gruppe öffnet das Symbol mit den drei Punkten weitere Aktionen:\n- **Details**: deine Rolle und Angaben zur Gruppe.\n- **Als Favorit markieren**: Die Gruppe wird beim Öffnen der App bevorzugt gewählt.\n- **Gruppe löschen**: nur als [[Administrator]]. Du bestätigst mit dem vollständigen Namen der Gruppe, weil sich das Löschen nicht rückgängig machen lässt.\n\nUnter „Weitere Gruppe“ trittst du mit einem Einladungslink einer Gruppe bei oder gründest eine neue. Mit „Gruppe nach der Anmeldung wählen“ fragt die App nach jeder Anmeldung, welche Gruppe du öffnen möchtest.",
  ),
  "other-dashboard": HelpArticleTranslation(
    title: "Heute (Startseite)",
    keywords: ["übersicht", "startseite", "heute", "dashboard", "geburtstag", "geburtstage", "nächster termin", "aufmerksamkeit", "glocke"],
    body: "„Heute“ ist die Startseite. Sie zeigt, was als Nächstes ansteht.\n\n**Für die Leitung** ([[Administrator]], [[Verantwortlicher]] und [[Helfer]]):\n- **Nächster Termin** mit den Rückmeldungen (zugesagt, entschuldigt, kommt später, offen) und „Anwesenheit erfassen“.\n- **Braucht deine Aufmerksamkeit**: neue Anmeldungen, [[Kritische Person|Problemfälle]], Termine ohne erfasste Anwesenheit und Abmeldungen für den nächsten Termin. Ein Tipp auf eine Zeile führt direkt dorthin.\n- **Anstehende Geburtstage** mit den Namen.\n\n**Für Mitglieder**: der nächste Termin mit deiner Antwort. Du sagst dort zu, meldest dich ab oder kündigst an, dass du später kommst.\n\nOben rechts ist die Glocke mit deinen Benachrichtigungen. Ein Punkt zeigt, dass es neue gibt. Die aktuellen Werke der nächsten Termine stehen im Reiter „Werke“ unter „Aktuell“.",
  ),
};

/// Beta versions (English) by article id.
const Map<String, HelpArticleTranslation> betaHelpArticlesEn = {
  "gs-navigation": HelpArticleTranslation(
    title: "How is the app structured?",
    keywords: ["tabs", "navigation", "menu", "overview", "today", "me", "administration", "where do i find", "settings", "new design", "beta"],
    body: "On the phone there are up to five tabs at the bottom. Which ones you see depends on your [[Rolle|role]]. On a computer and on a tablet in landscape they are in a sidebar on the left (see “Sidebar on tablet and computer”).\n\n- **Today**: the next event. Leaders see the responses there and what needs their attention, for example new registrations. Members accept or decline there. The bell with your notifications is at the top right.\n- **Events**: Leaders see all events of the group, create new ones and record attendance. Members see their own events.\n- **Members**: the people of the group with their [[Stammdaten|master data]].\n- **Works**: the group's sheet music library.\n- **Me**: everything about you, for example reporting an absence, notifications, appearance, language, help and your account.\n\n**Where do I find what?**\n- The group's settings are under “Me” › “Administration” (only [[Administrator|administrators]] and [[Verantwortlicher|responsible persons]]). It is divided into areas: Members, Access and permissions, Events, Statistics and messages, Group and organisation.\n- You switch group under “Me” › “My groups”.\n- Log out and change password are under “Me” › “Account”.\n- You switch the new design off again under “Me” › “New design (beta)”. The setting only applies to this device.",
  ),
  "gs-side-panel": HelpArticleTranslation(
    title: "Sidebar on tablet and computer",
    keywords: ["sidebar", "side panel", "menu", "navigation", "tablet", "ipad", "computer", "log out", "tab bar", "leadership", "personal"],
    body: "On a computer and on a tablet in landscape a sidebar on the left replaces the tabs at the bottom. Which entries you see depends on your [[Rolle|role]].\n\n- **At the top** is the current [[Instanz|group]]. Tap it to switch group.\n- **Overview**: the same areas as the tabs on the phone: Today, Events, Members and Works.\n- **Leadership** (only [[Administrator|administrators]] and [[Verantwortlicher|responsible persons]]): Insights, Announcements and Administration.\n- **Personal**: “Me”, “Team” (if [[Teamorganisation|team organisation]] is switched on) and Help.\n- **A number at “Members”** shows leaders how many new registrations are waiting for approval.\n\nThe bell with your notifications is at the top right of “Today”. You log out under “Me” › “Account”.\n\nIf you hold a tablet upright, the areas are a narrow bar with icons on the left edge. On the phone the tabs stay at the bottom.",
  ),
  "gs-switch-instance": HelpArticleTranslation(
    title: "Switching between several groups",
    keywords: ["switch instance", "switch group", "several clubs", "several groups", "my groups"],
    body: "If your account belongs to several [[Instanz|groups]] (e.g. because you are active in several clubs), you switch under “Me” › “My groups”: tap the group you want to open. On a computer you can also do this at the top of the sidebar: tap the group's name and choose another one.\n\nAll data shown (people, events, works) always belongs to the currently selected group only.",
  ),
  "settings-switch-instance": HelpArticleTranslation(
    title: "Switch, favourite or delete a group",
    keywords: ["switch instance", "switch group", "delete instance", "delete group", "favourite", "join", "new group"],
    body: "Under “Me” › “My groups” you see all [[Instanz|groups]] your account belongs to. Tapping a group switches to it.\n\n“Manage groups” opens the “Groups” page. Next to each group the three dots open more actions:\n- **Details**: your role and information about the group.\n- **Mark as favourite**: the group is preferred when the app opens.\n- **Delete group**: only as an [[Administrator|administrator]]. You confirm with the full name of the group, because deleting cannot be undone.\n\nUnder “Another group” you join a group with an invitation link or start a new one. With “Choose group after signing in” the app asks after every sign-in which group you want to open.",
  ),
  "other-dashboard": HelpArticleTranslation(
    title: "Today (start page)",
    keywords: ["overview", "start page", "today", "dashboard", "birthday", "birthdays", "next event", "attention", "bell"],
    body: "“Today” is the start page. It shows what is coming up next.\n\n**For leaders** ([[Administrator|administrators]], [[Verantwortlicher|responsible persons]] and [[Helfer|helpers]]):\n- **Next event** with the responses (accepted, excused, coming later, open) and “Record attendance”.\n- **Needs your attention**: new registrations, [[Kritische Person|problem cases]], events without recorded attendance and sign-outs for the next event. Tapping a row takes you straight there.\n- **Upcoming birthdays** with the names.\n\n**For members**: the next event with your answer. You accept there, sign out or say that you will come later.\n\nThe bell with your notifications is at the top right. A dot shows that there are new ones. The current works of the next events are in the “Works” tab under “Current”.",
  ),
};
