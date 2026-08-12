#
# FAT32 PBR installer.
#
# FAT32 boot-sector layout:
#
#   000-002   JMP + NOP
#   003-059   BPB / extended BPB
#   05A-1FF   boot code + signature
#
# BPB_BkBootSec at offset 0x32 identifies the backup boot sector.
#

pbr_install_fat()
{
    local dev="$1"
    local pbr="$2"
    local backup_sector

    #
    # Replace JMP + NOP.
    #

    pbr_write_range \
        "$dev" "$pbr" \
        0 0 3 ||
        return 1

    #
    # Preserve FAT32 metadata at 0x003-0x059 and replace everything
    # from 0x05A through the end of the boot sector.
    #

    pbr_write_range \
        "$dev" "$pbr" \
        $((0x5A)) $((0x5A)) $((512 - 0x5A)) ||
        return 1

    #
    # Read BPB_BkBootSec from the now-preserved FAT32 BPB.
    #

    backup_sector=$(pbr_read_le16 "$dev" $((0x32))) ||
        return 1

    if [ -z "$backup_sector" ] || [ "$backup_sector" -eq 0 ]; then
        echo "FAILED: FAT32 BPB contains no valid backup boot sector" >&2
        return 1
    fi

    echo "FAT32 backup boot sector: $backup_sector"

    #
    # The primary boot sector is now authoritative and internally
    # complete. Copy it to FAT32's backup boot sector.
    #

    pbr_copy_sector "$dev" 0 "$backup_sector" ||
        return 1

    echo "FAT32 primary and backup boot sectors updated"
}
