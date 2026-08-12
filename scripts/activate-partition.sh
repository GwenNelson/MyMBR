#!/bin/bash
set -e

IMAGE="${1:-}"
PART="${2:-}"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -n "$IMAGE" ] || fail "Usage: $0 IMAGE PARTITION"
[ -f "$IMAGE" ] || fail "Image '$IMAGE' does not exist"

case "$PART" in
    1|2|3|4) ;;
    *) fail "Partition must be 1, 2, 3 or 4" ;;
esac

# MBR partition table starts at 0x1BE.
# Each entry is 16 bytes and its first byte is the active flag.
for n in 1 2 3 4; do
    OFFSET=$((0x1BE + (n - 1) * 16))

    if [ "$n" -eq "$PART" ]; then
        VALUE='\x80'
    else
        VALUE='\x00'
    fi

    printf "$VALUE" |
        dd of="$IMAGE" bs=1 seek="$OFFSET" count=1 conv=notrunc status=none
done

echo "Activated partition $PART"
