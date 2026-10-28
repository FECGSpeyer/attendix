# Sol-Postbote für attendix

Der Sol-Postbote holt Code-Reviews von Sol (GPT-6.1-Sol über die Codex-CLI mit Leons privaten
ChatGPT-Konten) für PRs mit dem Label `review:sol` und legt sie als PR-Kommentar ab. Es ist derselbe
Postbote wie für `Lionhunt3r/werkbank`: Er läuft dort als TrueNAS-App und prüft attendix mit denselben
Konten mit (Aufbau, Einrichtung und Sicherheit in werkbank unter `docs/sol-postbote.md`, Abschnitt
„Weitere Repositories“, Code in `ops/sol-postbote/`). In diesem Repository liegt nichts davon.

## Review anfordern (für Threads und Leon)

1. Einen PR-Kommentar schreiben, der mit `Sol-Auftrag` beginnt (erste Zeile genau so). Danach Umfang,
   Schwerpunkte und was Sol besonders prüfen soll. Optionale Zeilen:
   - `Effort: high` für Delta-Reviews, Doku und kleine Mechanik (Standard ist `xhigh`).
   - `Konto: Olli` oder `Konto: Leon` erzwingt ein Konto (sonst Olli zuerst, Leon als Ersatz).
   - `Modell: Astra` lässt GPT Astra (`gpt-6.1-astra`) statt Sol prüfen, `Modell: Sol` ist der Standard
     (`gpt-6.1-sol`). Der Kommentarkopf nennt das gelaufene Modell.
2. Danach das Label `review:sol` an den PR setzen.
3. Warten, nicht blockierend: Alle fünf Minuten schaut der Postbote nach. Die Antwort kommt als Kommentar
   `Sol-Review (<Modell>, <Effort>, <Konto>) zu Kopf <sha> …`, die erste Zeile des Berichts ist
   `Urteil: freigeben` oder `Urteil: nicht freigeben`, die letzte `Zahlen: <blockierend>/<wichtig>/<Hinweise>`.
   Das Label wechselt dann auf `review:sol-done`.
4. Delta-Review nach Korrekturen: pushen, neuen `Sol-Auftrag` (mit `Effort: high`) schreiben und
   `review:sol` wieder setzen. Ein Push oder neuer Auftrag während eines Laufs lässt das Label stehen;
   der nächste Durchlauf prüft dann den neuen Kopf.

Was zählt:

- Nur Aufträge von Eigentümer, Mitgliedern und Mitarbeitern des Repositories (`author_association`)
  gelten. Kommentare mit Leons GitHub-Konto (auch über `gh` oder die GitHub-Anbindung eines Threads)
  erfüllen das.
- Nur PRs aus Branches dieses Repositories, nie aus Forks: Das Repository ist öffentlich, fremder Code
  geht nie an Codex.
- Sol prüft `git diff origin/master...HEAD` nur lesend und ohne Netz. Er liest `CLAUDE.md`,
  `.claude/agents/flutter-reviewer.md`, bei Supabase, Auth und Mandanten
  `.claude/agents/security-scanner.md`, bei der Migration `MIGRATION.md` und
  `.claude/agents/service-parity-checker.md`. Tests laufen dabei nicht.
- Ein Review darf höchstens 45 Minuten dauern. Sehr große PRs besser in Teilen beauftragen
  (im Auftrag Verzeichnisse oder Commits nennen).
- Die Kommentare sind öffentlich wie das Repository.

Wenn nichts kommt: Der Postbote kommentiert selbst, wenn beide Konten leer oder abgemeldet sind
(„Review nicht möglich“), wenn der Sandbox-Selbsttest scheitert oder wenn Codex einen anderen Fehler
meldet. Nach sechs Stunden ganz ohne Antwort gilt der Ausweichweg: ein Claude-Reviewer mit Wechsel zum
Autor (schrieb Sonnet, prüft Opus; schrieb Opus, prüft Sonnet xhigh).
