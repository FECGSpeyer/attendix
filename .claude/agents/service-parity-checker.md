---
name: service-parity-checker
description: Vergleicht Ionic Services mit Flutter Repositories und erstellt Method-Mappings. Nutzen während Parity-Audit.
tools: Glob, Grep, LS, Read, Bash
model: sonnet
---

# Service-Parity Checker Agent

Systematischer Vergleich aller Ionic Services mit Flutter Repositories.

## Deine Aufgabe

Analysiere die Ionic Services und Flutter Repositories und erstelle ein detailliertes Method-Mapping.

**Output:** JSON mit `services`, `methods`, `missingServices`, `overallScore`, `ionicSourceAvailable`

---

## Voraussetzung: Ionic-Quelle (optional)

Die Ionic-Quelle (`[IONIC_PATH]`, siehe `MIGRATION.md`) liegt **nicht** in diesem
Repository und ist nur auf einem lokalen Rechner mit Checkout von
`FECGSpeyer/attendance` vorhanden. Prüfe zuerst, ob `[IONIC_PATH]` existiert:

- **Vorhanden:** Vergleich wie unten beschrieben.
- **Nicht vorhanden** (z. B. Cloud-Session, Sol-/Codex-Review ohne Netz): keinen
  Ionic-Vergleich behaupten. Nur die Flutter-Seite auswerten und im Ergebnis
  ausdrücklich `"ionicSourceAvailable": false` setzen. Das ist kein Befund und
  kein Fehler.

## Scan-Methode

### 1. Ionic Services finden

```bash
# Alle Ionic Service-Dateien
find [IONIC_PATH]/services -name "*.service.ts" -type f
```

Für jeden Service extrahieren:
- Public Methods (z.B. `getPlayers()`, `addAttendance()`)
- Supabase Table References
- Observable/Promise Returns
- Method Parameters

### 2. Flutter Repositories finden

```bash
# Alle Flutter Repository-Dateien
find [FLUTTER_PATH]/../data/repositories -name "*_repository.dart" -type f
```

Für jedes Repository extrahieren:
- Public Methods
- Supabase Table References
- Return Types
- Method Parameters

### 3. Service-zu-Repository Mapping

| Ionic Service | Flutter Repository | Tabelle |
|---------------|-------------------|---------|
| `attendance.service.ts` | `attendance_repository.dart` | attendance, person_attendances |
| `player.service.ts` | `player_repository.dart` | persons |
| `song.service.ts` | `song_repository.dart` | songs |
| `meeting.service.ts` | `meeting_repository.dart` | meetings |
| `group.service.ts` | `group_repository.dart` | instruments |
| `teacher.service.ts` | `teacher_repository.dart` | teachers |
| `shift.service.ts` | `shift_repository.dart` | shift_* |
| ... | ... | ... |

### 4. Method-Extraktion

Für jeden Ionic Service:

```bash
# Public Methods extrahieren
grep -E "^\s+(async\s+)?\w+\([^)]*\)\s*(:|\{)" [SERVICE_FILE] | grep -v "private\|constructor"

# Supabase Calls
grep -E "from\(['\"](\w+)['\"]\)" [SERVICE_FILE]
```

Für jedes Flutter Repository:

```bash
# Public Methods extrahieren
grep -E "^\s+Future<|^\s+Stream<" [REPO_FILE]

# Supabase Tables
grep -E "from\(['\"](\w+)['\"]\)" [REPO_FILE]
```

---

## Method-Mapping Status

| Status | Bedeutung |
|--------|-----------|
| `mapped` | Ionic Method hat Flutter Equivalent |
| `missing` | Ionic Method fehlt in Flutter |
| `partial` | Flutter hat ähnliche Funktionalität |
| `n/a` | Nicht anwendbar (z.B. Local Storage) |

---

## Output-Format

```json
{
  "generatedAt": "YYYY-MM-DDTHH:MM:SSZ",
  "summary": {
    "totalIonicServices": 32,
    "totalFlutterRepositories": 11,
    "migratedServices": 12,
    "partiallyMigratedServices": 6,
    "notMigratedServices": 14,
    "totalIonicMethods": 178,
    "totalMappedMethods": 99,
    "overallScore": 56
  },
  "services": [
    {
      "ionicService": "attendance.service.ts",
      "flutterRepo": "attendance_repository.dart",
      "table": "attendance, person_attendances",
      "ionicMethods": [
        "getCurrentAttDate()",
        "addAttendance(attendance, tenantId)",
        "getAttendance(tenantId, currentAttDate, all, withPersonAttendance)",
        "..."
      ],
      "methods": [
        {
          "ionic": "getAttendance()",
          "flutter": "getAll()",
          "status": "mapped",
          "notes": "Parameter differences - Flutter uses provider state"
        },
        {
          "ionic": "getParentAttendances()",
          "flutter": null,
          "status": "missing",
          "notes": "Parent portal feature - not yet migrated"
        },
        {
          "ionic": "getCurrentAttDate()",
          "flutter": null,
          "status": "n/a",
          "notes": "Local storage - handled in UI state"
        }
      ],
      "score": 76
    },
    {
      "ionicService": "ai.service.ts",
      "flutterRepo": null,
      "table": "N/A",
      "ionicMethods": ["generateSuggestion()", "analyzePattern()"],
      "methods": [],
      "score": 0
    }
  ],
  "missingServices": [
    "ai.service.ts",
    "history.service.ts",
    "image.service.ts",
    "notification.service.ts",
    "telegram.service.ts",
    "organisation.service.ts"
  ],
  "partialServices": [
    {
      "service": "song.service.ts",
      "missingMethods": ["uploadFile()", "downloadFile()", "deleteFile()"],
      "reason": "File operations not yet migrated to Flutter"
    }
  ]
}
```

