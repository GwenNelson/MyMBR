#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/loop-funcs.sh"
source "$SCRIPT_DIR/filesystems/common.sh"

IMAGE="${1:-}"

cleanup()
{
    loop_cleanup
}

fail()
{
    echo
    echo "FAILED: $1"
    exit 1
}

trap cleanup EXIT

[ -n "$IMAGE" ] ||
    fail "Usage: $0 IMAGE"

[ -f "$IMAGE" ] ||
    fail "Image '$IMAGE' does not exist"

echo "Verifying $IMAGE"
echo

loop_acquire "$IMAGE" ||
    fail "Could not acquire loop device"

echo "Using $LOOP"
echo

#
# Partition table
#

echo "=== Partition table ==="

sudo sfdisk --verify "$LOOP" ||
    fail "Partition table verification failed"

#
# Ensure exactly four primary partitions exist.
#

for n in 1 2 3 4; do
    [ -b "${LOOP}p$n" ] ||
        fail "Partition $n is missing"
done

[ ! -b "${LOOP}p5" ] ||
    fail "Unexpected partition 5 exists"

#
# MBR boot signature
#

echo
echo "=== Boot sector signature ==="

filesystem_check_signature "$LOOP" ||
    fail "MBR boot sector signature invalid"

#
# Identify and verify every filesystem.
#

echo
echo "=== Filesystem verification ==="

for n in 1 2 3 4; do
    DEV="${LOOP}p$n"

    echo
    echo "=== Partition $n ==="

    TYPE=$(sudo blkid -s TYPE -o value "$DEV") ||
        fail "Could not identify filesystem on $DEV"

    echo "$DEV: $TYPE"

    filesystem_load "$TYPE" ||
        fail "Unsupported filesystem type '$TYPE' on partition $n"

    declare -F filesystem_verify >/dev/null ||
        fail "Filesystem '$TYPE' does not provide filesystem_verify()"

    filesystem_verify "$DEV" ||
        fail "$TYPE filesystem check failed on partition $n"

    echo "$DEV: $TYPE [OK]"
done

echo
echo "========================================"
echo " ALL CHECKS PASSED"
echo "========================================"

exit 0
