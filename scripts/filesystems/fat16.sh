#
# FAT16 PBR installer.
#
# FAT16 boot-sector layout:
#
#   000-002   JMP + NOP
#   003-03D   BPB / extended BPB
#   03E-1FF   boot code + signature
#
# Our PBR deliberately places its boot code at 0x5A, so we preserve
# 0x003-0x059. This is larger than FAT16 requires, but allows the same
# generated PBR layout to be used across our test filesystems.
#
# Unlike FAT32, FAT16 has no BPB-defined backup boot sector.
#

PARTED_TYPE="fat16"

filesystem_create()
{
    local dev="$1"
    local type="$2"

    echo "Creating FAT16 filesystem on $dev"

    sudo mkfs.vfat -F 16 "$dev"
}

filesystem_verify_fat()
{
    local dev="$1"

    echo "Checking boot sector signature on $dev"
    filesystem_check_signature "$dev"

    echo "Checking FAT16 filesystem on $dev"

    sudo fsck.fat -n "$dev"
}



pbr_install_fat()
{
    local dev="$1"
    local pbr="$2"

    #
    # Replace JMP + NOP.
    #

    dev_write_range \
        "$dev" "$pbr" \
        0 0 3 ||
        return 1

    #
    # Preserve the existing FAT16 BPB / extended BPB and install our
    # boot code from 0x5A through the end of the sector.
    #

    dev_write_range \
        "$dev" "$pbr" \
        $((0x5A)) $((0x5A)) $((512 - 0x5A)) ||
        return 1

    echo "FAT16 boot sector updated"
}

