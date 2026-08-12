#
# VFAT dispatcher.
#
# blkid identifies FAT12/FAT16/FAT32 filesystems as "vfat".
# Determine the actual FAT variant from the BPB and dispatch to
# the appropriate filesystem handler.
#

vfat_detect_type()
{
    local dev="$1"

    local bytes_per_sector
    local sectors_per_cluster
    local reserved_sectors
    local fat_count
    local root_entries
    local total16
    local total32
    local fat16_size
    local fat32_size

    local total_sectors
    local fat_size
    local root_dir_sectors
    local data_sectors
    local cluster_count

    bytes_per_sector=$(dev_read_le16 "$dev" 11) || return 1
    sectors_per_cluster=$(dev_read_u8 "$dev" 13) || return 1
    reserved_sectors=$(dev_read_le16 "$dev" 14) || return 1
    fat_count=$(dev_read_u8 "$dev" 16) || return 1
    root_entries=$(dev_read_le16 "$dev" 17) || return 1
    total16=$(dev_read_le16 "$dev" 19) || return 1
    fat16_size=$(dev_read_le16 "$dev" 22) || return 1
    total32=$(dev_read_le32 "$dev" 32) || return 1
    fat32_size=$(dev_read_le32 "$dev" 36) || return 1

    [ "$bytes_per_sector" -gt 0 ] || return 1
    [ "$sectors_per_cluster" -gt 0 ] || return 1

    if [ "$total16" -ne 0 ]; then
	    total_sectors="$total16"
	else
	    total_sectors="$total32"
	fi

	if [ "$fat16_size" -ne 0 ]; then
	    fat_size="$fat16_size"
	else
	    fat_size="$fat32_size"
	fi

	root_dir_sectors=$((
	    (root_entries * 32 + bytes_per_sector - 1) /
	    bytes_per_sector
	))

	data_sectors=$((
	    total_sectors -
	    (
		reserved_sectors +
		fat_count * fat_size +
		root_dir_sectors
	    )
	))

	cluster_count=$((data_sectors / sectors_per_cluster))

	    if [ "$cluster_count" -lt 4085 ]; then
        echo "fat12"
    elif [ "$cluster_count" -lt 65525 ]; then
        echo "fat16"
    else
        echo "fat32"
    fi
}


vfat_dispatch()
{
    local operation="$1"
    local dev="$2"
    shift 2

    local fat_type
    local handler

    fat_type=$(vfat_detect_type "$dev") || {
        echo "FAILED: Could not determine FAT type on $dev" >&2
        return 1
    }

    handler="$FILESYSTEM_DIR/$fat_type.sh"

    [ -f "$handler" ] || {
        echo "FAILED: No handler for $fat_type" >&2
        return 1
    }

    echo "VFAT volume identified as ${fat_type^^}"

    source "$handler" || return 1

    declare -F "$operation" >/dev/null || {
        echo "FAILED: $fat_type does not provide $operation()" >&2
        return 1
    }

    "$operation" "$dev" "$@"
}


pbr_install()
{
    vfat_dispatch pbr_install_fat "$@"
}


filesystem_verify()
{
    vfat_dispatch filesystem_verify_fat "$@"
}


filesystem_onunload()
{
    unset -f vfat_detect_type 2>/dev/null || true
    unset -f vfat_dispatch 2>/dev/null || true

    unset -f pbr_install_fat 2>/dev/null || true
    unset -f filesystem_verify_fat 2>/dev/null || true
    unset -f filesystem_create_fat 2>/dev/null || true
}
