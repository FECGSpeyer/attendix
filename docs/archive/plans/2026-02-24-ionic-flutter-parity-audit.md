# Ionic-Flutter Parity Audit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Systematisch das Ionic-Projekt mit Flutter vergleichen und ein interaktives Dashboard mit Feature-Gaps, Service-Parity, UX-Divergenzen und Code-Quality-Findings generieren.

**Architecture:** 4 spezialisierte Agents laufen parallel und analysieren jeweils einen Aspekt. Ein Aggregator kombiniert die Ergebnisse zu einem HTML-Dashboard.

**Tech Stack:** Claude Task Tool (Explore/general-purpose Agents), JSON für Daten, HTML/CSS für Dashboard

---

## Task 1: Report-Verzeichnis erstellen

**Files:**
- Create: `docs/reports/ionic-flutter-parity-2026-02-24/`

**Step 1: Verzeichnis anlegen**

```bash
mkdir -p docs/reports/ionic-flutter-parity-2026-02-24
```

**Step 2: Commit**

```bash
git add docs/reports && git commit -m "chore: create parity audit report directory"
```

---

## Task 2: Feature-Gap Scanner Agent ausführen

**Agent Type:** `general-purpose`

**Prompt:**
```
Analysiere ALLE Ionic Pages und vergleiche sie mit Flutter Features.

**Ionic Projekt:** /Users/I576226/repositories/attendance/src/app/
**Flutter Projekt:** /Users/I576226/repositories/attendix/lib/features/

FÜR JEDE Ionic Page:
1. Lies die TypeScript-Datei vollständig
2. Extrahiere ALLE:
   - Public methods (async und sync)
   - Template-Actions: (click), (ionChange), etc.
   - Dialoge: IonAlert, IonActionSheet, IonModal
   - Navigation: router.navigate(), navCtrl.push()
   - Service-Aufrufe

3. Finde das Flutter-Equivalent:
   - Suche in lib/features/ nach ähnlichem Namen
   - Lies die Flutter-Page vollständig

4. Vergleiche Funktion für Funktion:
   - Ionic-Funktion vorhanden in Flutter? ✅/❌
   - Falls ❌: Was fehlt genau?
   - Falls abweichend: Was ist anders?

5. Berechne Score pro Page: (Flutter-Features / Ionic-Features) * 100

**OUTPUT FORMAT (JSON):**
{
  "pages": [
    {
      "ionicPage": "attendance/attendance.page.ts",
      "flutterPage": "attendance/presentation/pages/attendance_detail_page.dart",
      "ionicFeatures": ["markAttendance", "showStatusInfo", "deleteAttendance"],
      "flutterFeatures": ["markAttendance", "showStatusInfo"],
      "missingInFlutter": ["deleteAttendance"],
      "score": 66,
      "details": [
        {"feature": "deleteAttendance", "severity": "warning", "description": "Delete button missing"}
      ]
    }
  ],
  "overallScore": 85,
  "criticalGaps": []
}

Gib NUR das JSON aus, keinen anderen Text.
```

**Output File:** `docs/reports/ionic-flutter-parity-2026-02-24/feature_gaps.json`

---

## Task 3: Service-Parity Checker Agent ausführen (parallel mit Task 2)

**Agent Type:** `general-purpose`

**Prompt:**
```
Analysiere ALLE Ionic Services und vergleiche sie mit Flutter Repositories.

**Ionic Services:** /Users/I576226/repositories/attendance/src/app/services/
**Flutter Repos:** /Users/I576226/repositories/attendix/lib/data/repositories/
**Flutter Providers:** /Users/I576226/repositories/attendix/lib/core/providers/

FÜR JEDEN Ionic Service:
1. Lies die TypeScript-Datei vollständig
2. Extrahiere ALLE public async Methoden:
   - Methodenname
   - Parameter
   - Return-Type
   - Supabase-Table die angesprochen wird

3. Finde das Flutter-Equivalent:
   - Repository oder Provider mit ähnlichem Namen
   - Lies die Dart-Datei vollständig

4. Mapping erstellen:
   - Ionic-Methode → Flutter-Methode
   - Parameter identisch?
   - Return-Type kompatibel?

5. Score pro Service: (gemappte Methoden / Ionic-Methoden) * 100

**Bekannte Mappings:**
- attendance.service.ts → attendance_repository.dart
- player.service.ts → player_repository.dart
- song.service.ts → song_repository.dart
- shift.service.ts → shift_repository.dart
- meeting.service.ts → meeting_repository.dart
- group.service.ts → group_repository.dart
- teacher.service.ts → teacher_repository.dart
- feedback.service.ts → feedback_repository.dart

**OUTPUT FORMAT (JSON):**
{
  "services": [
    {
      "ionicService": "attendance.service.ts",
      "flutterRepo": "attendance_repository.dart",
      "methods": [
        {"ionic": "getAttendances()", "flutter": "getAll()", "status": "mapped"},
        {"ionic": "createAttendance()", "flutter": "create()", "status": "mapped"},
        {"ionic": "deleteAttendance()", "flutter": null, "status": "missing"}
      ],
      "score": 90
    }
  ],
  "overallScore": 88,
  "missingServices": ["ai.service.ts"]
}

Gib NUR das JSON aus, keinen anderen Text.
```

