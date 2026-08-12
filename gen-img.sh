#!/bin/bash

# Create 32MB disk image (4 partitions × 8MB)
dd if=/dev/zero of=mbr-test.img bs=1M count=36

# Create MBR partition table
parted -s mbr-test.img mklabel msdos

# Create 4 primary partitions, each 8MB, suitably weird
parted -s mbr-test.img mkpart primary fat32 1MiB 9MiB
parted -s mbr-test.img mkpart primary ext2 9MiB 17MiB
parted -s mbr-test.img mkpart primary ntfs 17MiB 25MiB
parted -s mbr-test.img mkpart primary ext2 25MiB 33MiB

# Verify
parted -l mbr-test.img

