#!/bin/bash
# Creates the test accounts in the LOCAL Supabase (auth admin API).
# usage: e2e/seed_accounts.sh <api url> <service role key>
set -euo pipefail
API_URL=$1
SERVICE_KEY=$2
PASSWORD='attendix-e2e'   # same as e2ePassword in patrol_test/support/app.dart

for name in admin; do
  curl -sS --fail-with-body -o /dev/null \
    -X POST "$API_URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_KEY" -H "Authorization: Bearer $SERVICE_KEY" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$name@attendix.test\",\"password\":\"$PASSWORD\",\"email_confirm\":true}"
  echo "account $name@attendix.test"
done
