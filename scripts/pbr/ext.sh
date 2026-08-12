#
# Common ext2/ext3/ext4 PBR installer.
#
# ext-family filesystems reserve the first 1024 bytes for bootloader use.
# The superblock begins at byte 1024.
#
# Our 512-byte PBR therefore occupies only the first half of the
# filesystem's reserved boot area.
#

pbr_install()
{
    local dev="$1"
    local pbr="$2"

    pbr_write_range \
        "$dev" "$pbr" \
        0 0 512 ||
        return 1

    echo "ext-family boot sector updated"
}
