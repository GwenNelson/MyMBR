#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/loop-funcs.sh"

IMAGE="${1:-}"

[ -n "$IMAGE" ] ||
    fail "Usage: $0 IMAGE"

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

MBR_SIZE=$(stat -c %s "$REFERENCE_MBR")

[ "$MBR_SIZE" -eq 440 ] || {
    echo "FAILED: Reference MBR must be exactly 440 bytes (got $MBR_SIZE)" >&2
    exit 1
}

#
# Create a sparse 260 MiB disk image.
#
# Layout:
#
#   1-65 MiB      FAT32
#  65-129 MiB     ext2
# 129-193 MiB     NTFS
# 193-257 MiB     FAT16
#

truncate -s 260M "$IMAGE"

# Create MBR partition table
parted -s "$IMAGE" mklabel msdos

# Four 64 MiB primary partitions
parted -s "$IMAGE" mkpart primary fat32 1MiB 65MiB
parted -s "$IMAGE" mkpart primary ext2  65MiB 129MiB
parted -s "$IMAGE" mkpart primary ntfs  129MiB 193MiB
parted -s "$IMAGE" mkpart primary fat16 193MiB 257MiB

#
# Install known-good SYSLINUX reference MBR bootstrap.
#

"$SCRIPT_DIR/install-mbr.sh" \
    "$IMAGE" \
    "$PROJECT_DIR/test/syslinux-mbr.bin"

echo "Installed reference SYSLINUX MBR"

#
# Attach and create filesystems.
#

loop_acquire "$IMAGE"

echo "Image attached as $LOOP"

sudo mkfs.vfat -F 32 "${LOOP}p1"
sudo mkfs.ext2 -F "${LOOP}p2"
sudo mkfs.ntfs -F "${LOOP}p3"
sudo mkfs.vfat -F 16 "${LOOP}p4"

#
# Show resulting layout.
#

sudo fdisk -l "$LOOP"

sudo blkid \
    "${LOOP}p1" \
    "${LOOP}p2" \
    "${LOOP}p3" \
    "${LOOP}p4"
