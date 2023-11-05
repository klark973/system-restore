###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

############################################################
### The "timeshift" disk partitioning in deployment mode ###
############################################################

readonly BTRFS_PARTNAME="${BTRFS_PARTNAME-ALTLINUX}"

# Returns a list of partitioner requirements
#
timeshift_requires()
{
	printf "mkfs.btrfs btrfs"
}

# An additional multi-drives configuration checker
#
multi_drives_config()
{
	local msg="Don't use a separate /boot with the '%s' partitioner."

	[ -z "$bootsize" ] || [ "${platform:0:3}" = e2k ] ||
		fatal F000 "$msg" "timeshift"
	btrfspart=
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

# Prepares partition scheme for the target disk
#
timeshift_make_scheme()
{
	btrfspart=
	__prepare_${pt_scheme}_layout
	rootpart="/@"
	homepart="/@home"
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
	[ -z "$preppart" ] || [ -z "$prepname" ] ||
		gpt_part_label "$target" "${preppart##$x}" "$prepname"
	[ -z "$esp_part" ] || [ -z "$esp_name" ] ||
		gpt_part_label "$target" "${esp_part##$x}" "$esp_name"
	[ -z "$bbp_part" ] || [ -z "$bbp_name" ] ||
		gpt_part_label "$target" "${bbp_part##$x}" "$bbp_name"
	[ -z "$bootpart" ] || [ -z "$bootname" ] ||
		gpt_part_label "$target" "${bootpart##$x}" "$bootname"
	[ -z "$swappart" ] || [ -z "$swapname" ] ||
		gpt_part_label "$target" "${swappart##$x}" "$swapname"
	[ -z "$btrfspart" ] || [ -z "$BTRFS_PARTNAME" ] ||
		gpt_part_label "$target" "${btrfspart##$x}" "$BTRFS_PARTNAME"
	log "All GUID/GPT partitions has been renamed"
}

