#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <version> <title> <body-file> <output-dir>" >&2
  exit 2
fi

VERSION="$1"
TITLE="$2"
BODY_FILE="$3"
OUTPUT_DIR="$4"

mkdir -p "$OUTPUT_DIR"

NOTES_MD="$OUTPUT_DIR/OpenASO-$VERSION.dmg.md"
GITHUB_MD="$OUTPUT_DIR/github-release-notes.md"

{
  echo "# $TITLE"
  echo
  cat "$BODY_FILE"
} > "$NOTES_MD"

cp "$NOTES_MD" "$GITHUB_MD"

echo "$NOTES_MD"
