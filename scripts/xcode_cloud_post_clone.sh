#!/usr/bin/env bash
# Shared Xcode Cloud post-clone bootstrap for iOS and macOS.
#
# Invoked by:
#   ios/ci_scripts/ci_post_clone.sh   -> scripts/xcode_cloud_post_clone.sh ios
#   macos/ci_scripts/ci_post_clone.sh -> scripts/xcode_cloud_post_clone.sh macos
#
# Note: Xcode Cloud builds plain Flutter archives via xcodebuild (no Shorebird
# OTA patches). See docs/release/xcode-cloud.md and docs/release/shorebird.md.
set -euo pipefail

# Never enable `set -x` here: secrets live in environment variables.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export CI=true

PLATFORM="${1:-}"
if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "macos" ]]; then
  echo "xcode-cloud: usage: $0 <ios|macos>" >&2
  exit 1
fi

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

log() {
  echo "[xcode-cloud][$PLATFORM] $*"
}

warn() {
  echo "[xcode-cloud][$PLATFORM] WARNING: $*" >&2
}

fail() {
  echo "[xcode-cloud][$PLATFORM] ERROR: $*" >&2
  exit 1
}

# 1. Resolve pinned Flutter version from .github/workflows/ci.yml (overridable).
FLUTTER_VERSION="${FLUTTER_VERSION:-$(sed -n "s/^ *flutter-version: *['\"]\{0,1\}\([0-9][0-9.]*\)['\"]\{0,1\} *$/\1/p" .github/workflows/ci.yml | head -n1)}"
[[ -n "$FLUTTER_VERSION" ]] || fail "Flutter version not found in .github/workflows/ci.yml (set FLUTTER_VERSION)."
log "Target Flutter version: $FLUTTER_VERSION"

# 2. Resolve store version name and build number via scripts/store_build.sh.
#    Xcode Cloud assigns CI_BUILD_NUMBER for App Store Connect uploads. Keep
#    FLUTTER_BUILD_NUMBER aligned with CI_BUILD_NUMBER whenever CI_BUILD_NUMBER
#    is higher than the pubspec-derived store build number.
STORE_ARGS="$(bash scripts/store_build.sh --print)"
BUILD_NAME="$(printf '%s\n' "$STORE_ARGS" | sed -n 's/.*--build-name \([^ ]*\).*/\1/p')"
STORE_BUILD_NUMBER="$(printf '%s\n' "$STORE_ARGS" | sed -n 's/.*--build-number \([0-9][0-9]*\).*/\1/p')"
[[ -n "$BUILD_NAME" && -n "$STORE_BUILD_NUMBER" ]] || fail "Could not parse scripts/store_build.sh --print output: $STORE_ARGS"

BUILD_NUMBER="$STORE_BUILD_NUMBER"
if [[ -n "${BUILD_NUMBER_OVERRIDE:-}" ]]; then
  [[ "$BUILD_NUMBER_OVERRIDE" =~ ^[0-9]+$ ]] || fail "BUILD_NUMBER_OVERRIDE must be an integer."
  BUILD_NUMBER="$BUILD_NUMBER_OVERRIDE"
  log "Using BUILD_NUMBER_OVERRIDE=$BUILD_NUMBER (store baseline: $STORE_BUILD_NUMBER)."
