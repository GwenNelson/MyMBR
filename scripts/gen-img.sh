#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/loop-funcs.sh"

IMAGE="$PROJECT_DIR/mbr-test.img"
REFERENCE_MBR="$PROJECT_DIR/test/syslinux-mbr.bin"

cleanup()
{
    loop_cleanup
}

trap cleanup EXIT

[ -f "$REFERENCE_MBR" ] || {
    echo "FAILED: Reference MBR '$REFERENCE_MBR' does not exist" >&2
    exit 1
}

# Create 36MB disk image (4 partitions × 8MB, plus alignment/slack)
dd if=/dev/zero of="$IMAGE" bs=1M count=36

# Create MBR partition table
parted -s "$IMAGE" mklabel msdos

# Create 4 primary partitions, each 8MB, suitably weird
parted -s "$IMAGE" mkpart primary fat32 1MiB 9MiB
parted -s "$IMAGE" mkpart primary ext2 9MiB 17MiB
parted -s "$IMAGE" mkpart primary ntfs 17MiB 25MiB
parted -s "$IMAGE" mkpart primary ext2 25MiB 33MiB

#
# Install known-good reference MBR bootstrap.
#
# syslinux-mbr.bin is exactly 440 bytes, covering offsets 0x000-0x1B7.
# This deliberately leaves the disk signature/reserved area and partition
# table untouched.
#

MBR_SIZE=$(stat -c %s "$REFERENCE_MBR")

[ "$MBR_SIZE" -eq 440 ] || {
    echo "FAILED: Reference MBR must be exactly 440 bytes (got $MBR_SIZE)" >&2
    exit 1
}

dd \
    if="$REFERENCE_MBR" \
    of="$IMAGE" \
    bs=440 \
    count=1 \
    conv=notrunc \
    status=none

echo "Installed reference SYSLINUX MBR"

# Attach image and have the kernel expose its partitions
loop_acquire "$IMAGE"

echo "Image attached as $LOOP"

# Create the filesystems
sudo mkfs.vfat -F 32 "${LOOP}p1"
sudo mkfs.ext2 -F "${LOOP}p2"
sudo mkfs.ntfs -F "${LOOP}p3"
sudo mkfs.ext2 -F "${LOOP}p4"

# Show what we've made
sudo fdisk -l "$LOOP"
sudo blkid "${LOOP}p1" "${LOOP}p2" "${LOOP}p3" "${LOOP}p4"