**Output File:** `docs/reports/ionic-flutter-parity-2026-02-24/service_parity.json`

---

## Task 4: UX-Detail Analyzer Agent ausführen (parallel mit Task 2, 3)

**Agent Type:** `general-purpose`

**Prompt:**
```
Analysiere UX-Patterns in beiden Codebases und finde Divergenzen.

**Ionic Projekt:** /Users/I576226/repositories/attendance/src/app/
**Flutter Projekt:** /Users/I576226/repositories/attendix/lib/

PRÜFE FOLGENDE KATEGORIEN:

1. **Dialoge:**
   - Ionic: Suche nach IonAlert, alertController, IonActionSheet
   - Flutter: Suche nach showDialog, AlertDialog, showModalBottomSheet
   - Vergleiche: Gleiche Dialoge an gleichen Stellen?

2. **Toast/Snackbar:**
   - Ionic: Suche nach IonToast, toastController
   - Flutter: Suche nach ScaffoldMessenger, SnackBar
   - Vergleiche: Dauer, Inhalt, Position

3. **Loading States:**
   - Ionic: Suche nach IonLoading, loadingController
   - Flutter: Suche nach CircularProgressIndicator, AsyncValue.loading
   - Vergleiche: Wo wird Loading angezeigt?

4. **Pull-to-Refresh:**
   - Ionic: Suche nach ion-refresher
   - Flutter: Suche nach RefreshIndicator
   - Vergleiche: Welche Listen haben Refresh?

5. **Forms:**
   - Ionic: FormControl, FormGroup, Validators
   - Flutter: TextFormField, Form, validator
   - Vergleiche: Validierung identisch?

6. **Navigation:**
   - Ionic: router.navigate, navCtrl, back()
   - Flutter: context.go, context.push, Navigator.pop
   - Vergleiche: Gleiche Flows?

**OUTPUT FORMAT (JSON):**
{
  "categories": [
    {
      "name": "dialogs",
      "ionic": {
        "count": 45,
        "locations": ["person.page.ts:deleteConfirm", "attendance.page.ts:statusInfo"]
      },
      "flutter": {
        "count": 38,
        "locations": ["person_detail_page.dart:_showDeleteDialog"]
      },
      "divergences": [
        {
          "location": "Song Detail",
          "ionic": "ActionSheet mit 5 Optionen",
          "flutter": "AlertDialog mit 3 Optionen",
          "severity": "warning"
        }
      ],
      "score": 84
    }
  ],
  "overallScore": 89
}

Gib NUR das JSON aus, keinen anderen Text.
```

**Output File:** `docs/reports/ionic-flutter-parity-2026-02-24/ux_divergences.json`

---

## Task 5: Code-Quality Auditor Agent ausführen (parallel mit Task 2, 3, 4)

**Agent Type:** `general-purpose`

