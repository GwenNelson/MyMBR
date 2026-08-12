#!/bin/bash
set -e

IMAGE=mbr-test.img
LOOP=""

cleanup()
{
    if [ -n "$LOOP" ]; then
        sudo losetup -d "$LOOP"
    fi
}

trap cleanup EXIT

# Create 36MB disk image (4 partitions × 8MB, plus alignment/slack)
dd if=/dev/zero of="$IMAGE" bs=1M count=36

# Create MBR partition table
parted -s "$IMAGE" mklabel msdos

# Create 4 primary partitions, each 8MB, suitably weird
parted -s "$IMAGE" mkpart primary fat32 1MiB 9MiB
parted -s "$IMAGE" mkpart primary ext2 9MiB 17MiB
parted -s "$IMAGE" mkpart primary ntfs 17MiB 25MiB
parted -s "$IMAGE" mkpart primary ext2 25MiB 33MiB

# Attach image and have the kernel expose its partitions
LOOP=$(sudo losetup --find --show --partscan "$IMAGE")

echo "Image attached as $LOOP"

# Create the filesystems
sudo mkfs.vfat -F 32 "${LOOP}p1"
sudo mkfs.ext2 -F "${LOOP}p2"
sudo mkfs.ntfs -F "${LOOP}p3"
sudo mkfs.ext2 -F "${LOOP}p4"

# Show what we've made
sudo fdisk -l "$LOOP"
sudo blkid "${LOOP}p1" "${LOOP}p2" "${LOOP}p3" "${LOOP}p4"

# cleanup trap detaches LOOP
