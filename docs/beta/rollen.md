# Rollen: Wer sieht was, wer darf was

[Zurück zur Übersicht](README.md)

Jede Person hat in jeder Gruppe genau eine Rolle. Wer in zwei Gruppen ist, kann
dort verschiedene Rollen haben. Die Rolle bestimmt, welche Reiter die Person
sieht und was sie tun darf. Einige Rechte legt die Gruppe zusätzlich mit
Schaltern fest (siehe unten).

## Die Rollen

| Rolle | Kurz gesagt |
|-------|-------------|
| **Administrator** | Darf alles in der Gruppe, auch andere Admins verwalten. |
| **Verantwortlicher** | Leitet die Gruppe wie ein Admin, verwaltet aber keine Admins. |
| **Beobachter** | Sieht alles, ändert nichts. |
| **Helfer** | Ist Mitglied und erfasst zusätzlich die Anwesenheit. |
| **Stimmführer** | Ist Mitglied und sieht zusätzlich seine Stimme unter „Meine Stimme“. |
| **Stimmführer-Helfer** | Helfer, der zugleich Stimmführer ist. |
| **Mitglied** | Sagt zu oder ab, sieht eigene Termine und Noten. |
| **Elternteil** | Sieht die Termine der eigenen Kinder und meldet sie ab. |
| **Bewerber** | Hat sich angemeldet und wartet auf die Freigabe. |

In dieser Doku heißt **Leitung**: Administrator und Verantwortlicher.

## Welche Reiter sieht wer?

| Rolle | Heute | Termine | Mitglieder | Werke | Ich | Verwaltung |
|-------|:-----:|:-------:|:----------:|:-----:|:---:|:----------:|
| Administrator | ja | alle der Gruppe | volle Liste | ja | ja | ja |
| Verantwortlicher | ja | alle der Gruppe | volle Liste | ja | ja | ja, ohne „Admins“ |
| Beobachter | ja | alle der Gruppe, nur lesen | volle Liste, nur lesen | ja | ja | nein |
| Helfer, Stimmführer-Helfer | ja | alle der Gruppe | einfache Liste, wenn erlaubt | ja | ja | nein |
| Stimmführer | ja | eigene | einfache Liste, wenn erlaubt | ja | ja | nein |
| Mitglied | ja | eigene | einfache Liste, wenn erlaubt | ja | ja | nein |
| Elternteil | ja | die der Kinder | nein | nein | ja | nein |
| Bewerber | Warteseite | nein | nein | nein | ja | nein |

Dazu gilt:

- **Mitglieder, einfache Liste:** Sie erscheint nur, wenn die Leitung
  „Mitglieder-Tab für alle“ eingeschaltet hat. Sie zeigt Namen und Einteilung,
  keine Stammdaten.
- **Werke:** Allgemeine Gruppen haben keinen Reiter „Werke“.
- **Heute für Bewerber:** Statt der Startseite steht dort, dass die Anmeldung
  geprüft wird.

## Wer darf was?

| Aufgabe | Wer |
|---------|-----|
| Für sich selbst zusagen, absagen, Verspätung melden | Mitglied, Stimmführer, Helfer. Die Leitung und Beobachter haben keine eigene Zusage. |
| Für ein Kind antworten | Elternteil |
| Anwesenheit erfassen | Leitung, Helfer |
| Termine anlegen | Leitung. Helfer nur mit dem Schalter „Termine anlegen“. |
| Mitglieder anlegen, bearbeiten, freigeben, archivieren | Leitung |
| Werke anlegen und bearbeiten, Noten hochladen | Leitung |
| „Gespielte Werke“ ansehen | Leitung, Helfer |
| Dateiablage lesen | Leitung, Helfer. Alle anderen außer Bewerbern nur mit „Dateiablage für alle lesbar“. |
| In die Dateiablage hochladen | Leitung |
| „Meine Stimme“ ansehen | Stimmführer, Stimmführer-Helfer (nicht in allgemeinen Gruppen) |
| Einstellungen der Gruppe ändern („Verwaltung“) | Leitung |
| Admins verwalten | nur Administrator |
| Benachrichtigungen einstellen, Kalender abonnieren | alle außer Bewerbern |
| „Team“ (Besprechungen und Aufgaben) | Leitung immer. Andere, wenn die Teamorganisation an ist und sie zum Team gehören oder Aufgaben haben. |
| Chat-Assistent | alle außer Bewerbern, wenn die Gruppe ihn eingeschaltet hat |

## Schalter der Gruppe

Die Leitung stellt unter „Ich“ › „Verwaltung“ › „Rollen und Rechte“ ein, was
Helfer und Mitglieder dürfen und sehen. Jeder Schalter wird sofort gespeichert.

**Was Helfer dürfen**

| Schalter | Wirkung |
|----------|---------|
| „Alle Instrumente eintragen“ | Aus: Helfer erfassen nur die Anwesenheit ihres eigenen Instruments (Chor: ihrer Stimme). |
| „Stimmführer nur ihre Stimme“ | Helfer, die Stimmführer sind, erfassen nur ihre eigene Stimme. |
| „Termine anlegen“ | Aus: Helfer können keine neuen Termine anlegen. |
| „Notizen zu Personen sehen“ | Notizen im Termin bei der Anwesenheit. |
| „Checkliste im Termin sehen“ | Die Aufgaben, die vor einem Termin zu erledigen sind. |
| „Abwesenheit selbst eintragen“ | Sich für einen Zeitraum abmelden. |

Helfer, die Stimmführer sind, sehen Notizen und Checkliste immer.

**Was Mitglieder dürfen**

| Schalter | Wirkung |
|----------|---------|
| „Abwesenheit selbst eintragen“ | Sich für einen Zeitraum abmelden, zum Beispiel für den Urlaub. |
| „Sich selbst pausieren“ | Unter „Ich“ pausieren und wieder zurückkommen. Gilt für alle mit eigenem Profil, auch für Helfer. |

Beides gilt auch für Mitglieder, die Stimmführer sind.

**Was Mitglieder sehen**

| Schalter | Wirkung |
|----------|---------|
| „Alle Termine zeigen“ | Mitglieder sehen auch Termine, zu denen sie nicht eingeladen sind. |
| „Mitglieder-Tab für alle“ | Auch Mitglieder, Helfer und Stimmführer sehen die einfache Mitgliederliste. |

**Dateiablage**

| Schalter | Wirkung |
|----------|---------|
| „Dateiablage für alle lesbar“ | Sonst lesen nur Leitung und Helfer. Hochladen darf immer nur die Leitung. |

## Warum sehe ich etwas nicht?

Die häufigsten Gründe:

1. **Die Rolle erlaubt es nicht.** Siehe die Tabellen oben.
2. **Ein Schalter der Gruppe ist aus.** Zum Beispiel fehlt „Abwesenheit
   eintragen“ unter „Ich“, solange die Leitung es nicht erlaubt.
3. **Die Gruppe nutzt die Funktion nicht.** Zum Beispiel gibt es ohne
   Dienstplan keine „Offenen Dienste“ und ohne Teamorganisation kein „Team“.
4. **Du bist in dieser Gruppe nicht als Mitglied eingetragen.** Dann gibt es
   keine eigene Zusage und keine eigene Anwesenheit.
5. **Das falsche Design ist an.** Diese Doku gilt nur mit „Neues Design
   (Beta)“.
