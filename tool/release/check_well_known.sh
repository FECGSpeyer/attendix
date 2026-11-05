#!/usr/bin/env bash
# Checks the Universal Link / App Link files (apple-app-site-association and
# assetlinks.json) that iOS and Android fetch from /.well-known/.
#
# Local mode (CI, after `flutter build web`):
#   tool/release/check_well_known.sh build/web
#   tool/release/check_well_known.sh web
#
# Remote mode (before/after the DNS switch, see docs/release/store-switch-runbook.md):
#   tool/release/check_well_known.sh https://attendix-5eg.pages.dev
#   tool/release/check_well_known.sh --apple-cdn https://attendix.de https://www.attendix.de
#
# Remote mode does NOT follow redirects (iOS does not either): each file must
# answer 200 directly, as JSON (the AASA also with a JSON Content-Type), and
# must not be the SPA fallback (index.html). --apple-cdn additionally checks
# Apple's cached copy at app-site-association.cdn-apple.com for each host
# (it can lag up to ~24 h behind the server).
#
# Several targets may be given; the exit code is non-zero if any check fails.
set -uo pipefail

IOS_APP_ID="MXM3YWAKPL.io.stephanus.attendix"
ANDROID_PACKAGE="io.stephanus.attendix"
AASA_PATH=".well-known/apple-app-site-association"
ASSETLINKS_PATH=".well-known/assetlinks.json"

failures=0
apple_cdn=0
targets=()

usage() {
  sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
}

for arg in "$@"; do
  case "$arg" in
    --apple-cdn) apple_cdn=1 ;;
    -h|--help) usage; exit 0 ;;
    *) targets+=("$arg") ;;
  esac
done

if [[ ${#targets[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

ok() { echo "  OK    $*"; }
fail() { echo "  FAIL  $*"; failures=$((failures + 1)); }
warn() { echo "  WARN  $*"; }

# check_json <kind: aasa|assetlinks> <file> <label>
# Validates JSON and that the app IDs are present. Python runs isolated (-I)
# because the file may come from the network.
check_json() {
  local kind="$1" file="$2" label="$3" out rc
  out="$(python3 -I - "$kind" "$file" "$IOS_APP_ID" "$ANDROID_PACKAGE" <<'PY'
import json, sys

kind, path, ios_id, android_pkg = sys.argv[1:5]
with open(path, "rb") as f:
    raw = f.read()
head = raw.lstrip()[:64].lower()
if head.startswith(b"<!doctype html") or head.startswith(b"<html"):
    print("FAIL is HTML (SPA fallback / index.html), not JSON")
    sys.exit(1)
try:
    data = json.loads(raw.decode("utf-8"))
except Exception as e:
    print(f"FAIL invalid JSON: {e}")
    sys.exit(1)

errors, warnings = [], []
if kind == "aasa":
    ids = []
    details = (data.get("applinks") or {}).get("details") if isinstance(data, dict) else None
    for d in details or []:
        if isinstance(d, dict):
            if isinstance(d.get("appID"), str):
                ids.append(d["appID"])
            ids.extend(x for x in d.get("appIDs") or [] if isinstance(x, str))
    if ios_id not in ids:
        errors.append(f"applinks has no entry for {ios_id}")
    creds = (data.get("webcredentials") or {}).get("apps") if isinstance(data, dict) else None
    if ios_id not in (creds or []):
        warnings.append(f"webcredentials does not list {ios_id} (no password suggestions)")
else:
    found = False
    for s in data if isinstance(data, list) else []:
        target = s.get("target") if isinstance(s, dict) else None
        if isinstance(target, dict) and target.get("package_name") == android_pkg:
            found = True
            if "delegate_permission/common.handle_all_urls" not in (s.get("relation") or []):
                errors.append(f"{android_pkg} lacks relation handle_all_urls")
            if not target.get("sha256_cert_fingerprints"):
                errors.append(f"{android_pkg} has no sha256_cert_fingerprints")
    if not found:
        errors.append(f"no statement for package {android_pkg}")

for w in warnings:
    print(f"WARN {w}")
for e in errors:
    print(f"FAIL {e}")
if not errors:
    print("OK valid JSON with app IDs")
sys.exit(1 if errors else 0)
PY
)"
  rc=$?
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    case "$line" in
      OK\ *) ok "$label: ${line#OK }" ;;
      WARN\ *) warn "$label: ${line#WARN }" ;;
      FAIL\ *) fail "$label: ${line#FAIL }" ;;
      *) fail "$label: $line" ;;
    esac
  done <<< "$out"
  if [[ $rc -ne 0 && -z "$out" ]]; then
    fail "$label: check failed (python3 exit $rc)"
  fi
}

check_local() {
  local dir="${1%/}" kind path file
  echo "== $dir (local)"
  if [[ ! -d "$dir" ]]; then
    fail "$dir is not a directory"
    return
  fi
  for kind in aasa assetlinks; do
    if [[ "$kind" == aasa ]]; then path="$AASA_PATH"; else path="$ASSETLINKS_PATH"; fi
    file="$dir/$path"
    if [[ ! -f "$file" ]]; then
      fail "$path missing"
      continue
    fi
    check_json "$kind" "$file" "$path"
  done
}

# check_url <kind> <url> <label>
check_url() {
  local kind="$1" url="$2" label="$3" tmp meta status ctype redirect
  tmp="$(mktemp)"
  # No -L: a redirect must fail, iOS does not follow it for the AASA.
  if ! meta="$(curl -sS -o "$tmp" --max-time 20 \
      -w '%{http_code}\t%{content_type}\t%{redirect_url}' "$url")"; then
    fail "$label: request failed ($url)"
    rm -f "$tmp"
    return
  fi
  IFS=$'\t' read -r status ctype redirect <<< "$meta"
  if [[ "$status" != "200" ]]; then
    fail "$label: HTTP $status${redirect:+ -> $redirect} ($url)"
    rm -f "$tmp"
    return
  fi
  ok "$label: HTTP 200, no redirect"
  if [[ "$ctype" == *json* ]]; then
    ok "$label: Content-Type $ctype"
  elif [[ "$kind" == aasa ]]; then
    fail "$label: Content-Type '${ctype:-none}', expected application/json"
  else
    warn "$label: Content-Type '${ctype:-none}', application/json recommended"
  fi
  check_json "$kind" "$tmp" "$label"
  rm -f "$tmp"
}

check_remote() {
  local base="${1%/}" host
  echo "== $base (remote)"
  check_url aasa "$base/$AASA_PATH" "$AASA_PATH"
  check_url assetlinks "$base/$ASSETLINKS_PATH" "$ASSETLINKS_PATH"
  if [[ $apple_cdn -eq 1 ]]; then
    host="${base#*://}"
    host="${host%%/*}"
    check_url aasa "https://app-site-association.cdn-apple.com/a/v1/$host" "Apple CDN ($host)"
  fi
}

for target in "${targets[@]}"; do
  case "$target" in
    http://*|https://*) check_remote "$target" ;;
    *) check_local "$target" ;;
  esac
done

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