elif [[ -n "${CI_BUILD_NUMBER:-}" ]]; then
  if [[ "$CI_BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    if (( 10#$CI_BUILD_NUMBER > 10#$STORE_BUILD_NUMBER )); then
      BUILD_NUMBER="$CI_BUILD_NUMBER"
      log "Using CI_BUILD_NUMBER=$BUILD_NUMBER (above store baseline $STORE_BUILD_NUMBER)."
    else
      if (( 10#$CI_BUILD_NUMBER < 10#$STORE_BUILD_NUMBER )); then
        warn "CI_BUILD_NUMBER ($CI_BUILD_NUMBER) is below store baseline ($STORE_BUILD_NUMBER)."
        warn "Raise 'Next Build Number' in App Store Connect -> Xcode Cloud -> Settings -> Build Number above $STORE_BUILD_NUMBER so TestFlight accepts uploads."
      fi
      log "Using store baseline build number $BUILD_NUMBER (CI_BUILD_NUMBER=$CI_BUILD_NUMBER)."
    fi
  else
    warn "Ignoring non-numeric CI_BUILD_NUMBER='$CI_BUILD_NUMBER'; using $BUILD_NUMBER."
  fi
fi
log "Version: $BUILD_NAME ($BUILD_NUMBER)"

# 3. Generate .env.app from Xcode Cloud environment variables (client keys only).
#    Local runs keep an existing .env.app unless FORCE_WRITE_ENV=1 is set.
if [[ "${CI_XCODE_CLOUD:-}" == "TRUE" || "${FORCE_WRITE_ENV:-0}" == "1" || ! -f ".env.app" ]]; then
  [[ -n "${SUPABASE_ANON_KEY:-}" ]] || fail "SUPABASE_ANON_KEY is not set. Add it as a Secret Environment Variable in the Xcode Cloud workflow."
  export SUPABASE_URL="${SUPABASE_URL:-https://api.attendix.de}"

  python3 - << 'PY'
import os
import sys

def format_dotenv_value(value: str) -> str:
    if "\n" in value or "\r" in value:
        sys.exit("[xcode-cloud] ERROR: Environment variable values for .env.app must not contain newlines.")
    # Single-quote values containing '#' or '$' or whitespace (flutter_dotenv
    # treats unquoted '#' as comment start and interpolates '$').
    if any(ch in value for ch in ("#", "$", " ", "\t", '"', "'")):
        if "'" not in value:
            return f"'{value}'"
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")
        return f'"{escaped}"'
    return value

entries = [
    ("SUPABASE_URL", os.environ["SUPABASE_URL"].strip()),
    ("SUPABASE_ANON_KEY", os.environ["SUPABASE_ANON_KEY"].strip()),
]

sentry_dsn = os.environ.get("SENTRY_DSN", "").strip()
if sentry_dsn:
    entries.append(("SENTRY_DSN", sentry_dsn))
    entries.append(("SENTRY_ENVIRONMENT", os.environ.get("SENTRY_ENVIRONMENT", "production").strip() or "production"))

demo_email = (os.environ.get("DEMO_EMAIL") or os.environ.get("DEMOMAIL") or "").strip()
demo_password = (os.environ.get("DEMO_PASSWORD") or os.environ.get("DEMOPASSWORD") or "").strip()
if demo_email and demo_password:
    entries.append(("DEMO_EMAIL", demo_email))
    entries.append(("DEMO_PASSWORD", demo_password))

with open(".env.app", "w", encoding="utf-8") as fh:
    for key, value in entries:
        fh.write(f"{key}={format_dotenv_value(value)}\n")

print(f"[xcode-cloud] Wrote .env.app with keys: {', '.join(k for k, _ in entries)}")
PY
else
  log "Using existing local .env.app (set FORCE_WRITE_ENV=1 to regenerate)."
fi

# Verify .env.app contains required keys and never contains a service role key.
python3 - << 'PY'
import sys

with open(".env.app", "r", encoding="utf-8") as fh:
    lines = [l.strip() for l in fh if l.strip() and not l.strip().startswith("#")]

keys = {l.split("=", 1)[0].strip() for l in lines if "=" in l}
missing = [k for k in ("SUPABASE_URL", "SUPABASE_ANON_KEY") if k not in keys]
if missing:
    sys.exit(f"[xcode-cloud] ERROR: .env.app missing required key(s): {', '.join(missing)}")
if any("SERVICE_ROLE" in k for k in keys):
    sys.exit("[xcode-cloud] ERROR: .env.app must never contain SERVICE_ROLE keys.")
print(f"[xcode-cloud] Verified .env.app keys: {', '.join(sorted(keys))}")
PY

# 4. Decode GoogleService-Info.plist if provided via Xcode Cloud secret.
#    Both iOS and macOS copy phases read ios/Runner/GoogleService-Info.plist.
GOOGLE_PLIST="ios/Runner/GoogleService-Info.plist"
if [[ -n "${GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]]; then
  python3 - "$GOOGLE_PLIST" << 'PY'
import base64
import os
import sys

raw = "".join(os.environ["GOOGLE_SERVICE_INFO_PLIST_B64"].split())
try:
    data = base64.b64decode(raw, validate=True)
except Exception as exc:
    sys.exit(f"[xcode-cloud] ERROR: GOOGLE_SERVICE_INFO_PLIST_B64 is not valid base64: {exc}")

with open(sys.argv[1], "wb") as fh:
    fh.write(data)
PY
  xattr -c "$GOOGLE_PLIST" 2>/dev/null || true
  plutil -lint "$GOOGLE_PLIST" >/dev/null || fail "Decoded $GOOGLE_PLIST is not a valid plist."
  log "Decoded and verified $GOOGLE_PLIST."
elif [[ -f "$GOOGLE_PLIST" ]]; then
  log "Using existing $GOOGLE_PLIST."
else
  warn "$GOOGLE_PLIST missing and GOOGLE_SERVICE_INFO_PLIST_B64 not set; push notifications will be disabled."
fi

# 5. Install or reuse Flutter SDK at the pinned version.
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
if [[ "${CI_XCODE_CLOUD:-}" == "TRUE" ]] || ! command -v flutter >/dev/null 2>&1; then
  if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
    log "Cloning Flutter $FLUTTER_VERSION into $FLUTTER_HOME..."
    git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION" "$FLUTTER_HOME"
  else
    log "Reusing Flutter installation at $FLUTTER_HOME."
  fi
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

log "Flutter binary: $(command -v flutter)"
flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true

# The repo uses CocoaPods (Podfile.lock) without a committed swiftpm/Package.resolved.
# Xcode Cloud disables automatic SPM resolution during ci_post_clone, so disable
# Flutter's on-the-fly SPM auto-migration inside Xcode Cloud.
if [[ "${CI_XCODE_CLOUD:-}" == "TRUE" || "${DISABLE_FLUTTER_SPM:-0}" == "1" ]]; then
  log "Disabling Flutter Swift Package Manager auto-migration (using CocoaPods)..."
  flutter config --no-enable-swift-package-manager >/dev/null
fi

# 6. Ensure CocoaPods is available before `flutter build --config-only` runs.
if ! command -v pod >/dev/null 2>&1; then
  log "Installing CocoaPods via Homebrew..."
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 brew install cocoapods
fi

# 7. Precache platform artifacts, fetch Dart packages, and generate Xcode configs.
log "Running flutter precache --$PLATFORM..."
flutter precache "--$PLATFORM"

log "Running flutter pub get..."
flutter pub get

if [[ "$PLATFORM" == "ios" ]]; then
  log "Configuring iOS build settings (config-only)..."
  flutter build ios --release --no-codesign --config-only \
    --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER"
  GENERATED_CONFIG="ios/Flutter/Generated.xcconfig"
else
  log "Configuring macOS build settings (config-only)..."
  flutter build macos --release --config-only \
    --build-name "$BUILD_NAME" --build-number "$BUILD_NUMBER"
  GENERATED_CONFIG="macos/Flutter/ephemeral/Flutter-Generated.xcconfig"

  # 8. macOS App Store / TestFlight entitlements:
  #    macos/Runner/Release.entitlements omits keychain-access-groups and
  #    aps-environment so local ad-hoc builds succeed without a provisioning
  #    profile. In Xcode Cloud, Apple signs with the Mac App Store profile, so
  #    activate AppStore.entitlements inside the ephemeral clone.
  if [[ "${CI_XCODE_CLOUD:-}" == "TRUE" || "${APPLY_MACOS_APPSTORE_ENTITLEMENTS:-0}" == "1" ]]; then
    cp macos/Runner/AppStore.entitlements macos/Runner/Release.entitlements
    plutil -lint macos/Runner/Release.entitlements >/dev/null || fail "macos/Runner/Release.entitlements failed plutil lint."
    grep -q "keychain-access-groups" macos/Runner/Release.entitlements || fail "AppStore entitlements missing keychain-access-groups."
    grep -q "aps-environment" macos/Runner/Release.entitlements || fail "AppStore entitlements missing aps-environment."
    log "Applied macos/Runner/AppStore.entitlements for Xcode Cloud archive."
  else
    log "Local run: leaving macos/Runner/Release.entitlements unchanged (set APPLY_MACOS_APPSTORE_ENTITLEMENTS=1 to test swap)."
  fi
fi

# 9. Ensure CocoaPods dependencies are installed and synced with Podfile.lock.
#    `flutter build --config-only` normally runs `pod install` already; only
#    re-run it when Pods/Manifest.lock is missing or differs from Podfile.lock.
(
  cd "$REPO_ROOT/$PLATFORM"
  if [[ ! -f "Pods/Manifest.lock" ]] || ! cmp -s "Podfile.lock" "Pods/Manifest.lock"; then
    log "Running pod install in $PLATFORM/..."
    pod install || pod install --repo-update
  else
    log "CocoaPods already up to date in $PLATFORM/."
  fi
)

# 10. Summary check.
log "Generated config summary ($GENERATED_CONFIG):"
grep -E '^(FLUTTER_ROOT|FLUTTER_BUILD_NAME|FLUTTER_BUILD_NUMBER|TREE_SHAKE_ICONS)=' "$GENERATED_CONFIG" || true
log "Post-clone bootstrap finished successfully."
