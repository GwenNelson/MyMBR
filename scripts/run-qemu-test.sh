#!/bin/bash

IMAGE="${1:-}"
EXPECTED="${2:-}"
TIMEOUT="3"

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

EXPECTED_OUTPUT="PBR_TEST_OK:$EXPECTED"


OUTPUT_FILE=$(mktemp)

cleanup()
{
    rm -f "$OUTPUT_FILE"
}

trap cleanup EXIT

timeout --signal=TERM "$TIMEOUT" \
    qemu-system-i386 \
    -drive "file=$IMAGE,format=raw" \
    -display none \
    -monitor none \
    -no-reboot \
    -no-shutdown \
    -debugcon "file:$OUTPUT_FILE" \
    2>/dev/null

STATUS=$?

OUTPUT=$(cat "$OUTPUT_FILE")

# QEMU is expected to be killed by timeout because our PBR deliberately
# hangs after reporting success.
#
# GNU timeout returns 124 when the timeout expires.
if [ "$STATUS" -ne 124 ]; then
    fail "QEMU terminated unexpectedly (status $STATUS)"
fi

# Strip CR because serial routines often emit CRLF.
OUTPUT=$(printf '%s' "$OUTPUT" | tr -d '\r')

if [ "$OUTPUT" != "$EXPECTED_OUTPUT" ]; then
    echo "Expected:"
    printf '  <%s>\n' "$EXPECTED_OUTPUT"
    echo "Received:"
    printf '  <%s>\n' "$OUTPUT"
    fail "Unexpected QEMU serial output"
fi

echo "PBR $EXPECTED executed successfully [OK]"
exit 0
