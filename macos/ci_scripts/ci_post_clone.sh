#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
exec "$REPO_ROOT/scripts/xcode_cloud_post_clone.sh" macos