**Prompt:**
```
Prüfe die Flutter-Codebase auf Qualität und Best Practices.

**Flutter Projekt:** /Users/I576226/repositories/attendix/lib/

PRÜFUNGEN:

1. **Multi-Tenant Security (KRITISCH):**
   - Jedes Repository in lib/data/repositories/ MUSS:
     - Von BaseRepository erben
     - TenantAwareRepository mixin haben
     - .eq('tenantId', currentTenantId) in JEDER Query
   - Suche nach Queries OHNE tenantId Filter → CRITICAL

2. **Riverpod Patterns:**
   - Provider-Namen enden auf "Provider"
   - FutureProvider für async Daten
   - NotifierProvider für Mutations
   - ref.watch in build(), ref.read in Callbacks
   - ref.invalidate nach Mutations

3. **Error Handling:**
   - try-catch in allen Repository-Methoden
   - handleError(e, stack, 'methodName') Call
   - Kein leeres catch {}

4. **Freezed Models:**
   - Alle Models in lib/data/models/ haben @freezed
   - .freezed.dart und .g.dart existieren
   - fromJson/toJson generiert

5. **Import Structure:**
   - Keine relativen Imports über features hinweg
   - Core-Imports korrekt

**OUTPUT FORMAT (JSON):**
{
  "categories": [
    {
      "name": "multi_tenant_security",
      "status": "pass|fail",
      "findings": [
        {
          "file": "song_repository.dart",
          "line": 45,
          "severity": "critical",
          "message": "Query ohne tenantId Filter",
          "code": ".select('*').order('name')"
        }
      ],
      "score": 95
    }
  ],
  "overallScore": 92,
  "criticalFindings": []
}

Gib NUR das JSON aus, keinen anderen Text.
```

**Output File:** `docs/reports/ionic-flutter-parity-2026-02-24/code_quality.json`

---

## Task 6: Agent-Ergebnisse aggregieren

**Files:**
- Read: `docs/reports/ionic-flutter-parity-2026-02-24/*.json`
- Create: `docs/reports/ionic-flutter-parity-2026-02-24/data.json`

**Step 1: Alle JSON-Dateien einlesen**

Lies alle 4 JSON-Outputs und kombiniere sie:

```json
{
  "generatedAt": "2026-02-24T...",
  "summary": {
    "featureScore": <aus feature_gaps.json>,
    "serviceScore": <aus service_parity.json>,
    "uxScore": <aus ux_divergences.json>,
    "codeQualityScore": <aus code_quality.json>,
    "overallScore": <gewichteter Durchschnitt>
  },
  "featureGaps": <feature_gaps.json>,
  "serviceParity": <service_parity.json>,
  "uxDivergences": <ux_divergences.json>,
  "codeQuality": <code_quality.json>
}
```

**Step 2: Overall Score berechnen**

```
overallScore = (featureScore * 1.5 + serviceScore * 1.0 + uxScore * 0.8 + codeQualityScore * 1.0) / 4.3
```

---

## Task 7: HTML-Dashboard generieren

**Files:**
- Create: `docs/reports/ionic-flutter-parity-2026-02-24/index.html`

**Dashboard-Template:**

