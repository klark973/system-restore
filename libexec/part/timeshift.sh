###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

############################################################
### The "timeshift" disk partitioning in deployment mode ###
############################################################

readonly BTRFS_PARTNAME="${BTRFS_PARTNAME-$root_gpt_label}"

# Returns a list of partitioner requirements
#
timeshift_requires()
{
	printf "mkfs.btrfs btrfs"
}

# An additional single-drive configuration checker
#
single_drive_config()
{
	local msg

	msg="Don't use a separate /boot with '%s' partitioner."
	[ -z "$bootsize" ] || [ "${platform:0:3}" = e2k ] ||
		fatal F000 "$msg" "timeshift"
	msg="A separate /home is required for '%s' partitioner."
	[ -n "$create_users_list" ] || is_file_exists "home.$ziptype" ||
		fatal F000 "$msg" "timeshift"
	datapart_mp=/home
	btrfspart=
	rootsize=
}

# An additional multi-drives configuration checker
#
multi_drives_config()
{
	single_drive_config
}

# Sets paths for all partition device nodes
#
define_parts()
{
	[ -z "$preppart" ] ||
		preppart="$(devnode "$preppart")"
	[ -z "$esp_part" ] ||
		esp_part="$(devnode "$esp_part")"
	[ -z "$bbp_part" ] ||
		bbp_part="$(devnode "$bbp_part")"
	[ -z "$bootpart" ] ||
		bootpart="$(devnode "$bootpart")"
	[ -z "$swappart" ] ||
		swappart="$(devnode "$swappart")"
	btrfspart="$(devnode "$btrfspart")"
}

# Sets the GUID/GPT PART-LABEL for each created partition
#
set_gpt_part_names()
{
	local x="${target}p"

	[ "$pt_scheme" = gpt ] ||
		return 0
	[ "$ppartsep" = 1 ] ||
		x="$target"
	[ -z "$preppart" ] || [ -z "$prep_gpt_label" ] ||
		gpt_part_label "$target" "${preppart##$x}" "$prep_gpt_label"
	[ -z "$esp_part" ] || [ -z "$esp__gpt_label" ] ||
		gpt_part_label "$target" "${esp_part##$x}" "$esp__gpt_label"
	[ -z "$bbp_part" ] || [ -z "$bbp__gpt_label" ] ||
		gpt_part_label "$target" "${bbp_part##$x}" "$bbp__gpt_label"
	[ -z "$bootpart" ] || [ -z "$boot_gpt_label" ] ||
		gpt_part_label "$target" "${bootpart##$x}" "$boot_gpt_label"
	[ -z "$swappart" ] || [ -z "$swap_gpt_label" ] ||
		gpt_part_label "$target" "${swappart##$x}" "$swap_gpt_label"
	[ -z "$btrfspart" ] || [ -z "$BTRFS_PARTNAME" ] ||
		gpt_part_label "$target" "${btrfspart##$x}" "$BTRFS_PARTNAME"
	log "All GUID/GPT partitions have been renamed"
}

# Prepares partition scheme for the target disk
#
timeshift_make_scheme()
{
	btrfspart=
	__prepare_${pt_scheme}_layout
	rootpart="@"
	datapart="@home"
}

# Creates a GUID/GPT disk layout
#
__prepare_gpt_layout()
{
	local i=1

	# IBM Power PReP partition
	if [ -n "$prepsize" ]; then
		echo ",$prepsize,$prepguid"
		preppart="$i"
		i=$((1 + $i))
	fi

	# EFI System partition
	if [ -n "$esp_size" ]; then
		echo ",$esp_size,U"
		esp_part="$i"
		i=$((1 + $i))
	fi

	# BIOS Boot partition
	if [ -n "$bbp_size" ]; then
		echo ",$bbp_size,$bbp_guid"
		bbp_part="$i"
		i=$((1 + $i))
	fi

	# /boot partition
	if [ -n "$bootsize" ]; then
		echo ",$bootsize"
		bootpart="$i"
		i=$((1 + $i))
	fi

	# SWAP partition
	if [ -n "$swapsize" ]; then
		echo ",$swapsize,S"
		swappart="$i"
		i=$((1 + $i))
	fi

	# BTRFS partition is required
	echo ","
	btrfspart="$i"
}

# Creates a simple DOS/MBR disk layout
#
__prepare_dos_layout()
{
	local i=1

	# IBM Power PReP partition
	if [ -n "$prepsize" ]; then
		echo ",$prepsize,7"
		preppart="$i"
		i=$((1 + $i))
	fi

	# EFI System partition
	if [ -n "$esp_size" ]; then
		echo ",$esp_size,U"
		esp_part="$i"
		i=$((1 + $i))
	fi

	# /boot partition
	if [ -n "$bootsize" ]; then
		echo ",$bootsize,L,*"
		bootpart="$i"
		i=$((1 + $i))
	fi

	# SWAP partition
	if [ -n "$swapsize" ]; then
		echo ",$swapsize,S"
		swappart="$i"
		i=$((1 + $i))
	fi

	# BTRFS partition is required
	[ -n "$bootsize" ] && echo "," ||
		echo ",,L,*"
	btrfspart="$i"
}

# Post-formatting function specific to this partitioner
#
timeshift_post_format()
{
	local label="${root_fs_label:-$BTRFS_PARTNAME}"

	msg "${L0000-Formatting %s (%s)...}" "BTRFS" "$btrfspart"
	log "Creating a btrfs partition specifically for Timeshift..."

	# NB: there is no way to restore the old UUID of the partition
	run mkfs.btrfs -q -f${label:+ -L "$BTRFS_PARTNAME"} -- "$btrfspart"
	run mkdir -p -m 0755 -- "$destdir"
	run mount -t btrfs -- "$btrfspart" "$destdir"
	run cd -- "$destdir"/
	run btrfs subvolume create "./$rootpart"
	run btrfs subvolume create "./$homepart"
	run cd - >/dev/null ||:
	run umount -- "$destdir" ||
		run umount -fl -- "$destdir"
	rootuuid="$(get_fs_uuid "$btrfspart")"
	datauuid="$rootuuid"
}

# A specific function for this partitioner that mounts
# specified partition at the specified destination
#
timeshift_mount_part()
{
	local part="$1" dest="$2"

	run mount -t btrfs -o "relatime,subvol=$part" -- "$btrfspart" "$dest"
	log "The btrfs partition '%s' has been mounted to '%s'" "$part" "$dest"
}

