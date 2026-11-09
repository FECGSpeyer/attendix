#!/usr/bin/env bash
# Store build of the Flutter app with store version numbers.
#
# The Flutter app replaces the Ionic app as an update of the store app
# "Attendix" (io.stephanus.attendix). The stores only accept versions above
# Ionic's last one: 4.19.9, Android versionCode 230, iOS build 239.
#
# pubspec.yaml keeps the internal developer version (0.x+build, see
# CLAUDE.md "Interne vs. Nutzer-Version"), which is far below that. This
# script builds with
#   --build-name   = AppConstants.displayVersion (what users see, e.g. 5.0.0)
#   --build-number = pubspec build number + STORE_BUILD_OFFSET
# so every store build is above Ionic's and the number keeps rising with
# every internal version bump.
#
# Store builds go through Shorebird (OTA patches, docs/release/shorebird.md):
#   ipa            shorebird release ios
#   appbundle      shorebird release android
#   apk            shorebird release android --artifact apk
#   macos-release  shorebird release macos (Mac App Store / TestFlight, then
#                  sign + package as .pkg, see docs/release/shorebird.md)
#   patch-ios      shorebird patch ios     --release-version=<name>+<number>
#   patch-macos    shorebird patch macos   --release-version=<name>+<number>
#   patch-android  shorebird patch android --release-version=<name>+<number>
#                  (RELEASE_VERSION=<name>+<number> patches an earlier release)
#   ios, macos     plain flutter build (e.g. --config-only), NO Shorebird release
# The Flutter version for releases is read from .github/workflows/ci.yml and
# can be overridden with SHOREBIRD_FLUTTER_VERSION.
#
# Usage: scripts/store_build.sh <ipa|appbundle|apk|macos-release|patch-ios|patch-android|patch-macos|ios|macos> [flutter build args…]
#        scripts/store_build.sh --print   (only print name and number)
set -euo pipefail

STORE_BUILD_OFFSET=100
IONIC_ANDROID_VERSION_CODE=230
IONIC_IOS_BUILD=239

cd "$(dirname "$0")/.."

name=$(sed -n "s/^ *static const String displayVersion = '\([0-9][0-9.]*\)';.*/\1/p" \
  lib/core/constants/app_constants.dart)
pubspec_build=$(sed -n 's/^version: *[0-9][0-9.]*+\([0-9][0-9]*\) *$/\1/p' pubspec.yaml)

if [[ -z "$name" || -z "$pubspec_build" ]]; then
  echo "store_build: displayVersion or pubspec build number not found" >&2
  exit 1
fi

number=$((10#$pubspec_build + STORE_BUILD_OFFSET))  # 10#: leading zeros are not octal
for ionic in "$IONIC_ANDROID_VERSION_CODE" "$IONIC_IOS_BUILD"; do
  if (( number <= ionic )); then
    echo "store_build: build number $number is not above Ionic's $ionic" >&2
    exit 1
  fi
done
if [[ "$(printf '%s\n' "$name" 4.19.9 | sort -V | tail -n1)" != "$name" || "$name" == 4.19.9 ]]; then
  echo "store_build: build name $name is not above Ionic's 4.19.9" >&2
  exit 1
fi

if [[ "${1:-}" == "--print" ]]; then
  echo "--build-name $name --build-number $number"
  exit 0
fi

usage="usage: scripts/store_build.sh <ipa|appbundle|apk|macos-release|patch-ios|patch-android|patch-macos|ios|macos> [flutter build args…]"
target=${1:?$usage}
shift
for arg in "$@"; do
  case "$arg" in
    --build-name|--build-name=*|--build-number|--build-number=*)
      echo "store_build: $arg is set by this script, do not pass it" >&2
      exit 1
      ;;
  esac
done
build_args=(--build-name "$name" --build-number "$number")

# Store builds must come from `shorebird release`, otherwise no OTA patches
# reach the app (docs/release/shorebird.md). Flutter version = the one CI uses.
find_shorebird() {
  if command -v shorebird >/dev/null 2>&1; then
    shorebird=shorebird
  elif [[ -x "$HOME/.shorebird/bin/shorebird" ]]; then
    shorebird="$HOME/.shorebird/bin/shorebird"
  else
    echo "store_build: shorebird not found (neither in PATH nor ~/.shorebird/bin)." >&2
    echo "store_build: store builds need shorebird, see docs/release/shorebird.md" >&2
    exit 1
  fi
}
flutter_version() {
  fv=${SHOREBIRD_FLUTTER_VERSION:-$(sed -n "s/^ *flutter-version: *['\"]\{0,1\}\([0-9][0-9.]*\)['\"]\{0,1\} *$/\1/p" \
    .github/workflows/ci.yml | head -n1)}
  if [[ -z "$fv" ]]; then
    echo "store_build: Flutter version not found in .github/workflows/ci.yml (set SHOREBIRD_FLUTTER_VERSION)" >&2
    exit 1
  fi
}
run() {
  echo "store_build: $*"
  exec "$@"
}

case "$target" in
  appbundle)
    find_shorebird; flutter_version
    run "$shorebird" release android "--flutter-version=$fv" -- "${build_args[@]}" "$@"
    ;;
  apk)
    find_shorebird; flutter_version
    run "$shorebird" release android --artifact apk "--flutter-version=$fv" -- "${build_args[@]}" "$@"
    ;;
  ipa)
    find_shorebird; flutter_version
    run "$shorebird" release ios "--flutter-version=$fv" -- "${build_args[@]}" "$@"
    ;;
  macos-release)
    find_shorebird; flutter_version
    # Unsigned build: keychain-access-groups would need a Mac development
    # profile (this Mac registered as a device in the team). The App Store
    # signature comes later from `xcodebuild -exportArchive`, see
    # docs/release/shorebird.md.
    export FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO FLUTTER_XCODE_CODE_SIGNING_REQUIRED=NO
    run "$shorebird" release macos "--flutter-version=$fv" -- "${build_args[@]}" "$@"
    ;;
  patch-android|patch-ios|patch-macos)
    # A patch only applies to the exact release build (name + number); the
    # Flutter version is taken from that release by shorebird itself. After an
    # internal version bump the current numbers no longer match the store
    # release: then pass it explicitly, e.g. RELEASE_VERSION=5.0.0+241.
    release=${RELEASE_VERSION:-$name+$number}
    if [[ ! "$release" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
      echo "store_build: RELEASE_VERSION must look like 5.0.0+241, got '$release'" >&2
      exit 1
    fi
    find_shorebird
    run "$shorebird" patch "${target#patch-}" "--release-version=$release" -- \
      --build-name "${release%+*}" --build-number "${release##*+}" "$@"
    ;;
  ios|macos)
    echo "store_build: WARNING: plain 'flutter build $target' is NOT a Shorebird release," >&2
    echo "store_build: WARNING: an upload from it gets no OTA patches. Use 'ipa' / 'macos-release' for the App Store." >&2
    run flutter build "$target" --release "${build_args[@]}" "$@"
    ;;
  *)
    echo "store_build: unknown target '$target'" >&2
    echo "$usage" >&2
    exit 1
    ;;
esac
