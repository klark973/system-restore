###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

########################################################
### The "plain" disk partitioning in deployment mode ###
########################################################

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

	# ROOT partition is required
	echo ",$rootsize"
	rootpart="$i"
	i=$((1 + $i))

	# DATA or HOME partition
	if [ -n "$rootsize" ]; then
		[ "$datapart_mp" = /home ] && echo ",,H" ||
			echo ","
		datapart="$i"
	fi
}

# Creates a simple DOS/MBR disk layout
#
__simple_dos_layout()
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

	# ROOT partition is required
	if [ -z "$bootsize" ]; then
		echo ",$rootsize,L,*"
		rootpart="$i"
		i=$((1 + $i))
	else
		echo ",$rootsize"
		rootpart="$i"
		i=$((1 + $i))
	fi

	# DATA or HOME partition
	if [ -n "$rootsize" ]; then
		echo ","
		datapart="$i"
	fi
}

# Creates a complex DOS/MBR disk layout
#
__complex_dos_layout()
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

	# Extended partition
	echo ",,0x05"

	# ROOT partition is required
	if [ -z "$bootsize" ]; then
		echo ",$rootsize,L,*"
		rootpart=5
	else
		echo ",$rootsize"
		rootpart=5
	fi

	# DATA or HOME partition
	if [ -n "$rootsize" ]; then
		echo ","
		datapart=6
	fi
}

# Creates a DOS/MBR disk layout
#
__prepare_dos_layout()
{
	local i=1

	# Counting partitions
	[ -z "$prepsize" ] ||
		i=$((1 + $i))
	[ -z "$esp_size" ] ||
		i=$((1 + $i))
	[ -z "$bootsize" ] ||
		i=$((1 + $i))
	[ -z "$swapsize" ] ||
		i=$((1 + $i))
	[ -z "$rootsize" ] ||
		i=$((1 + $i))

	# Selecting MBR layout
	if [ "$i" -le 4 ]; then
		__simple_dos_layout
	else
		__complex_dos_layout
	fi
}

# Prepares partition scheme for the target disk
#
plain_make_scheme()
{
	__prepare_${pt_scheme}_layout
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
	[ -z "$datapart" ] ||
		datapart="$(devnode "$datapart")"
	rootpart="$(devnode "$rootpart")"
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
	[ -z "$rootpart" ] || [ -z "$rootname" ] ||
		gpt_part_label "$target" "${rootpart##$x}" "$rootname"
	[ -z "$datapart" ] || [ -z "$dataname" ] ||
		gpt_part_label "$target" "${datapart##$x}" "$dataname"
	log "All GUID/GPT partitions has been renamed"
}

