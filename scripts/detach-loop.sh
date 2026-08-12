#!/bin/bash
set -euo pipefail

IMAGE="${1:-}"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -n "$IMAGE" ] ||
    fail "Usage: $0 IMAGE"

[ -f "$IMAGE" ] ||
    fail "Image '$IMAGE' does not exist"

IMAGE=$(realpath "$IMAGE")
STATE="${IMAGE}.loop-device"

[ -f "$STATE" ] ||
    fail "No loop device recorded for '$IMAGE'"

LOOP=$(cat "$STATE")

[ -b "$LOOP" ] ||
    fail "Recorded loop device '$LOOP' does not exist"

#
# Never detach something merely because the state file says so.
# Ask the kernel what this loop device is actually attached to.
#

BACKING=$(sudo losetup -n -O BACK-FILE "$LOOP") ||
    fail "Could not determine backing file for '$LOOP'"

BACKING=$(realpath "$BACKING")

[ "$BACKING" = "$IMAGE" ] ||
    fail "$LOOP is attached to '$BACKING', not '$IMAGE'; refusing to detach"

echo "Detaching $LOOP from $IMAGE..." >&2

sudo losetup -d "$LOOP" ||
    fail "Could not detach $LOOP"

rm -f "$STATE"

echo "$LOOP detached" >&2
