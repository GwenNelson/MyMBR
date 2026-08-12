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

SIG=$(
    dd if="$PBR" bs=1 skip=510 count=2 status=none |
    od -An -tx1 |
    tr -d ' \n'
)

[ "$SIG" = "55aa" ] ||
    fail "PBR does not have a 55 AA signature"

#
# Acquire the image's loop device.
#

loop_acquire "$IMAGE" ||
    fail "Could not acquire loop device"

DEV="${LOOP}p${PART}"

[ -b "$DEV" ] ||
    fail "Partition device '$DEV' does not exist"

#
# Identify filesystem.
#

TYPE=$(sudo blkid -s TYPE -o value "$DEV") ||
    fail "Could not identify filesystem on $DEV"

case "$TYPE" in
    vfat)
        #
        # FAT32 has BPB_FATSz16 == 0. We'll add proper FAT12/16
        # dispatch later.
        #
        FATSZ16=$(sudo dd if="$DEV" bs=1 skip=$((0x16)) count=2 status=none |
                  od -An -tu2 |
                  tr -d ' ')

        if [ "$FATSZ16" -eq 0 ]; then
            HANDLER="$SCRIPT_DIR/pbr/fat32.sh"
        else
            fail "FAT12/FAT16 PBR installation is not supported yet"
        fi
        ;;

    *)
        HANDLER="$SCRIPT_DIR/pbr/$TYPE.sh"
        ;;
esac

[ -f "$HANDLER" ] ||
    fail "Unsupported filesystem type '$TYPE'"

source "$SCRIPT_DIR/pbr/common.sh"
source "$HANDLER"

echo "Installing $PBR into partition $PART ($TYPE)"

pbr_install "$DEV" "$PBR" ||
    fail "PBR installation failed"

sync

echo "PBR $PART installed [OK]"
