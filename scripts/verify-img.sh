#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/loop-funcs.sh"

IMAGE="${1:-$PROJECT_DIR/mbr-test.img}"

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

if [ ! -f "$IMAGE" ]; then
    fail "Image '$IMAGE' does not exist"
fi

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

# Ensure exactly the four expected partitions exist.
for n in 1 2 3 4; do
    [ -b "${LOOP}p$n" ] ||
        fail "Partition $n is missing"
done

[ ! -b "${LOOP}p5" ] ||
    fail "Unexpected partition 5 exists"

#
# Filesystem identification
#

check_type()
{
    DEV="$1"
    EXPECTED="$2"

    ACTUAL=$(sudo blkid -s TYPE -o value "$DEV") ||
        fail "Could not identify filesystem on $DEV"

    if [ "$ACTUAL" != "$EXPECTED" ]; then
        fail "$DEV: expected $EXPECTED, found ${ACTUAL:-nothing}"
    fi

    echo "$DEV: $ACTUAL [OK]"
}

check_signature()
{
    DEV="$1"

    SIG=$(sudo dd if="$DEV" bs=1 skip=510 count=2 status=none |
          od -An -tx1 |
          tr -d ' \n')

    [ "$SIG" = "55aa" ] ||
        fail "$DEV: invalid boot-sector signature ($SIG)"

    echo "$DEV: boot signature 55 AA [OK]"
}

echo
echo "=== Boot sector signatures ==="
check_signature "${LOOP}"     # MBR itself
check_signature "${LOOP}p1"   # FAT32
check_signature "${LOOP}p3"   # NTFS
check_signature "${LOOP}p4"   # FAT16

echo
echo "=== Filesystem identification ==="

check_type "${LOOP}p1" "vfat"
check_type "${LOOP}p2" "ext2"
check_type "${LOOP}p3" "ntfs"
check_type "${LOOP}p4" "vfat"

#
# Filesystem consistency
#

echo
echo "=== FAT32: partition 1 ==="

sudo fsck.vfat -n "${LOOP}p1" ||
    fail "FAT32 filesystem check failed on partition 1"

echo
echo "=== ext2: partition 2 ==="

sudo e2fsck -fn "${LOOP}p2" ||
    fail "ext2 filesystem check failed on partition 2"

echo
echo "=== NTFS: partition 3 ==="

sudo ntfsfix -n "${LOOP}p3" ||
    fail "NTFS filesystem check failed on partition 3"

echo
echo "=== FAT16: partition 4 ==="

sudo fsck.vfat -n "${LOOP}p4" ||
    fail "FAT16 filesystem check failed on partition 4"

echo
echo "========================================"
echo " ALL CHECKS PASSED"
echo "========================================"

exit 0
