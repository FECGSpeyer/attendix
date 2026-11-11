# Sicherheit der Produktiv-Datenbank (Stand 2026-11-11)

Anlass: Supabase meldet für das Projekt „Attendix“ (`ultyjzgwejpehfjuyenr`)
`rls_disabled_in_public` und `sensitive_columns_exposed`. Es gibt nur dieses
eine Projekt; die Ionic-App und die Flutter-App nutzen es gemeinsam.

Alle Angaben unten stammen aus der echten Datenbank (Security Advisor,
`pg_class`, `pg_policies`, `pg_proc`, Auth-Konfiguration), gelesen am
2026-11-11. Geändert wurde dabei nichts.

## 1. Befund

### 1.1 Kritisch: 24 Tabellen ohne RLS

Bei diesen Tabellen ist Row Level Security aus. Mit dem öffentlichen
App-Schlüssel (steckt in jeder Web- und Store-App) kann jeder **ohne
Anmeldung** alle Zeilen lesen, ändern und löschen:

| Tabelle | Zeilen | Inhalt |
|---|---:|---|
| `person_attendances` | 179.000 | Anwesenheiten mit Notizen |
| `player` | 6.100 | Personen: Name, Geburtstag, E-Mail, Telefon, Notizen |
| `songs` | 7.200 | Werke mit Datei-Links |
| `attendance` | 3.700 | Termine, Ablaufpläne, Freigabe-Schlüssel |
| `tenantUsers` | 2.600 | Konto, E-Mail und Rolle je Instanz |
| `notifications` | 1.500 | Einstellungen, Telegram-Chat-ID |
| `history` | 1.200 | Werkhistorie |
| `tenant_role_permissions` | 1.100 | Rollenrechte |
| `instruments` | 990 | Gruppen |
| `device_tokens` | 660 | Push-Tokens aller Geräte |
| `attendance_types` | 580 | Terminarten |
| `tenants` | 190 | Instanzen samt Anmelde- und Werke-Link-Schlüssel |
| `group_categories`, `song_categories`, `churches`, `teachers`, `meetings`, `shifts`, `conductors`, `viewers`, `parents`, `questions`, `feedback`, `scores` | je < 100 | Stammdaten |

Bei fünf davon (`attendance`, `player`, `songs`, `song_categories`,
`tenant_role_permissions`) gibt es zwar Policies, sie wirken aber nicht, weil
RLS aus ist. Sie decken auch nur Sonderfälle ab. RLS dort einfach
einzuschalten würde beide Apps lahmlegen.

Das ist kein neuer Fehler der Flutter-App: Das Schema stammt aus der
Ionic-App, die sich komplett auf Filter im Client verlässt.

### 1.2 Weitere Funde

- `tenant_groups` und `tenant_group_tenants` haben RLS, aber eine Policy
  „alles für alle“. Auch ohne Anmeldung kann man Organisationen ändern und
  löschen.
- `get_user_id_by_email` (SECURITY DEFINER) ist ohne Anmeldung aufrufbar und
  verrät zu jeder E-Mail-Adresse, ob es ein Konto gibt, samt Konto-ID.
- Realtime: `player`, `attendance`, `person_attendances`, `songs` und
  `notifications` werden ohne RLS an jeden Abonnenten gesendet, also auch
  Änderungen fremder Instanzen.
- Storage: Die Buckets `songs` (8.400 Dateien), `profiles`, `attendances`,
  `branding` sind öffentlich. In `profiles` darf jeder ohne Anmeldung
  hochladen, in `songs`, `profiles`, `attendances`, `branding` darf jeder
  angemeldete Nutzer jede Datei überschreiben und löschen. Keine Größen-
  oder Dateityp-Grenzen.
- 12 Funktionen ohne festen `search_path`.
- Auth: Schutz vor bekannten Passwörtern aus, Mindestlänge 6, Token-Laufzeit
  7 Tage, kein Captcha, E-Mail-Änderung ohne Bestätigung der alten Adresse.
- Der alte `service_role`-Schlüssel steht im Klartext in drei
  Datenbank-Webhooks (`new_user`, `new_feedback`, `new_question`).
- Schon bekannt und zurückgestellt: Freigabe-Schlüssel der öffentlichen
  Pläne sind auslesbar (`docs/security-public-plans.md`).

