#!/bin/bash

IMAGE="${1:-mbr-test.img}"
LOOP=""

cleanup()
{
    if [ -n "$LOOP" ]; then
        sudo losetup -d "$LOOP"
    fi
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

# Attach image and scan its partition table
LOOP=$(sudo losetup --find --show --partscan "$IMAGE") ||
    fail "Could not attach image"

echo "Attached as $LOOP"
echo

# Verify MBR partition table
echo "=== Partition table ==="
sudo sfdisk --verify "$LOOP" ||
    fail "Partition table verification failed"

# Make sure all four expected partitions actually exist
for n in 1 2 3 4; do
    [ -b "${LOOP}p$n" ] ||
        fail "Partition $n is missing"
done

echo
echo "=== FAT32: partition 1 ==="
sudo fsck.vfat -n "${LOOP}p1" ||
    fail "FAT32 filesystem check failed"

echo
echo "=== ext2: partition 2 ==="
sudo e2fsck -fn "${LOOP}p2" ||
    fail "ext2 filesystem check failed on partition 2"

echo
echo "=== NTFS: partition 3 ==="
sudo ntfsfix -n "${LOOP}p3" ||
    fail "NTFS filesystem check failed"

echo
echo "=== ext2: partition 4 ==="
sudo e2fsck -fn "${LOOP}p4" ||
    fail "ext2 filesystem check failed on partition 4"

echo
echo "========================================"
echo " ALL CHECKS PASSED"
echo "========================================"
