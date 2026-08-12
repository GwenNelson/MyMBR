#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/loop-funcs.sh"

IMAGE="${1:-}"
PART="${2:-}"
PBR="${3:-}"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

cleanup()
{
    loop_cleanup
}

trap cleanup EXIT

[ -n "$IMAGE" ] && [ -n "$PART" ] && [ -n "$PBR" ] ||
    fail "Usage: $0 IMAGE PARTITION PBR"

[ -f "$IMAGE" ] ||
    fail "Image '$IMAGE' does not exist"

[ -f "$PBR" ] ||
    fail "PBR '$PBR' does not exist"

case "$PART" in
    1|2|3|4) ;;
    *) fail "Partition must be 1, 2, 3 or 4" ;;
esac

SIZE=$(stat -c %s "$PBR")

[ "$SIZE" -eq 512 ] ||
    fail "PBR must be exactly 512 bytes (got $SIZE)"

#
# Validate our input PBR.
#

SIG=$(dd if="$PBR" bs=1 skip=510 count=2 status=none |
      od -An -tx1 |
      tr -d ' \n')

[ "$SIG" = "55aa" ] ||
    fail "PBR does not have a 55 AA signature"

#
# Acquire image loop device.
#

loop_acquire "$IMAGE" ||
    fail "Could not acquire loop device"

DEV="${LOOP}p${PART}"

[ -b "$DEV" ] ||
    fail "Partition device '$DEV' does not exist"

echo "Installing $PBR into partition $PART"

#
# Install JMP + NOP.
# 000-002: ours
#

sudo dd \
    if="$PBR" \
    of="$DEV" \
    bs=1 \
    count=3 \
    conv=notrunc \
    status=none

#
# 003-059: filesystem-owned, preserve.
# 05A-1FF: ours
#

sudo dd \
    if="$PBR" \
    of="$DEV" \
    bs=1 \
    skip=$((0x5A)) \
    seek=$((0x5A)) \
    count=$((512 - 0x5A)) \
    conv=notrunc \
    status=none

sync

echo "PBR $PART installed [OK]"