### 1.3 Was in Ordnung ist

- Alle Edge Functions und Cron-Jobs arbeiten mit dem `service_role`-Key und
  prüfen das Konto selbst. RLS-Änderungen treffen sie nicht.
- Die neueren Tabellen (Nachrichten, Aufgaben, Protokolle, Abwesenheiten,
  Sammlungen, `files`-Bucket) haben saubere Policies nach Instanz und Rolle.
- E-Mail-Bestätigung ist Pflicht, Refresh-Token-Rotation ist an.

## 2. Plan in drei Stufen

Eine saubere Trennung nach Instanz und Rolle braucht Änderungen in beiden
Apps, weil sie an mehreren Stellen instanzübergreifend lesen (Konto per
E-Mail suchen, verknüpfte Personen, Organisations-Ansichten, Übertragen).
Deshalb in Stufen:

### Stufe 1: Tür zu für Unangemeldete (nur Datenbank, keine App-Änderung)

`supabase/sql/security_stufe1_rls.sql`, Rückweg
`supabase/sql/security_stufe1_rollback.sql`.

- RLS auf allen 24 Tabellen an.
- Ohne Anmeldung geht nur noch, was die öffentlichen Seiten brauchen:

  | Öffentliche Seite | Zugriff ohne Anmeldung |
  |---|---|
  | Anmeldelink `/register/:id` | Instanzen mit Anmeldelink, deren Gruppen und Terminarten und die Gemeindeliste lesen; Gemeinde anlegen; eigene Anmeldung anlegen (`tenantUsers` nur als Bewerber, bei automatischer Genehmigung als Mitglied; `player` nur mit `self_register`); die eigene frische Anmeldung 15 Minuten lang lesen und das Bild setzen; bei automatischer Genehmigung kommende Termine der Instanz lesen und sich eintragen |
  | Werke-Link `/:songSharingId` | Instanzen mit Werke-Link: Werke, Kategorien, Gruppen, Terminarten, Werkhistorie |
  | Plan-Links `/plan`, `/org-plan` | wie bisher (bestehende Policies); Bearbeiten nur noch der Spalten `plan` und `extra_plans` bei Terminen mit Bearbeiten-Link |

