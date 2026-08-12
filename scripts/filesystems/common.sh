#
# Common filesystem handling and PBR primitives.
#

FILESYSTEM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


#
# Remove anything exported by the previously loaded filesystem handler.
#
# Keep this list here as the filesystem-handler interface grows.
#

filesystem_unload()
{
    unset PARTED_TYPE

    unset -f filesystem_create 2>/dev/null || true
    unset -f filesystem_verify 2>/dev/null || true
    unset -f pbr_install 2>/dev/null || true
    unset -f pbr_install_fat 2>/dev/null || true
}


#
# Load a filesystem handler.
#
# Usage:
#
#   filesystem_load fat32
#   filesystem_load ntfs
#
# The handler may export:
#
#   PARTED_TYPE
#   filesystem_create()
#   filesystem_verify()
#   pbr_install()
#

filesystem_load()
{
    local type="${1:-}"
    local handler

    [ -n "$type" ] || {
        echo "FAILED: filesystem_load requires a filesystem type" >&2
        return 1
    }

    handler="$FILESYSTEM_DIR/$type.sh"

    [ -f "$handler" ] || {
        echo "FAILED: unsupported filesystem type '$type'" >&2
        return 1
    }

    filesystem_unload

    source "$handler" || {
        echo "FAILED: could not load filesystem handler '$handler'" >&2
        return 1
    }

    return 0
}


#
# Write a range from an image to a filesystem device.
#

dev_write_range()
{
    local dev="$1"
    local pbr="$2"
    local src_offset="$3"
    local dst_offset="$4"
    local length="$5"

    sudo dd \
        if="$pbr" \
        of="$dev" \
        bs=1 \
        skip="$src_offset" \
        seek="$dst_offset" \
        count="$length" \
        conv=notrunc \
        status=none
}


#
# Copy one sector within a filesystem device.
#

dev_copy_sector()
{
    local dev="$1"
    local src_sector="$2"
    local dst_sector="$3"

    sudo dd \
        if="$dev" \
        bs=512 \
        skip="$src_sector" \
        count=1 \
        status=none |
    sudo dd \
        of="$dev" \
        bs=512 \
        seek="$dst_sector" \
        count=1 \
        conv=notrunc \
        status=none
}


dev_read_u8()
{
    local dev="$1"
    local offset="$2"

    sudo dd \
        if="$dev" \
        bs=1 \
        skip="$offset" \
        count=1 \
        status=none |
    od -An -tu1 |
    tr -d ' '
}


dev_read_le16()
{
    local dev="$1"
    local offset="$2"

    sudo dd \
        if="$dev" \
        bs=1 \
        skip="$offset" \
        count=2 \
        status=none |
    od -An -tu2 |
    tr -d ' '
}


dev_read_le32()
{
    local dev="$1"
    local offset="$2"

    sudo dd \
        if="$dev" \
        bs=1 \
        skip="$offset" \
        count=4 \
        status=none |
    od -An -tu4 |
    tr -d ' '
}
