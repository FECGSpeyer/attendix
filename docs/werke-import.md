# Noten importieren: Google-Drive-Link und KI-Vorschläge einrichten

Im Beta-Design gibt es unter **Werke › + › Noten importieren** zwei Wege:

- **ZIP-Datei**: läuft ganz in der App, braucht keine Einrichtung.
- **Google Drive**: die Gruppe gibt ihren Notenordner mit „Jeder, der über den Link verfügt“ frei und fügt den Link ein. Die Edge Function `werke-import` liest den Ordner und kopiert die gewählten Dateien direkt von Google Drive in den Speicher der Gruppe. Aufs Handy wird nichts geladen.

Für den Drive-Weg braucht es einmalig drei Dinge. Solange sie fehlen, zeigt die App beim Link „Der Import per Link ist noch nicht eingerichtet“ und der ZIP-Weg funktioniert weiter.

## 1. Google-API-Schlüssel

1. In der [Google Cloud Console](https://console.cloud.google.com/) ein Projekt anlegen oder wählen (z. B. „Attendix“).
2. **APIs & Dienste › Bibliothek › Google Drive API › Aktivieren**.
3. **APIs & Dienste › Anmeldedaten › Anmeldedaten erstellen › API-Schlüssel**.
4. Den Schlüssel einschränken: **API-Einschränkungen › Schlüssel einschränken › Google Drive API**. Eine Einschränkung nach Websites oder IP-Adressen geht nicht, weil die Edge Function keine feste Adresse hat.

Der Schlüssel liest nur Dateien, die öffentlich per Link freigegeben sind. Er braucht keine Google-Prüfung und keine Anmeldung der Nutzer. Kosten entstehen bei Google nicht (Drive API ohne Gebühren, Tageskontingent reicht weit).

## 2. Tabelle für das Tageslimit

Im Supabase SQL Editor einmal ausführen: [`supabase/sql/werke_import_usage.sql`](../supabase/sql/werke_import_usage.sql).

Die Tabelle zählt pro Tag Aufrufe und Bytes je Konto und je Gruppe. Ohne sie lehnt die Funktion jeden Aufruf ab. Die Grenzen stehen oben in `supabase/functions/werke-import/index.ts` (20.000 Aufrufe und 10 GB je Konto, 40.000 und 20 GB je Gruppe). Der Speyer-Import mit rund 2.700 Dateien braucht etwa 3.000 Aufrufe.

## 3. Schlüssel hinterlegen und Funktion deployen

```bash
supabase secrets set GOOGLE_API_KEY=<schlüssel> --project-ref ultyjzgwejpehfjuyenr
supabase functions deploy werke-import --project-ref ultyjzgwejpehfjuyenr
```

Kurztest ohne Anmeldung (muss 401 liefern):

```bash
curl -i -X POST https://ultyjzgwejpehfjuyenr.supabase.co/functions/v1/werke-import \
  -H "Content-Type: application/json" -d '{}'
```

## Was die Funktion prüft

- Nur angemeldete Konten mit Bearbeitungsrecht in der Gruppe (wie `part-detect`).
- Beim Kopieren gehört das Werk zur Gruppe, der Dateiname hat das Muster der App und eine vorhandene Datei wird nie überschrieben.
- Es wird nur `www.googleapis.com` abgefragt. Google-Dokumente und Dateien über 20 MB werden abgelehnt.
- Tageslimit je Konto und Gruppe: jeder Aufruf wird gezählt, bevor Google gefragt wird; die Bytes einer Datei vor dem Herunterladen, das dort stoppt.
- Ordner mit mehr als 20.000 Einträgen auf einer Ebene werden abgelehnt (Unterordner wählen), nie halb gelesen.

## KI-Vorschläge für die Fragen

Unbekannte Stimmnamen („Sax“, „фл“) fragt der Import einmal ab. Mit dem Schalter **Vorschläge der KI** (an, wenn es Fragen gibt) schickt die App die Namen, ein paar Datei- und Werknamen an die Edge Function `part-suggest`. Die Gruppen liest die Funktion selbst aus der Datenbank. Sichere Vorschläge werden ausgefüllt und mit ✦ markiert, unsichere nur angeboten. Alles lässt sich ändern, ausschalten nimmt die ausgefüllten Antworten zurück.

Einrichtung wie bei `part-detect` (gleicher Schlüssel `OPEN_AI_KEY`, gleiches Tageslimit aus [`supabase/sql/part_detect_usage.sql`](../supabase/sql/part_detect_usage.sql), ein Aufruf pro Import):

```bash
supabase functions deploy part-suggest --project-ref ultyjzgwejpehfjuyenr
```

Ohne die Funktion steht bei den Fragen „Die KI ist gerade nicht erreichbar“, der Import geht normal weiter.

## Dropbox

Dropbox-Links gehen noch nicht. Dropbox liest geteilte Ordner nur mit dem Zugang eines angemeldeten Dropbox-Kontos aus. Dafür bräuchte es eine eigene Dropbox-App mit einem hinterlegten Konto. Bis dahin lädt man den Ordner bei Dropbox als ZIP herunter.
