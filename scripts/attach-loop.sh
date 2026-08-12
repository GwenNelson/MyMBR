#!/bin/bash
set -e

IMAGE="${1:-mbr-test.img}"
STATE=".loop-device"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -f "$IMAGE" ] ||
    fail "Image '$IMAGE' does not exist"

if [ -e "$STATE" ]; then
    LOOP=$(cat "$STATE")

    if [ -b "$LOOP" ] && sudo losetup "$LOOP" >/dev/null 2>&1; then
        echo "$IMAGE already attached as $LOOP"
        exit 0
    fi

    echo "Removing stale loop-device state"
    rm -f "$STATE"
fi

LOOP=$(sudo losetup --find --show --partscan "$IMAGE") ||
    fail "Could not attach '$IMAGE'"

echo "$LOOP" > "$STATE"

echo "$IMAGE attached as $LOOP"
