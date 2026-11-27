# Ionic-Flutter Parity Audit Design

**Datum:** 2026-02-24
**Ziel:** Vollständiger Audit (Feature-Lücken + UX-Vergleich + Code-Review)
**Output:** Interaktives HTML-Dashboard mit JSON-Daten

---

## Übersicht

Systematischer Vergleich des Ionic-Projekts (`/Users/I576226/repositories/attendance`) mit dem Flutter-Projekt (`/Users/I576226/repositories/attendix`) auf drei Ebenen:

1. **Feature-Parität:** Alle Ionic-Funktionalitäten in Flutter vorhanden?
2. **UX-Konsistenz:** Gleiche User Experience (Dialoge, Navigation, etc.)?
3. **Code-Qualität:** Flutter-Patterns korrekt angewendet?

---

## Architektur

```
┌────────────────────────────────────────────────────────────────────┐
│                    IONIC-FLUTTER PARITY AUDIT                       │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    Starte 4 Agents parallel                      │
│  │ Orchestrator │────────────────────────────────────┐             │
│  └──────┬───────┘                                    │             │
│         │                                            │             │
│  ┌──────▼──────────────────────────────────────────────────────┐   │
│  │                    PARALLEL ANALYSIS                         │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐│   │
│  │  │ Feature-Gap │ │ Service-    │ │ UX-Detail   │ │ Code-   ││   │
│  │  │ Scanner     │ │ Parity      │ │ Analyzer    │ │ Quality ││   │
│  │  │             │ │ Checker     │ │             │ │ Auditor ││   │
│  │  │ 35 Ionic    │ │ 32 Ionic    │ │ Dialogs,    │ │ Riverpod││   │
│  │  │ Pages →     │ │ Services →  │ │ Toasts,     │ │ Patterns││   │
│  │  │ 38 Flutter  │ │ 10 Flutter  │ │ Navigation, │ │ Security││   │
│  │  │ Pages       │ │ Repos       │ │ Forms       │ │ Multi-  ││   │
│  │  │             │ │             │ │             │ │ Tenant  ││   │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └────┬────┘│   │
│  │         │               │               │              │     │   │
│  └─────────┼───────────────┼───────────────┼──────────────┼─────┘   │
│            └───────────────┴───────────────┴──────────────┘         │
│                            │                                        │
│                     ┌──────▼──────┐                                 │
│                     │  Aggregator │                                 │
│                     │  + Report   │                                 │
│                     │  Generator  │                                 │
│                     └──────┬──────┘                                 │
│                            │                                        │
│                     ┌──────▼──────┐                                 │
│                     │  Dashboard  │                                 │
│                     │  (HTML/JSON)│                                 │
│                     └─────────────┘                                 │
└────────────────────────────────────────────────────────────────────┘
```

---

## Agent-Spezifikationen

### Agent 1: Feature-Gap Scanner

**Input:**
- Ionic Pages: `/Users/I576226/repositories/attendance/src/app/`
- Flutter Features: `/Users/I576226/repositories/attendix/lib/features/`

**Algorithmus:**
1. Parse jede Ionic TypeScript-Page
2. Extrahiere: public methods, (click) handler, Dialoge, Navigation
3. Finde Flutter-Equivalent via Name-Matching
4. Vergleiche Funktionen 1:1
5. Score: (Flutter-Funktionen / Ionic-Funktionen) × 100

**Output:** `feature_gaps.json`

### Agent 2: Service-Parity Checker

**Input:**
- Ionic Services: `attendance/src/app/services/*.service.ts`
- Flutter Repos: `attendix/lib/data/repositories/*.dart`

**Algorithmus:**
1. Extrahiere alle public async Methoden aus Ionic Services
2. Finde Flutter Repository/Provider Equivalent
3. Methoden-Mapping (CRUD + Custom)
4. Score: (gemappte Methoden / Ionic Methoden) × 100

**Output:** `service_parity.json`

### Agent 3: UX-Detail Analyzer

**Prüfungen:**
| Kategorie | Ionic Pattern | Flutter Equivalent |
|-----------|---------------|-------------------|
| Dialoge | `IonAlert`, `IonActionSheet` | `showDialog`, `showModalBottomSheet` |
| Toast | `IonToast` | `ScaffoldMessenger.showSnackBar` |
| Loading | `IonLoading` | `CircularProgressIndicator` |
| Pull-Refresh | `ion-refresher` | `RefreshIndicator` |
| Infinite Scroll | `ion-infinite-scroll` | `ListView.builder` + Pagination |
| Forms | `FormControl`, `Validators` | `TextFormField`, `validator:` |

**Output:** `ux_divergences.json`

### Agent 4: Code-Quality Auditor

**Prüfungen:**
1. **Multi-Tenant Security:** `tenantId` Filter in allen Repositories
2. **Riverpod Patterns:** Naming, `ref.watch` vs `ref.read`, Invalidation
3. **Error Handling:** try-catch, `handleError()` Calls
4. **Freezed Models:** `@freezed` Annotation, generierte Dateien

**Output:** `code_quality.json`

---

## Output-Format

### Verzeichnisstruktur
```
docs/reports/ionic-flutter-parity-2026-02-24/
├── index.html          ← Interaktives Dashboard
├── data.json           ← Aggregierte Rohdaten
├── feature_gaps.json   ← Agent 1 Output
├── service_parity.json ← Agent 2 Output
├── ux_divergences.json ← Agent 3 Output
└── code_quality.json   ← Agent 4 Output
```

### Dashboard-Sektionen
1. **Summary Cards:** 4 Score-Karten (Features, Services, UX, Code)
2. **Feature Gaps:** Expandierbare Liste mit Severity-Icons
3. **Service Parity:** Matrix Ionic→Flutter mit Coverage %
4. **UX Divergences:** Tabelle mit Ionic vs Flutter Patterns
5. **Code Findings:** Sortiert nach Severity

### Scoring
- **Overall:** (Feature×1.5 + Service×1.0 + UX×0.8 + Code×1.0) / 4.3
- **Severity:**
  - 🔴 Critical: Fehlende Features, Security-Issues
  - 🟡 Warning: Partielle Implementierung, UX-Unterschiede
  - 🟢 Info: Minor Differences

---

## Projektmetriken

| Metrik | Ionic | Flutter |
|--------|-------|---------|
| Pages | 35 | 38 |
| Services/Repos | 32 | 10 |
| Code-Zeilen | ~27.000 TS | ~16.800 Dart |
| Migration-Status | - | ~97% |

---

## Nächste Schritte

1. Design-Dokument committen
2. Implementierungsplan erstellen (writing-plans Skill)
3. Agents implementieren und parallel ausführen
4. Dashboard generieren