```html
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ionic-Flutter Parity Audit</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        .score-card { transition: transform 0.2s; }
        .score-card:hover { transform: translateY(-2px); }
        .expandable { cursor: pointer; }
        .expandable-content { display: none; }
        .expandable.open .expandable-content { display: block; }
    </style>
</head>
<body class="bg-gray-100 min-h-screen">
    <div class="container mx-auto px-4 py-8">
        <header class="mb-8">
            <h1 class="text-3xl font-bold text-gray-800">Ionic → Flutter Parity Report</h1>
            <p class="text-gray-600">Generiert: <span id="generated-date"></span></p>
        </header>

        <!-- Summary Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
            <div class="score-card bg-white rounded-lg shadow p-6 text-center">
                <h3 class="text-sm font-medium text-gray-500">Features</h3>
                <p class="text-4xl font-bold" id="feature-score">--</p>
            </div>
            <div class="score-card bg-white rounded-lg shadow p-6 text-center">
                <h3 class="text-sm font-medium text-gray-500">Services</h3>
                <p class="text-4xl font-bold" id="service-score">--</p>
            </div>
            <div class="score-card bg-white rounded-lg shadow p-6 text-center">
                <h3 class="text-sm font-medium text-gray-500">UX</h3>
                <p class="text-4xl font-bold" id="ux-score">--</p>
            </div>
            <div class="score-card bg-white rounded-lg shadow p-6 text-center">
                <h3 class="text-sm font-medium text-gray-500">Code Quality</h3>
                <p class="text-4xl font-bold" id="code-score">--</p>
            </div>
        </div>

        <!-- Overall Score -->
        <div class="bg-white rounded-lg shadow p-6 mb-8 text-center">
            <h2 class="text-xl font-medium text-gray-600">Overall Parity Score</h2>
            <p class="text-6xl font-bold" id="overall-score">--</p>
        </div>

        <!-- Detail Sections -->
        <div class="space-y-6">
            <!-- Feature Gaps -->
            <section class="bg-white rounded-lg shadow">
                <div class="p-4 border-b expandable" onclick="toggleSection(this)">
                    <h2 class="text-xl font-semibold flex items-center justify-between">
                        Feature Gaps
                        <span class="text-gray-400">▼</span>
                    </h2>
                </div>
                <div class="expandable-content p-4" id="feature-gaps-content"></div>
            </section>

            <!-- Service Parity -->
            <section class="bg-white rounded-lg shadow">
                <div class="p-4 border-b expandable" onclick="toggleSection(this)">
                    <h2 class="text-xl font-semibold flex items-center justify-between">
                        Service Parity
                        <span class="text-gray-400">▼</span>
                    </h2>
                </div>
                <div class="expandable-content p-4" id="service-parity-content"></div>
            </section>

            <!-- UX Divergences -->
            <section class="bg-white rounded-lg shadow">
                <div class="p-4 border-b expandable" onclick="toggleSection(this)">
                    <h2 class="text-xl font-semibold flex items-center justify-between">
                        UX Divergences
                        <span class="text-gray-400">▼</span>
                    </h2>
                </div>
                <div class="expandable-content p-4" id="ux-divergences-content"></div>
            </section>

            <!-- Code Quality -->
            <section class="bg-white rounded-lg shadow">
                <div class="p-4 border-b expandable" onclick="toggleSection(this)">
                    <h2 class="text-xl font-semibold flex items-center justify-between">
                        Code Quality Findings
                        <span class="text-gray-400">▼</span>
                    </h2>
                </div>
                <div class="expandable-content p-4" id="code-quality-content"></div>
            </section>
        </div>
    </div>

    <script>
        function toggleSection(el) {
            el.parentElement.querySelector('.expandable-content').classList.toggle('hidden');
        }

        function getScoreColor(score) {
            if (score >= 90) return 'text-green-600';
            if (score >= 70) return 'text-yellow-600';
            return 'text-red-600';
        }

        function getSeverityBadge(severity) {
            const colors = {
                critical: 'bg-red-100 text-red-800',
                warning: 'bg-yellow-100 text-yellow-800',
                info: 'bg-blue-100 text-blue-800'
            };
            return `<span class="px-2 py-1 rounded text-xs font-medium ${colors[severity] || colors.info}">${severity}</span>`;
        }

        async function loadData() {
            try {
                const response = await fetch('data.json');
                const data = await response.json();
                renderDashboard(data);
            } catch (e) {
                console.error('Error loading data:', e);
            }
        }

        function renderDashboard(data) {
            document.getElementById('generated-date').textContent = new Date(data.generatedAt).toLocaleString('de-DE');

            // Scores
            const featureScore = data.summary.featureScore;
            const serviceScore = data.summary.serviceScore;
            const uxScore = data.summary.uxScore;
            const codeScore = data.summary.codeQualityScore;
            const overallScore = data.summary.overallScore;

            document.getElementById('feature-score').textContent = featureScore + '%';
            document.getElementById('feature-score').className = `text-4xl font-bold ${getScoreColor(featureScore)}`;

            document.getElementById('service-score').textContent = serviceScore + '%';
            document.getElementById('service-score').className = `text-4xl font-bold ${getScoreColor(serviceScore)}`;

            document.getElementById('ux-score').textContent = uxScore + '%';
            document.getElementById('ux-score').className = `text-4xl font-bold ${getScoreColor(uxScore)}`;

            document.getElementById('code-score').textContent = codeScore + '%';
            document.getElementById('code-score').className = `text-4xl font-bold ${getScoreColor(codeScore)}`;

            document.getElementById('overall-score').textContent = Math.round(overallScore) + '%';
            document.getElementById('overall-score').className = `text-6xl font-bold ${getScoreColor(overallScore)}`;

            // Feature Gaps
            const featureGapsHtml = data.featureGaps?.pages?.map(page => `
                <div class="border-b pb-4 mb-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="font-medium">${page.ionicPage}</span>
                        <span class="${getScoreColor(page.score)} font-bold">${page.score}%</span>
                    </div>
                    ${page.missingInFlutter?.length ? `
                        <div class="text-sm text-gray-600">
                            Missing: ${page.missingInFlutter.map(f => `<code class="bg-gray-100 px-1 rounded">${f}</code>`).join(', ')}
                        </div>
                    ` : '<div class="text-sm text-green-600">All features present</div>'}
                </div>
            `).join('') || '<p class="text-gray-500">No data</p>';
            document.getElementById('feature-gaps-content').innerHTML = featureGapsHtml;

            // Service Parity
            const serviceParityHtml = data.serviceParity?.services?.map(svc => `
                <div class="border-b pb-4 mb-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="font-medium">${svc.ionicService} → ${svc.flutterRepo || 'N/A'}</span>
                        <span class="${getScoreColor(svc.score)} font-bold">${svc.score}%</span>
                    </div>
                    <div class="text-sm">
                        ${svc.methods?.filter(m => m.status === 'missing').map(m => `
                            <span class="text-red-600">Missing: ${m.ionic}</span>
                        `).join('<br>') || '<span class="text-green-600">All methods mapped</span>'}
                    </div>
                </div>
            `).join('') || '<p class="text-gray-500">No data</p>';
            document.getElementById('service-parity-content').innerHTML = serviceParityHtml;

            // UX Divergences
            const uxHtml = data.uxDivergences?.categories?.map(cat => `
                <div class="border-b pb-4 mb-4">
                    <h3 class="font-medium capitalize mb-2">${cat.name}</h3>
                    <div class="grid grid-cols-2 gap-4 text-sm">
                        <div>Ionic: ${cat.ionic?.count || 0} occurrences</div>
                        <div>Flutter: ${cat.flutter?.count || 0} occurrences</div>
                    </div>
                    ${cat.divergences?.map(d => `
                        <div class="mt-2 p-2 bg-gray-50 rounded text-sm">
                            ${getSeverityBadge(d.severity)} <strong>${d.location}</strong>: ${d.ionic} vs ${d.flutter}
                        </div>
                    `).join('') || ''}
                </div>
            `).join('') || '<p class="text-gray-500">No data</p>';
            document.getElementById('ux-divergences-content').innerHTML = uxHtml;

            // Code Quality
            const codeHtml = data.codeQuality?.categories?.map(cat => `
                <div class="border-b pb-4 mb-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="font-medium capitalize">${cat.name.replace(/_/g, ' ')}</span>
                        <span class="${cat.status === 'pass' ? 'text-green-600' : 'text-red-600'}">${cat.status?.toUpperCase()}</span>
                    </div>
                    ${cat.findings?.map(f => `
                        <div class="mt-2 p-2 bg-gray-50 rounded text-sm">
                            ${getSeverityBadge(f.severity)} <code>${f.file}:${f.line}</code> - ${f.message}
                        </div>
                    `).join('') || '<div class="text-green-600 text-sm">No issues found</div>'}
                </div>
            `).join('') || '<p class="text-gray-500">No data</p>';
            document.getElementById('code-quality-content').innerHTML = codeHtml;
        }

        loadData();
    </script>
</body>
</html>
```

---

## Task 8: Report committen und öffnen

**Step 1: Commit all reports**

```bash
git add docs/reports/ionic-flutter-parity-2026-02-24/
git commit -m "feat: Add Ionic-Flutter parity audit report with dashboard"
```

**Step 2: Open in browser**

```bash
open docs/reports/ionic-flutter-parity-2026-02-24/index.html
```

---

## Execution Summary

| Task | Agent | Parallel? | Output |
|------|-------|-----------|--------|
| 1 | - | - | Directory |
| 2 | Feature-Gap Scanner | Yes | feature_gaps.json |
| 3 | Service-Parity Checker | Yes | service_parity.json |
| 4 | UX-Detail Analyzer | Yes | ux_divergences.json |
| 5 | Code-Quality Auditor | Yes | code_quality.json |
| 6 | - | After 2-5 | data.json |
| 7 | - | After 6 | index.html |
| 8 | - | After 7 | Git commit |

**Parallelisierung:** Tasks 2, 3, 4, 5 laufen gleichzeitig als separate Agents.
