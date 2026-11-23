# Supabase MCP Server Setup

## Aktueller Status

✅ MCP Server installiert mit **Service Role Key** (voller Zugriff)

## Upgrade auf Service Key

Sobald du den Service Key von deinem Kollegen hast:

```bash
# Alten MCP Server entfernen
claude mcp remove supabase

# Neu mit Service Key hinzufügen
claude mcp add \
  -e SUPABASE_URL=https://api.attendix.de \
  -e SUPABASE_SERVICE_ROLE_KEY=<DEIN_SERVICE_KEY> \
  --transport stdio supabase -- npx -y @supabase/mcp-server-postgrest
```

Optional: Service Key in `.env` speichern (ist gitignored):
```
SUPABASE_SERVICE_KEY=<DEIN_SERVICE_KEY>
```

## Was geht mit anon key vs service key?

| Aktion | anon key | service_role |
|--------|----------|--------------|
| Schema einer Tabelle anzeigen | ❌ | ✅ |
| Alle Spalten/Typen auflisten | ❌ | ✅ |
| Daten ohne Login abfragen | ❌ (RLS blockiert) | ✅ |
| Foreign Keys erkennen | ❌ | ✅ |

## Verwendung (mit Service Key)

Mit dem MCP Server kannst du direkt mit der Supabase-Datenbank interagieren:

### Schema abfragen
```
Zeige mir die Struktur der 'player' Tabelle
```

### Daten abfragen
```
Welche Spalten hat die attendance Tabelle?
```

### Migrationen prüfen
```
Gibt es Unterschiede zwischen dem Supabase-Schema und meinen Freezed-Models?
```

## Sicherheitshinweis

- Service Key NIEMALS committen
- Nur in lokaler Entwicklung verwenden
- `.env` ist bereits in `.gitignore`