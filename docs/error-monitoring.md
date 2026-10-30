# Fehler-Monitoring

Die App meldet unerwartete Fehler an [Sentry](https://sentry.io), sobald ein `SENTRY_DSN` gesetzt ist. Ohne DSN ist alles aus.

## Einrichten (einmalig)

1. Bei sentry.io ein Konto anlegen (der kostenlose Plan reicht) und ein Projekt vom Typ **Flutter** oder **Dart** erstellen.
2. Den DSN aus *Settings › Client Keys (DSN)* kopieren.
3. Im GitHub-Repo unter *Settings › Secrets and variables › Actions* ein Secret `SENTRY_DSN` mit diesem Wert anlegen.
4. Für lokale Builds auf dem iPhone oder Mac: `SENTRY_DSN=...` in `.env.app` eintragen.

Der Deploy-Workflow schreibt den DSN in die Web-App. Previews melden als Umgebung `preview`, master als `production`.

## Was gemeldet wird

- Jeder Fehler, den ein Repository über `handleError` behandelt
- Nicht abgefangene Fehler (`FlutterError.onError`, `PlatformDispatcher.onError`)
- Ausgewählte Stellen, die Fehler früher still verschluckt haben (`ErrorReporter.report`)

Netzwerkfehler (offline, Timeout) werden nicht gemeldet.

## Datenschutz

Gesendet werden nur der Fehler, der Stacktrace, die App-Version und der Ort im Code. Benutzer, IP-Adresse, Anfragedaten und Breadcrumbs entfernt `ErrorReporter.scrub`, bevor etwas das Gerät verlässt. Sentry sollte trotzdem in der Datenschutzerklärung (Tabelle `legal_content`) als Auftragsverarbeiter genannt werden.