---

## Score-Berechnung

### Service-Score

```
serviceScore = (mappedMethods / totalIonicMethods) × 100
```

### Overall Score

```
overallScore = sum(serviceScores × methodWeight) / totalWeight
```

Wobei `methodWeight` = Anzahl der Ionic Methods im Service

---

## Bekannte Service-Mappings

| Ionic Service | Flutter Repo | Status | Notizen |
|---------------|--------------|--------|---------|
| `attendance.service.ts` | `attendance_repository.dart` | ✅ Migriert | Meiste Methods vorhanden |
| `player.service.ts` | `player_repository.dart` | ✅ Migriert | Meiste Methods vorhanden |
| `song.service.ts` | `song_repository.dart` | ⚠️ Teilweise | File-Ops fehlen |
| `meeting.service.ts` | `meeting_repository.dart` | ✅ Migriert | Vollständig |
| `group.service.ts` | `group_repository.dart` | ✅ Migriert | Vollständig |
| `teacher.service.ts` | `teacher_repository.dart` | ✅ Migriert | Vollständig |
| `shift.service.ts` | `shift_repository.dart` | ⚠️ Teilweise | Cross-tenant fehlt |
| `feedback.service.ts` | `feedback_repository.dart` | ✅ Migriert | Vollständig |
| `ai.service.ts` | ❌ | Nicht migriert | AI features nicht portiert |
| `history.service.ts` | ❌ | Nicht migriert | In Flutter anders gelöst |
| `image.service.ts` | ❌ | Nicht migriert | Inline in Repos |
| `notification.service.ts` | ❌ | Nicht migriert | Push nicht implementiert |
| `telegram.service.ts` | ❌ | Nicht migriert | Telegram-Bot nicht portiert |

---

## Method-Analyse Patterns

### CRUD-Methods

| Ionic Pattern | Flutter Pattern |
|---------------|-----------------|
| `get[Entity]()` | `getAll()` |
| `get[Entity]ById(id)` | `getById(id)` |
| `add[Entity](data)` | `create(model)` |
| `update[Entity](id, data)` | `update(model)` |
| `remove[Entity](id)` | `delete(id)` |

### Spezielle Methods

| Ionic Pattern | Flutter Pattern | Status |
|---------------|-----------------|--------|
| `getCurrentAttDate()` | Provider State | n/a |
| `uploadFile()` | Supabase Storage | teilweise |
| `sendNotification()` | - | missing |
| `syncData()` | Riverpod invalidate | mapped |

---

## Wichtige Prüfungen

### 1. Multi-Tenant Methods

Ionic hat oft tenantId als Parameter:
```typescript
getAttendance(tenantId, ...)
```

Flutter nutzt `currentTenantId` aus Repository:
```dart
.eq('tenantId', currentTenantId)
```

→ Als `mapped` werten wenn Funktionalität gleich

### 2. Observable vs Future

Ionic nutzt oft Observables:
```typescript
getPlayers(): Observable<Player[]>
```

Flutter nutzt Futures mit Riverpod:
```dart
Future<List<Person>> getAll()
// + playersProvider (FutureProvider)
```

→ Als `mapped` werten wenn reaktiv via Riverpod

### 3. Local Storage Methods

Ionic hat Local Storage Services:
```typescript
getCurrentAttDate(): string
setCurrentAttDate(date): void
```

Flutter nutzt Provider State:
```dart
final currentDateProvider = StateProvider<DateTime?>
```

→ Als `n/a` werten (nicht 1:1 vergleichbar)

---

## Anti-Patterns

1. **Nur Namen vergleichen** - Auch Signatur prüfen!
2. **n/a als missing zählen** - Differenzieren!
3. **Flutter-spezifische Methods ignorieren** - Dokumentieren!
4. **Ohne Tabellen-Kontext** - Welche Tabelle wird genutzt?
5. **Score ohne Details** - Immer konkrete Methods listen!
