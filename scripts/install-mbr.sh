#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

IMAGE="${1:-}"
MBR="${2:-}"

fail()
{
    echo "FAILED: $1" >&2
    exit 1
}

[ -n "$IMAGE" ] && [ -n "$MBR" ] ||
    fail "Usage: $0 IMAGE MBR"

[ -f "$IMAGE" ] ||
    fail "Image '$IMAGE' does not exist"

[ -f "$MBR" ] ||
    fail "MBR '$MBR' does not exist"

#
# We deliberately accept only the 440-byte executable portion of an MBR.
#
#   000-1B7   bootstrap code          <- replaced
#   1B8-1BD   disk signature/reserved <- preserved
#   1BE-1FD   partition table         <- preserved
#   1FE-1FF   55 AA signature         <- preserved
#

SIZE=$(stat -c %s "$MBR") ||
    fail "Could not determine size of '$MBR'"

[ "$SIZE" -eq 440 ] ||
    fail "MBR bootcode must be exactly 440 bytes (got $SIZE)"

echo "Installing MBR bootcode from $MBR"

dd \
    if="$MBR" \
    of="$IMAGE" \
    bs=440 \
    count=1 \
    conv=notrunc \
    status=none

sync

echo "MBR bootcode installed [OK]"
