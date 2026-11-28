# Testing & Quality Architecture

Attendix secures app quality across four automated `flutter test` layers, supplemented by end-to-end flows in `patrol_test/` and tooling tests in `tool/`.

## The 4 Flutter Test Layers (`test/`)

| Layer | Location | What it catches | Local command |
|---|---|---|---|
| **1. UI Layout & Design Guards** | `test/ui/` | Layout overflows, clipped text, undersized touch targets, spacing & design-system violations | `flutter test test/ui/` |
| **2. Visual Goldens** | `test/golden/` | Unintended pixel, colour, icon or typography regressions on key pages ([test/golden/README.md](../test/golden/README.md)) | `flutter test test/golden` |
| **3. Widget & Feature Tests** | `test/features/`, `test/shared/` | Broken user flows, Riverpod provider state, role permissions, forms, navigation and adaptive sheets | `flutter test test/features/ test/shared/` |
| **4. Core, Data, Security & Helpers** | `test/core/`, `test/data/`, `test/helpers/`, `test/*_test.dart` | Multi-tenant security leaks (`tenantId` guards), models, date/calc utils, l10n and PWA/service-worker tooling | `flutter test test/core/ test/data/` |

On CI (`.github/workflows/ci.yml`), all files under `test/` run across **4 parallel Linux shards**, alongside static analysis (`dart analyze`) and Python/JS tool checks (`python3 -m unittest tool/testing/test_dashboard.py`). On pull requests that touch `test/golden/goldens/**`, **Bildvergleich** (`.github/workflows/golden-preview.yml`) comments before/after screenshots directly on the PR.

## Test-Dashboard

An interactive HTML dashboard (zero external dependencies) and GitHub Actions summary can be generated at any time from the repository:

```bash
# Scan the repository and open the interactive dashboard in your browser
python3 tool/testing/generate_test_dashboard.py --open

# Or combine live `flutter test --file-reporter json:...` results and embed goldens
python3 tool/testing/generate_test_dashboard.py \
  --results path/to/test-results.json \
  --html build/test-dashboard/index.html \
  --embed-goldens \
  --markdown build/test-dashboard/summary.md
```

- **What it shows:** KPI cards, the 4-layer explanation, a **Feature Coverage Matrix** across `lib/features/*`, a **Golden Screenshot Gallery** (embedded standalone when `--embed-goldens` is passed), and an **Interactive Test Explorer** with search, layer filters, status filters and expandable test case lists.
- **Online (GitHub Pages):** Every push to `master` automatically publishes the interactive dashboard live to <https://fecgspeyer.github.io/attendix/>.
- **In GitHub Actions CI:** Every `CI` run aggregates all 4 shard JSON reports into `$GITHUB_STEP_SUMMARY` and uploads the standalone HTML dashboard as the **`test-dashboard`** artifact (retained for 14 days, even when a shard fails).

# E2E flows (Patrol)

