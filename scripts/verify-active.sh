#!/bin/bash

IMAGE="${1:-}"
EXPECTED="${2:-}"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -n "$IMAGE" ] || fail "Usage: $0 IMAGE PARTITION"
[ -f "$IMAGE" ] || fail "Image '$IMAGE' does not exist"

case "$EXPECTED" in
    1|2|3|4) ;;
    *) fail "Partition must be 1, 2, 3 or 4" ;;
esac

for n in 1 2 3 4; do
    OFFSET=$((0x1BE + (n - 1) * 16))

    VALUE=$(
        dd if="$IMAGE" bs=1 skip="$OFFSET" count=1 status=none |
        od -An -tx1 |
        tr -d ' \n'
    )

    if [ "$n" -eq "$EXPECTED" ]; then
        [ "$VALUE" = "80" ] ||
            fail "Partition $n should be active, but flag is 0x$VALUE"
    else
        [ "$VALUE" = "00" ] ||
            fail "Partition $n should be inactive, but flag is 0x$VALUE"
    fi
done

echo "Active partition is $EXPECTED [OK]"
exit 0
