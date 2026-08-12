#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
STATE="$PROJECT_DIR/.loop-device"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -f "$STATE" ] ||
    fail "No loop device recorded"

LOOP=$(cat "$STATE")

echo "Detaching $LOOP..." >&2

sudo losetup -d "$LOOP" ||
    fail "Could not detach $LOOP"

rm -f "$STATE"

echo "$LOOP detached" >&2
