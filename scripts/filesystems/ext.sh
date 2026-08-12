PARTED_TYPE="ext2"

filesystem_create()
{
    local dev="$1"

    echo "Creating $FILESYSTEM_TYPE filesystem on $dev"

    sudo "mkfs.$FILESYSTEM_TYPE" -F "$dev"
}

filesystem_verify()
{
    local dev="$1"

    echo "Checking ext filesystem on $dev"

    sudo e2fsck -fn "$dev"
}

pbr_install()
{
    local dev="$1"
    local pbr="$2"

    dev_write_range \
        "$dev" "$pbr" \
        0 0 512
}

filesystem_onunload() {
    unset FILESYSTEM_TYPE
}
