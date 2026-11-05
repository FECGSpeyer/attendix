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
# Usage: scripts/store_build.sh <ipa|appbundle|apk|ios|macos> [flutter build args…]
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

number=$((pubspec_build + STORE_BUILD_OFFSET))
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

target=${1:?usage: scripts/store_build.sh <ipa|appbundle|apk|ios|macos> [flutter build args…]}
shift
echo "store_build: flutter build $target --release --build-name $name --build-number $number $*"
exec flutter build "$target" --release --build-name "$name" --build-number "$number" "$@"
