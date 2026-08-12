#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/loop-funcs.sh"
source "$SCRIPT_DIR/filesystems/common.sh"

IMAGE="${1:-}"
LAYOUT="${2:-}"

[ -n "$IMAGE" ] && [ -n "$LAYOUT" ] ||
    fail "Usage: $0 IMAGE LAYOUT"

[ -f "$LAYOUT" ] ||
    fail "Layout '$LAYOUT' does not exist"

source "$LAYOUT"

[ -n "${IMAGE_SIZE:-}" ] ||
    fail "Layout does not define IMAGE_SIZE"

declare -p PARTITIONS &>/dev/null ||
    fail "Layout does not define PARTITIONS"

[ "${#PARTITIONS[@]}" -eq 4 ] ||
    fail "Layout must define exactly four partitions"


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


# create image
truncate -s "$IMAGE_SIZE" "$IMAGE"

# Create MBR partition table
parted -s "$IMAGE" mklabel msdos

# create partitions according to the provided layout

for entry in "${PARTITIONS[@]}"; do
    read -r type start end extra <<< "$entry"

    [ -n "$type" ] &&
    [ -n "$start" ] &&
    [ -n "$end" ] &&
    [ -z "$extra" ] ||
        fail "Invalid partition entry: '$entry'"

    filesystem_load "$type" ||
        fail "Unsupported filesystem '$type'"

    [ -n "${PARTED_TYPE:-}" ] ||
        fail "Filesystem '$type' does not define PARTED_TYPE"

    parted -s "$IMAGE" \
        mkpart primary "$PARTED_TYPE" "$start" "$end" ||
        fail "Could not create $type partition"
done

#
# Install reference MBR bootstrap.
#

"$SCRIPT_DIR/install-mbr.sh" \
    "$IMAGE" \
    "$REFERENCE_MBR"

echo "Installed reference  MBR"

#
# Attach and create filesystems.
#

loop_acquire "$IMAGE" ||
    fail "Could not acquire loop device"

echo "Image attached as $LOOP"

part=1

for entry in "${PARTITIONS[@]}"; do
    read -r type start end <<< "$entry"

    DEV="${LOOP}p${part}"

    [ -b "$DEV" ] ||
        fail "Partition device '$DEV' does not exist"

    filesystem_load "$type" ||
        fail "Unsupported filesystem '$type'"

    declare -F filesystem_create >/dev/null ||
        fail "Filesystem '$type' does not provide filesystem_create()"

    filesystem_create "$DEV" ||
        fail "Could not create $type filesystem on partition $part"

    ((part++))
done


#
# Show resulting layout.
#

sudo fdisk -l "$LOOP"

sudo blkid \
    "${LOOP}p1" \
    "${LOOP}p2" \
    "${LOOP}p3" \
    "${LOOP}p4"