The flows in `patrol_test/` drive the real app like a user: they start `lib/main.dart`, sign in and tap through pages. They are written once in Dart ([Patrol](https://patrol.leancode.co)) and run in the browser and in the Android app; iOS and macOS follow later.

They never talk to production. Every run starts a fresh **local Supabase** (`e2e/supabase`, Docker) and fills it with the tables, the access rules and the test data of the app. Those come from the private repository `attendix-db` (private because the schema shows how access is protected).

## The test data

Two groups that have nothing to do with each other, and one account per role. Every account is `<name>@attendix.test` with the password `attendix-e2e`; they exist only in the local instance.

| Account | Role |
|---|---|
| `admin`, `verantwortlich` | lead of the group "Stadtorchester" |
| `helfer` | Helfer |
| `mitglied`, `stimmfuehrer`, `stimmhelfer` | members (the last two with their section roles) |
| `beobachter` | Beobachter |
| `eltern` | Elternteil of the child "Lena Kind" |
| `bewerber`, `bewerberin` | signed up, not yet accepted |
| `chor-admin`, `chor-mitglied` | the second group "Kammerchor" |
| `fremd` | an account without a group |

"Stadtorchester" has a Probe on 1 June 2099 and the Auftritt "Sommerkonzert" on 1 July 2099, so "the next Termin" is the same on every day.

## The flows

| File | What |
|---|---|
| `login_test.dart` | sign-in and the first steps of a new account (N-…) |
| `mitglied_test.dart` | answering, looking at a Termin, Werke, sign-out (M-…) |
| `helfer_test.dart` | attendance, creating and changing a Termin (H-…) |
| `leitung_test.dart` | members, accepting an applicant, a new Werk, an instrument (L-…) |
| `weitere_rollen_test.dart` | Beobachter, Eltern, Stimmführer (B-…, E-…, S-…) |

A flow carries the number of its scenario in `docs/beta/szenarien/` (`M-01 Für den nächsten Termin zusagen`). A pull request that changes how that scenario works changes the flow with it.

## Where they run

GitHub: workflow **E2E** (`.github/workflows/e2e.yml`).

- **Web (Chromium), pull requests:** the flows tagged `pr`, a handful of the most important paths. All flows when the pull request touches `patrol_test/`, `e2e/` or the workflow, or carries the label `e2e-alle` (set the label before the push). Pull requests that only change docs or the changelog are left out.
- **Web (Chromium), every night** and by hand via "Run workflow": all flows.
- **Android (Emulator)** runs the flows tagged `mobil` in the Android app. It takes about 15 minutes, so it only runs by hand via "Run workflow", or on a pull request that carries the label `e2e-android` (set the label before the push). The emulator reaches the local Supabase of the job at `10.0.2.2`.

A failed web run uploads the Playwright report as the artifact `e2e-web-report`, and the log names the texts that were on the screen when a step did not find its widget.

The jobs read `attendix-db` with a key that can only read that repository (secret `ATTENDIX_DB_DEPLOY_KEY`). Pull requests from forks do not get it and skip the flows.

## Run locally

Needs Docker, the [Supabase CLI](https://supabase.com/docs/guides/local-development), Node.js, `psql` and read access to `attendix-db`.

```bash
git clone git@github.com:FECGSpeyer/attendix-db.git .attendix-db   # once

supabase start --workdir e2e
eval "$(supabase status --workdir e2e -o env)"
export SCHEMA_ADMIN_URL="${DB_URL/\/\/postgres:/\/\/supabase_admin:}"
.attendix-db/scripts/build_test_db.sh "$DB_URL"

# Point the app at the local Supabase. Keep a copy of your own .env.app.
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' "$API_URL" "$ANON_KEY" > .env.app

dart pub global activate patrol_cli 4.9.0
patrol test --device chrome                       # all flows
patrol test --device chrome --tags pr             # the ones of a pull request
patrol test --device chrome -t patrol_test/login_test.dart

supabase stop --workdir e2e --no-backup
```

The flows change the test data (answers, a new person, a new Termin). Before a second run, start from fresh data: `supabase db reset --workdir e2e`, then `build_test_db.sh` again.

## Writing a flow

- One file per role, one `patrolTest` per flow. Name a flow after its scenario in `docs/beta/`.
- Start with `startApp($)` from `patrol_test/support/app.dart` and sign in with `signInAs($, 'mitglied')`.
- Every test starts on a freshly loaded page with empty browser storage. The database is shared by all flows of a run, so a flow must not depend on what another one left behind: give a flow that changes something its own account or its own Termin. Creating and changing Termine happens in the second group, so "the next Termin" of the first one stays as it is.
- Find things the way a user does: by visible text. `tapOn($, 'Termine')` taps, `see($, 'Du bist dabei')` waits for a text, `seeNot` checks that something is missing. `label('Anmelden')` matches case-insensitively. Buttons that only show an icon have a `Key` or a name for screen readers (`named('Anwesend')`).
- The flows are written for a wide window (1280 × 800), where the app shows the side bar. Tag a flow `mobil` only when it also works on a phone.
- Tag a flow `pr` only when it guards a path nobody may break. Every `pr` flow costs time on every pull request.
- Keep the number small: one flow per thing a role really does, not one per variant.