- Angemeldete Nutzer behalten den heutigen Zugriff. Ausnahmen, weil sicher
  eingrenzbar:
  - `device_tokens`, `live_activity_tokens`: nur eigene Zeilen, dazu ein
    Trigger, der ein Token beim Speichern anderen Konten wegnimmt (das ist
    der Inhalt von PR #383, der damit erledigt ist).
  - `notifications`: nur die eigene Zeile.
  - `feedback`, `questions`: nur anlegen.
- `tenant_groups`, `tenant_group_tenants`: ohne Anmeldung nur noch lesen.
- `get_user_id_by_email`: nur noch angemeldet.

Damit sind beide Supabase-Warnungen erledigt.

**Was sich sichtbar ändert:** Auf der öffentlichen Werke-Seite fehlen für
Besucher ohne Anmeldung die Namen der Dirigenten und die Termin-Titel bei
„Aktuelle Werke“. Dafür müsste die Seite Personen- und Terminzeilen lesen
dürfen. Beide Apps kommen mit den fehlenden Angaben klar (geprüft im Code).
Alles andere bleibt gleich.

**Was Stufe 1 nicht löst:** Wer ein Konto hat, kann per API weiterhin die
Daten aller Instanzen lesen und ändern. Ein Konto kann sich jeder mit einer
E-Mail-Adresse anlegen. Stufe 1 stoppt automatische Scanner und alle, die
nur die URL kennen, aber keinen gezielten Angreifer. Dafür braucht es
Stufe 2.

**Geprüft:** Die Migration läuft gegen eine lokale Postgres-Kopie der
betroffenen Tabellen samt der bestehenden Policies durch (auch zweimal
hintereinander). Durchgespielt wurden: Anmeldung ohne Konto (manuell und
automatisch genehmigt, mit Bild, mit Kindern), Werke-Link, Plan-Links samt
Bearbeiten, Angriffsversuche ohne Anmeldung auf jede Tabelle, angemeldete
Nutzer (Zugriff unverändert), Token-Übernahme zwischen zwei Konten.

**Ablauf auf Produktion:**

1. Probelauf: die Migration in einer Transaktion ausführen, als `anon` und
   als Testkonto prüfen, zurückrollen. Ändert nichts, hält die Tabellen
   etwa eine Sekunde gesperrt.
2. Migration anwenden (SQL-Editor). Reine Schema-Änderung, keine Daten.
3. Direkt danach mit dem öffentlichen Schlüssel prüfen (`player` leer,
   Anmeldelink und Werke-Link gehen) und eine Stunde lang die API-Logs auf
   Fehler 401/403 ansehen.
4. Wenn etwas Wichtiges nicht geht: Rückweg-Skript, wirkt sofort.

### Stufe 2: Instanzen voneinander trennen

Ziel: Angemeldete Nutzer sehen und ändern nur Zeilen ihrer eigenen
Instanzen. Offene Punkte, die dafür in beiden Apps oder per RPC gelöst
werden müssen:

- Konto per E-Mail suchen beim Hinzufügen von Admins, Eltern, Beobachtern
  (`tenantUsers` wird heute instanzübergreifend gelesen).
- Selbstanmeldung ohne bestätigtes Konto über eine RPC statt direkter
  Inserts; dann entfallen die 15-Minuten-Ausnahmen aus Stufe 1.
- Verknüpfte Personen (`global_person_id`), Organisations-Ansichten,
  Personen und Werke in eine andere Instanz übertragen, Gemeinden
  zusammenführen, Instanz anlegen.
- Öffentliche Werke-Seite: Dirigentennamen über eine RPC, die nur den Namen
  liefert. Sammlungen serverseitig (Stufe 2 aus PR #399).
- Freigabe-Schlüssel der Pläne (`docs/security-public-plans.md`).
- Realtime liefert danach automatisch nur noch eigene Instanzen.

Test: Testgruppe „Attendix Test“ mit den neun Rollen-Konten, jede Rolle in
beiden Apps.

### Stufe 3: Rollen serverseitig

Spieler, Eltern und Beobachter dürfen per API nur, was die App ihnen
erlaubt (heute reine App-Logik, siehe `docs/rls-audit.md`).

## 3. Weitere Empfehlungen

Nach Aufwand und Wirkung sortiert. Nichts davon ist Teil von Stufe 1.

| Thema | Empfehlung | Risiko für die Apps |
|---|---|---|
| Dashboard-Konten | Zwei-Faktor-Anmeldung für alle Mitglieder der Supabase-Organisation | keins |
| Auth | „Leaked password protection“ einschalten | keins, wirkt bei neuen Passwörtern |
| Auth | Bestätigung der alten Adresse bei E-Mail-Änderung („Secure email change“) | Ablauf beim E-Mail-Ändern prüfen |
| Auth | Token-Laufzeit von 7 Tagen auf 1 Stunde (Standard). Gesperrte oder gelöschte Konten bleiben sonst bis zu 7 Tage gültig | gering, beide Apps erneuern Tokens selbst; nach Offline-Zeiten prüfen |
| Auth | Mindestlänge Passwort 8 | Formulare beider Apps müssen dieselbe Grenze prüfen |
| Auth | Captcha (Turnstile) für Registrierung und Code-Mails | App-Änderung nötig |
| Datenbank | SSL für direkte Datenbankverbindungen erzwingen | nur, falls ein externes Tool ohne SSL verbindet |
| Storage | Größen- und Dateityp-Grenzen je Bucket; Schreib- und Löschrechte in `songs`, `profiles`, `attendances`, `branding` auf die eigene Instanz begrenzen; Auflisten abschalten | mit Stufe 2 |
| Funktionen | `search_path` bei den 12 gemeldeten Funktionen setzen | gering |
| Schlüssel | Webhooks auf Vault-Secret umstellen, danach alte JWT-Schlüssel (`anon`, `service_role`) abschalten; prüfen, ob `n8n_key` und `dirigentenschule` noch gebraucht werden | alte App-Versionen mit altem anon-Schlüssel beachten |
| Aufräumen | Sicherungstabellen `backup_*_20261014` und `songs_files_chor_alle_20261030` löschen, wenn nicht mehr gebraucht | keins |
| Nachsehen | API-Logs (7 Tage) auf Massenabfragen ohne Anmeldung prüfen | keins |
