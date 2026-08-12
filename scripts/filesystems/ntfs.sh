#
# NTFS PBR installer.
#
# NTFS boot-sector layout:
#
#   000-002   JMP
#   003-053   OEM ID / BPB / extended BPB
#   054-059   normally boot code, but preserved here
#   05A-1FF   our boot code + signature
#
# NTFS maintains an alternate copy of the boot sector in the final
# sector of the volume.
#

PARTED_TYPE="ntfs"

filesystem_create()
{
    local dev="$1"

    echo "Creating NTFS filesystem on $dev"

    sudo mkfs.ntfs -F "$dev"
}

filesystem_verify()
{
    local dev="$1"

    echo "Checking boot signature on $dev"
    filesystem_check_signature "$dev"

    echo "Checking NTFS filesystem on $dev"

    sudo ntfsfix -n "$dev"
}



pbr_install()
{
    local dev="$1"
    local pbr="$2"
    local sectors
    local backup_sector

    #
    # Replace initial JMP.
    #

    dev_write_range \
        "$dev" "$pbr" \
        0 0 3 ||
        return 1

    #
    # Preserve filesystem-owned metadata and install our boot code
    # from 0x05A through the end of the sector.
    #

    dev_write_range \
        "$dev" "$pbr" \
        $((0x5A)) $((0x5A)) $((512 - 0x5A)) ||
        return 1

    #
    # NTFS keeps its alternate boot sector at the end of the volume.
    #

    sectors=$(sudo blockdev --getsz "$dev") ||
        return 1

    [ -n "$sectors" ] && [ "$sectors" -gt 0 ] || {
        echo "FAILED: Could not determine NTFS volume size" >&2
        return 1
    }

    backup_sector=$((sectors - 1))

    echo "NTFS alternate boot sector: $backup_sector"

    #
    # Copy our completed primary boot sector to the alternate.
    #

    dev_copy_sector "$dev" 0 "$backup_sector" ||
        return 1

    echo "NTFS primary and alternate boot sectors updated"
}
