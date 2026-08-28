#!/usr/bin/env bash
# Packages an unsigned .xcarchive into an .ipa that AltStore can install.
#
# The bundle is signed ad-hoc with its real entitlements so that sideloading
# tools can read which capabilities the app needs. AltStore replaces this
# signature with one made from your own Apple ID.
#
# Usage: package-ipa.sh <archive-path> <output.ipa>
set -euo pipefail

ARCHIVE="${1:?archive path required}"
OUTPUT="${2:?output ipa path required}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# zip runs from a staging directory, so the destination has to be absolute.
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

APP_SOURCE="$ARCHIVE/Products/Applications/Bucato.app"
if [ ! -d "$APP_SOURCE" ]; then
  echo "error: $APP_SOURCE not found" >&2
  exit 1
fi

mkdir -p "$STAGE/Payload"
cp -R "$APP_SOURCE" "$STAGE/Payload/Bucato.app"
APP="$STAGE/Payload/Bucato.app"

codesign --force --sign - --timestamp=none \
  --entitlements "$ROOT/Bucato/Support/Bucato.entitlements" \
  "$APP"

rm -f "$OUTPUT"
(cd "$STAGE" && zip -qry "$OUTPUT" Payload)

echo "Wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
