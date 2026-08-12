#!/usr/bin/env bash

set -euo pipefail


if [ "$#" -ne 2 ]; then
    echo "Usage: $0 IMAGE PARTITION" >&2
    exit 2
fi


IMAGE=$1
PARTITION=$2


case "$PARTITION" in
    1|2|3|4)
        ;;
    *)
        echo "FAILED: partition must be 1, 2, 3 or 4" >&2
        exit 2
        ;;
esac


EXPECTED="PBR_TEST_OK:$PARTITION"


#
# Temporary directory for the QEMU serial pipe.
#

TMPDIR=$(mktemp -d)

SERIAL="$TMPDIR/serial"
OUTPUT="$TMPDIR/output"


cleanup()
{
    rm -rf "$TMPDIR"
}

trap cleanup EXIT


#
# QEMU's pipe backend expects these two FIFOs.
#

mkfifo "$SERIAL.in"
mkfifo "$SERIAL.out"


#
# Keep both ends open ourselves so QEMU doesn't block while opening
# its pipe backend.
#

exec 3<>"$SERIAL.in"
exec 4<>"$SERIAL.out"


#
# Run QEMU.
#
# COM1 is connected to our pipe.
#
# Port E9/debugcon remains stdout, which is where the test PBR writes
# PBR_TEST_OK:n.
#
# Do NOT use -snapshot here: my-mbr deliberately writes the selected
# active partition back to the real test image, and the caller verifies
# that change afterwards.
#

set +e

timeout --signal=TERM 3 \
    qemu-system-i386 \
        -drive "file=$IMAGE,format=raw" \
        -display none \
        -monitor none \
        -serial "pipe:$SERIAL" \
        -debugcon stdio \
        >"$OUTPUT" 2>/dev/null &

QEMU_PID=$!

set -e


#
# Give QEMU/BIOS a moment to reach my-mbr.
#
# Writing earlier would normally just leave the byte waiting in the
# UART, but this also avoids racing QEMU's chardev setup.
#

sleep 0.25


#
# Send the selector character to COM1.
#
# No newline is required.
#

printf '%s' "$PARTITION" >&3


#
# Wait for QEMU/timeout.
#

set +e

wait "$QEMU_PID"
STATUS=$?

set -e


#
# timeout normally returns 124 when it terminates QEMU after the
# allotted test period. That's expected.
#

if [ "$STATUS" -ne 0 ] && [ "$STATUS" -ne 124 ]; then
    echo "FAILED: QEMU terminated unexpectedly (status $STATUS)" >&2
    exit 1
fi


RECEIVED=$(tr -d '\r\n' < "$OUTPUT")


echo "Expected:"
echo "  <$EXPECTED>"
echo "Received:"
echo "  <$RECEIVED>"


if [ "$RECEIVED" != "$EXPECTED" ]; then
    echo "FAILED: Unexpected QEMU debug output" >&2
    exit 1
fi


echo "QEMU boot test [OK]"
