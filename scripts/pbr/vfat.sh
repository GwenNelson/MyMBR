#
# VFAT PBR dispatcher.
#
# Determines whether the volume is FAT12, FAT16 or FAT32 from its
# cluster count, then loads the appropriate filesystem-specific handler.
#

pbr_install()
{
    local dev="$1"
    local pbr="$2"

    local bytes_per_sector
    local sectors_per_cluster
    local reserved_sectors
    local number_of_fats
    local root_entries
    local total_sectors_16
    local total_sectors_32
    local fat_size_16
    local fat_size_32

    local total_sectors
    local fat_size
    local root_dir_sectors
    local data_sectors
    local cluster_count
    local fat_type
    local handler

    bytes_per_sector=$(pbr_read_le16 "$dev" $((0x0B))) ||
        return 1

    sectors_per_cluster=$(pbr_read_u8 "$dev" $((0x0D))) ||
        return 1

    reserved_sectors=$(pbr_read_le16 "$dev" $((0x0E))) ||
        return 1

    number_of_fats=$(pbr_read_u8 "$dev" $((0x10))) ||
        return 1

    root_entries=$(pbr_read_le16 "$dev" $((0x11))) ||
        return 1

    total_sectors_16=$(pbr_read_le16 "$dev" $((0x13))) ||
        return 1

    fat_size_16=$(pbr_read_le16 "$dev" $((0x16))) ||
        return 1

    total_sectors_32=$(pbr_read_le32 "$dev" $((0x20))) ||
        return 1

    fat_size_32=$(pbr_read_le32 "$dev" $((0x24))) ||
        return 1

    if [ "$total_sectors_16" -ne 0 ]; then
        total_sectors="$total_sectors_16"
    else
        total_sectors="$total_sectors_32"
    fi

    if [ "$fat_size_16" -ne 0 ]; then
        fat_size="$fat_size_16"
    else
        fat_size="$fat_size_32"
    fi

    root_dir_sectors=$(( (root_entries * 32 + bytes_per_sector - 1) /
                         bytes_per_sector ))

    data_sectors=$(( total_sectors -
                     reserved_sectors -
                     number_of_fats * fat_size -
                     root_dir_sectors ))

    cluster_count=$((data_sectors / sectors_per_cluster))


    if [ "$cluster_count" -lt 4085 ]; then
        fat_type="fat12"
    elif [ "$cluster_count" -lt 65525 ]; then
        fat_type="fat16"
    else
        fat_type="fat32"
    fi

    echo "VFAT volume identified as ${fat_type^^} ($cluster_count clusters)"

    handler="$SCRIPT_DIR/pbr/$fat_type.sh"

    [ -f "$handler" ] || {
        echo "FAILED: ${fat_type^^} PBR installation is not supported yet" >&2
        return 1
    }

    source "$handler"

    pbr_install_fat "$dev" "$pbr"
}
