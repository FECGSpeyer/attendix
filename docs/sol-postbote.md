# Sol-Postbote für attendix

Der Sol-Postbote holt Code-Reviews von Sol (GPT-6.1-Sol über die Codex-CLI mit Leons privaten
ChatGPT-Konten) für PRs mit dem Label `review:sol` und legt sie als PR-Kommentar ab. Er ist ein Nachbau
des Postboten aus `Lionhunt3r/werkbank` (dort `docs/sol-postbote.md`, `ops/sol-postbote/`), nur der
Review-Modus: kein Umsetzungsmodus, kein Push-Token. Er läuft als eigene TrueNAS-App
`sol-postbote-attendix` neben dem werkbank-Postboten.

## Review anfordern (für Threads und Leon)

1. Einen PR-Kommentar schreiben, der mit `Sol-Auftrag` beginnt (erste Zeile genau so). Danach Umfang,
   Schwerpunkte und was Sol besonders prüfen soll. Optionale Zeilen:
   - `Effort: high` für Delta-Reviews, Doku und kleine Mechanik (Standard ist `xhigh`).
   - `Konto: Olli` oder `Konto: Leon` erzwingt ein Konto (sonst Olli zuerst, Leon als Ersatz).
2. Danach das Label `review:sol` an den PR setzen.
3. Warten, nicht blockierend: Alle fünf Minuten schaut der Postbote nach. Die Antwort kommt als Kommentar
   `Sol-Review (gpt-6.1-sol, <Effort>, <Konto>) zu Kopf <sha> …`, die erste Zeile des Berichts ist
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

## Aufbau

`ops/sol-postbote/compose.yaml` ist eine TrueNAS-App mit zwei Diensten:

- **`attendix-token`** hält als Einziges den Schlüssel der GitHub App und läuft mit Dockers Standardschutz.
  Alle zehn Minuten holt er ein Token (eine Stunde gültig, nur dieses Repository, nur „Issues: write“,
  „Pull requests: write“, „Contents: read“) und lädt `ops/sol-postbote/postbote.sh` vom Branch `master`
  (`SCRIPT_REF`) ins Volume `ctl`.
- **`attendix-postbote`** startet alle fünf Minuten einen Durchlauf als Benutzer `node`. Codex läuft je
  Konto als eigener Benutzer (`sola`, `solb`) ohne Token, im Lesemodus ohne Netz. Vor dem ersten Review
  jedes Kontos prüft ein Selbsttest, dass im Sandbox weder geschrieben noch das Netz erreicht noch das
  Token gelesen werden kann. Ein Bericht, der wie ein Zugangsdatum aussieht, wird nicht gepostet.
- **Volumes:** `codex-a`, `codex-b` (die Codex-Anmeldungen dieser App), `state` (Marker, Sperren,
  `status.txt`), `work` (Checkout), `ctl` (Token und Skript).

Zwei Konten, Sperren bei leerem Kontingent und Handschalter funktionieren wie im werkbank-Postboten
(dort `docs/sol-postbote.md`, Abschnitt „Zwei Konten“). Status:
`docker exec <container> cat /state/status.txt`. Das Kontingent-Issue des werkbank-Postboten ist hier aus,
weil das Repository öffentlich ist (`SOL_QUOTA_ISSUE=1` würde es einschalten); das Kontingent steht in
`status.txt` und im Issue in werkbank.

## Einrichten (einmalig, Leon)

Alles Geheime trägt Leon selbst ein, nie in Chat, Repo oder Log.

1. **GitHub App:** Die vorhandene App `werkbank-postbote` zusätzlich auf `Lionhunt3r/attendix` installieren
   (GitHub, Settings, Developer settings, GitHub Apps, `werkbank-postbote`, Install App, Configure, „Only
   select repositories“, `attendix` hinzufügen, speichern). Das Token dieser App wird im Compose auf
   Issues/Pull requests write und Contents read beschränkt, auch wenn die App für den Umsetzungsmodus in
   werkbank Contents write hat. Wer das trennen will, legt stattdessen eine eigene App `attendix-postbote`
   mit diesen drei Rechten an und installiert sie nur auf `attendix`.
2. **TrueNAS:** Apps, Discover Apps, Custom App, „Install via YAML“, Name `sol-postbote-attendix`; Inhalt von
   `ops/sol-postbote/compose.yaml` einfügen und nur dort beim Dienst `attendix-token` `APP_ID` und
   `APP_PRIVATE_KEY_B64` eintragen (dieselben Werte wie beim werkbank-Postboten, wenn dessen App genutzt
   wird). Erst nach dem Merge dieses PRs: Das Skript wird von `master` geladen.
3. **Codex-Logins (Gerätecode), in der TrueNAS-Shell als root:**
   ```
   C=$(docker ps --filter label=com.docker.compose.service=attendix-postbote -q | head -1)
   docker exec -it -u sola "$C" env CODEX_HOME=/codex/a codex login --device-auth
   ```
   Im Browser mit dem Konto **Ollis Codex** bestätigen. Dann mit `-u solb`, `CODEX_HOME=/codex/b` und dem
   Konto **Leons Codex** (privates Fenster). Prüfen:
   `docker exec -u sola "$C" env CODEX_HOME=/codex/a codex login status` (und `solb`, `b`).
   Die Anmeldungen des werkbank-Postboten nicht in diese App kopieren: Zwei Container mit derselben
   `auth.json` würden sich beim Erneuern der Anmeldung gegenseitig aussperren.
4. **Probe:** Ein PR mit Label `review:sol` und kurzem `Sol-Auftrag` (`Effort: high`). Einmal prüfen, dass
   Codex das Token nicht lesen kann: `docker exec -u sola "$C" cat /ctl/token` und
   `docker exec -u sola "$C" ls /codex/b` müssen „Permission denied“ melden.

## Sicherheit

Wie beim werkbank-Postboten (dort Abschnitt „Sicherheit“): kein Docker-Socket, nicht `privileged`, kein
Port; `attendix-postbote` läuft für Codex' Sandbox ohne seccomp und AppArmor, hält aber nur das
Ein-Stunden-Token, nie den Schlüssel. Zusätzlich hier, weil `attendix` öffentlich ist: nur PRs aus Branches
dieses Repositories, kein Kontingent-Issue. Jede Änderung an `ops/sol-postbote/**` ändert, was auf dem
TrueNAS mit den Konten läuft, und braucht deshalb Leons Freigabe.
