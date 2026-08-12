#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
STATE="$PROJECT_DIR/.loop-device"

IMAGE="${1:-$PROJECT_DIR/mbr-test.img}"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -f "$IMAGE" ] ||
    fail "Image '$IMAGE' does not exist"

[ ! -e "$STATE" ] ||
    fail "$STATE already exists; detach the existing loop device first"

if [ -t 0 ] && [ -t 1 ]; then
    printf "Attach a new loop device for '%s'? [y/N] " "$IMAGE"
    read -r REPLY

    case "$REPLY" in
        y|Y|yes|YES) ;;
        *) exit 1 ;;
    esac
fi

echo "Attaching new loop device for $IMAGE..." >&2

LOOP=$(sudo losetup --find --show --partscan "$IMAGE") ||
    fail "Could not attach '$IMAGE'"

echo "$LOOP" > "$STATE"

echo "New loop device: $LOOP" >&2
echo "$LOOP"
