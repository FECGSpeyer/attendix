# E2E flows (Patrol)

The flows in `patrol_test/` drive the real app like a user: they start
`lib/main.dart`, sign in and tap through pages. They are written once in Dart
([Patrol](https://patrol.leancode.co)) and run in the browser; native
platforms follow later.

They never talk to production. Every run starts a fresh **local Supabase**
(`e2e/supabase`, Docker) and creates its own test accounts
(`e2e/seed_accounts.sh`, password `attendix-e2e`, exists only in that local
instance).

## Where they run

GitHub: workflow **E2E** (`.github/workflows/e2e.yml`). It runs on pull
requests that touch `patrol_test/`, `e2e/` or the workflow, and by hand via
"Run workflow". A failed run uploads the Playwright report with screenshots
as the artifact `e2e-web-report`.

## Run locally

Needs Docker, the [Supabase CLI](https://supabase.com/docs/guides/local-development)
and Node.js.

```bash
supabase start --workdir e2e
eval "$(supabase status --workdir e2e -o env)"
e2e/seed_accounts.sh "$API_URL" "$SERVICE_ROLE_KEY"

# Point the app at the local Supabase. Keep a copy of your own .env.app.
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' "$API_URL" "$ANON_KEY" > .env.app

dart pub global activate patrol_cli 4.9.0
patrol test --device chrome                       # all flows
patrol test --device chrome -t patrol_test/login_test.dart

supabase stop --workdir e2e --no-backup
```

## Writing a flow

- One file per area, one `patrolTest` per flow. Name a flow after its
  scenario in `docs/beta/` once it has one.
- Start with `startApp($)` from `patrol_test/support/app.dart`
  (`beta: false` for the classic design) and sign in with `signIn`.
- Every test starts on a freshly loaded page with empty browser storage, so
  flows do not depend on each other.
- Find things the way a user does: by visible text (`label('Anmelden')`
  matches both designs, the classic design writes button labels in capitals)
  or by page type.
- Keep the number small: one flow per thing a role really does, not one per
  variant.
