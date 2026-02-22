#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOWNLOAD_URL="https://library.ldraw.org/library/updates/complete.zip"
ZIP_FILE="$REPO_ROOT/complete.zip"

cleanup() {
    rm -f "$ZIP_FILE"
}
trap cleanup EXIT

echo "Downloading LDraw complete library from $DOWNLOAD_URL ..."
curl -fL -o "$ZIP_FILE" "$DOWNLOAD_URL"

echo "Unzipping into repository root ..."
unzip -o "$ZIP_FILE" -d "$REPO_ROOT"

echo "Committing changes ..."
cd "$REPO_ROOT"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add ldraw/
git diff --cached --quiet || git commit -m "chore: update LDraw library [skip ci]"

echo "Done."
