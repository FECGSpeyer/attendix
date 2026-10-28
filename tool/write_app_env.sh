#!/usr/bin/env bash
# Writes .env.app – the ONLY env file bundled into the app (pubspec assets) –
# from .env, keeping just the client-side keys. Server-side secrets such as
# SUPABASE_SERVICE_ROLE_KEY stay in .env and never ship inside a build.
# Run before `flutter run` / `flutter build` on a developer machine.
set -euo pipefail
cd "$(dirname "$0")/.."
src="${1:-.env}"
out=".env.app"
allowed='^(SUPABASE_URL|SUPABASE_ANON_KEY|DEMO_EMAIL|DEMO_PASSWORD)='
if [[ ! -f "$src" ]]; then
  echo "missing $src" >&2
  exit 1
fi
# DEMO_* values are single-quoted like in CI: flutter_dotenv treats an
# unquoted '#' as a comment start and interpolates '$'.
grep -E "$allowed" "$src" | awk -F= -v OFS== '{
  key = $1; sub(/^[^=]*=/, "")
  if (key ~ /^DEMO_/ && $0 !~ /^[\x27"]/) $0 = "\x27" $0 "\x27"
  print key "=" $0
}' > "$out" || true
echo "wrote $out with keys: $(cut -d= -f1 "$out" | tr '\n' ' ')"
