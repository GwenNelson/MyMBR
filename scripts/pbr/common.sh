#
# Common PBR installation functions.
#

pbr_write_range()
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

pbr_copy_sector()
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


pbr_read_le16()
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
