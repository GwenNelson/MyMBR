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
    #
    # Give the current handler a chance to remove any private
    # functions or variables it exported.
    #

    if declare -F filesystem_onunload >/dev/null; then
        filesystem_onunload
    fi

    #
    # Remove the standard filesystem-handler interface.
    #

    unset PARTED_TYPE

    unset -f filesystem_create 2>/dev/null || true
    unset -f filesystem_verify 2>/dev/null || true
    unset -f pbr_install 2>/dev/null || true
    unset -f filesystem_onunload 2>/dev/null || true
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

    FILESYSTEM_TYPE="$type"

    source "$handler" || {
        echo "FAILED: could not load filesystem handler '$handler'" >&2
        filesystem_unload
        return 1
    }
}



filesystem_check_signature()
{
    DEV="$1"

    SIG=$(sudo dd if="$DEV" bs=1 skip=510 count=2 status=none |
          od -An -tx1 |
          tr -d ' \n')

    [ "$SIG" = "55aa" ] || {
        echo "$DEV: invalid boot-sector signature ($SIG)"
        return 1
    }

    echo "$DEV: boot signature 55 AA [OK]"
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
