###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#######################################################
### The "lvm2" disk partitioning in deployment mode ###
#######################################################

readonly LVM2_PARTNAME="${LVM2_PARTNAME-LVM1}"
readonly LVM2_SYSGROUP="${LVM2_SYSGROUP-alt}"
readonly LVM2_SWAPNAME="${LVM2_SWAPNAME-swap}"
readonly LVM2_ROOTNAME="${LVM2_ROOTNAME-root}"
readonly LVM2_DATANAME="${LVM2_DATANAME-data}"
readonly LVM2_PARTGUID="E6D6D379-F507-44C2-A23C-238F2A3DF928"

# Returns a list of partitioner requirements
#
lvm2_requires()
{
	printf "vgchange vgs lvs pvcreate vgcreate lvcreate"
}

# An additional multi-drives configuration checker
#
multi_drives_config()
{
	local msg="To boot from this drive you will need a separate /boot"

	[ "$platform" != x86_64 ] && [ "$platform" != aarch64 ] ||
		msg="$msg or /boot/efi"
	msg="$msg partition outside of LVM PV."
	[ -n "$uefiboot" ] || [ -n "$bootpart" ] ||
		fatal F000 "$msg"
	lvm2part=
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

	# LVM2 partition is required
	echo ",,$LVM2_PARTGUID"
	lvm2part="$i"
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

	# LVM2 partition is required
	[ -n "$bootsize" ] && echo ",,0x8E" ||
		echo ",,0x8E,*"
	lvm2part="$i"
}

# Prepares partition scheme for the target disk
#
lvm2_make_scheme()
{
	lvm2part=
	__prepare_${pt_scheme}_layout
	rootpart=1
	swappart="${swapsize:+1}"
	datapart="${rootsize:+1}"
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
	[ -z "$lvm2part" ] ||
		lvm2part="$(devnode "$lvm2part")"
	[ -z "$swappart" ] ||
		swappart="/dev/mapper/$LVM2_SYSGROUP-$LVM2_SWAPNAME"
	[ -z "$datapart" ] ||
		datapart="/dev/mapper/$LVM2_SYSGROUP-$LVM2_DATANAME"
	rootpart="/dev/mapper/$LVM2_SYSGROUP-$LVM2_ROOTNAME"
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
	[ -z "$lvm2part" ] || [ -z "$LVM2_PARTNAME" ] ||
		gpt_part_label "$target" "${lvm2part##$x}" "$LVM2_PARTNAME"
	log "All GUID/GPT partitions has been renamed"
}

# Creates a disk label and applies a new partition scheme
#
apply_scheme()
{
	local vs

	apply_scheme_default

	# Supress warnings about open file descriptors
	export LVM_SUPPRESS_FD_WARNINGS=1

	run pvcreate -- "$lvm2part"
	run vgcreate -- "$LVM2_SYSGROUP" "$lvm2part"

	if [ -n "$swappart" ]; then
		vs="$(size2human "$swapsize")"
		run lvcreate -L "$vs" -n "$LVM2_SWAPNAME" -- "$LVM2_SYSGROUP"
		run wipefs -a -- "$swappart" >/dev/null ||:
	fi

	if [ -z "$rootsize" ]; then
		run lvcreate -l100%FREE -n "$LVM2_ROOTNAME" -- "$LVM2_SYSGROUP"
		run wipefs -a -- "$rootpart" >/dev/null ||:
	else
		vs="$(size2human "$rootsize")"
		run lvcreate -L "$vs" -n "$LVM2_ROOTNAME" -- "$LVM2_SYSGROUP"
		run wipefs -a -- "$rootpart" >/dev/null ||:
		run lvcreate -l100%FREE -n "$LVM2_DATANAME" -- "$LVM2_SYSGROUP"
		run wipefs -a -- "$datapart" >/dev/null ||:
	fi
}

# Partitioner hook that is called after rootfs unpacking
#
lvm2_post_unpack()
{
	local fname

	# Editing /etc/initrd.mk
	fname="$destdir/etc/initrd.mk"
	if [ ! -f "$fname" ]; then
		echo "FEATURES += lvm" >"$fname"
	else
		grep -sw FEATURES "$fname" |grep -qsw lvm ||
			echo "FEATURES += lvm" >>"$fname"
	fi
}

# Deinitializes all disk subsystems after partitions
# are unmounted and before finalizing the primary action
#
deinit_disks()
{
	# Supress warnings about open file descriptors
	export LVM_SUPPRESS_FD_WARNINGS=1

	run vgs
	run lvs

	log "Deactivating LVM2 subsystem..."
	run vgchange -a n -- "$LVM2_SYSGROUP"
}

