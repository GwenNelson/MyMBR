#!/bin/bash
set -e

STATE=".loop-device"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -e "$STATE" ] ||
    fail "No loop device is currently recorded"

LOOP=$(cat "$STATE")

if [ -b "$LOOP" ]; then
    sudo losetup -d "$LOOP" ||
        fail "Could not detach $LOOP"
else
    echo "Warning: $LOOP no longer exists"
fi

rm -f "$STATE"

echo "$LOOP detached"
