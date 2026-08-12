#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

[ ! -e "$STATE" ] ||
    fail "Loop state already exists for '$IMAGE'; detach it first"

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

#
# Verify what the kernel says before recording it.
#

BACKING=$(sudo losetup -n -O BACK-FILE "$LOOP") ||
    fail "Could not determine backing file for '$LOOP'"

BACKING=$(realpath "$BACKING")

if [ "$BACKING" != "$IMAGE" ]; then
    sudo losetup -d "$LOOP" || true
    fail "$LOOP attached to unexpected backing file '$BACKING'"
fi

printf '%s\n' "$LOOP" > "$STATE"

echo "New loop device: $LOOP" >&2
echo "$LOOP"
