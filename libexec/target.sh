###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Determinates the device name of the whole disk drive
# for any specified device such as a disk partition
#
get_whole_disk()
{
	local varname="$1" partdev="$2"
	local number sysfs partn whole=""

	number="$(mountpoint -x -- "$partdev")"
	sysfs="$(readlink -fv -- "/sys/dev/block/$number")"

	if [ -r "$sysfs/partition" ]; then
		read -r partn <"$sysfs/partition" ||
			partn=
		if [ -n "$partn" ]; then
			case "$partdev" in
			*[0-9]p$partn)
				whole="${partdev%%p$partn}"
				;;
			*$partn)
				whole="${partdev%%$partn}"
				;;
			esac
		fi
		[ -n "$whole" ] && [ -b "$whole" ] &&
		[ -r "/sys/block/${whole##/dev/}/${partdev##/dev/}/dev" ] ||
			whole=
	fi

	[ -z "$whole" ] || eval "$varname=\"$whole\""
}

# Populates the list of protected devices
# with the specified mount points and/or devices
#
protect_boot_devices()
{
	local number sysfs mp pdev

	skip_mp_dev()
	{
		log "Mount point or device will be ignored: %s" "$1"
	}

	for mp in $protected_mpoints; do
		if [ -d "$mp" ] && mountpoint -q -- "$mp"; then
			number="$(mountpoint -d -- "$mp")"
		elif [ -b "$mp" ]; then
			number="$(mountpoint -x -- "$mp")"
		else
			skip_mp_dev "$mp"
			continue
		fi

		sysfs="$(readlink -fv -- "/sys/dev/block/$number"  2>/dev/null ||:)"
		pdev="$(sed -n -E 's/^DEVNAME=//p' "$sysfs"/uevent 2>/dev/null ||:)"
		if [ -z "$sysfs" ] || [ -z "$pdev" ]; then
			skip_mp_dev "$mp"
			continue
		fi

		pdev="/dev/$pdev"
		if [ ! -b "$pdev" ]; then
			skip_mp_dev "$mp"
			continue
		fi

		get_whole_disk pdev "$pdev"
		if [ -z "$pdev" ] || [ ! -b "$pdev" ]; then
			skip_mp_dev "$mp"
		elif ! in_array "$pdev" $protected_devices; then
			protected_devices="$protected_devices $pdev"
			log "Added to WP-list: %s => %s" "$mp" "$pdev"
		fi
	done

	log "Protected devices:$protected_devices"
}

# Determinates a size of the specified whole disk drive
#
get_disk_size()
{
	local dname="$1" nblocks disksize=0
	local sysfs="/sys/block/${dname##/dev/}"

	if [ ! -s "$sysfs/size" ]; then
		disksize="$(blockdev --getsize64 -- "/dev/${dname##/dev/}")"
	else
		read -r nblocks <"$sysfs/size" 2>/dev/null &&
		disksize="$(( ${nblocks:-0} * 512 ))"
	fi

	printf "%s" "$disksize"
}

# Reads information about specified whole disk drive
#
get_disk_info()
{
	local di="" field=
	local dev="${target##/dev/}"

	[ ! -r "/sys/block/$dev/device/vendor" ] ||
		read -r di <"/sys/block/$dev/device/vendor" 2>/dev/null ||:
	[ ! -r "/sys/block/$dev/device/model" ]  ||
		read -r field <"/sys/block/$dev/device/model" 2>/dev/null ||:
	[ -z "$field" ] ||
		di="${di:+$di }$field"
	field=
	[ ! -r "/sys/block/$dev/device/serial" ] ||
		read -r field <"/sys/block/$dev/device/serial" 2>/dev/null ||:
	[ -z "$field" ] ||
		di="${di:+$di }(s/n: $field)"
	dev="$(get_disk_size "$dev")"
	di="$(size2human -w "$dev")${di:+, $di}"

	if [ -n "$multi_targets" ]; then
		diskinfo=( "${diskinfo[@]}" "$target: $di" )
	else
		diskinfo="$di"
	fi
}

# Returns the minimum required disk size
#
requested_device_size()
{
	local v s=0

	[ -z "$prepsize" ] && v="" ||
		v="$(human2size "$prepsize")"
	[ -z "$v" ] ||
		s=$(( $s + $v ))
	[ -z "$esp_size" ] && v="" ||
		v="$(human2size "$esp_size")"
	[ -z "$v" ] ||
		s=$(( $s + $v ))
	[ -z "$bbp_size" ] && v="" ||
		v="$(human2size "$bbp_size")"
	[ -z "$v" ] ||
		s=$(( $s + $v ))
	[ -z "$bootsize" ] && v="" ||
		v="$(human2size "$bootsize")"
	[ -z "$v" ] ||
		s=$(( $s + $v ))
	[ -z "$swapsize" ] && v="" ||
		v="$(human2size "$swapsize")"
	[ -z "$v" ] ||
		s=$(( $s + $v ))
	[ -z "$rootsize" ] && v="" ||
		v="$(human2size "$rootsize")"
	[ -z "$v" ] ||
		s=$(( $s + $v ))
	v="$(human2size 1G)"
	s=$(( $s + $v ))
	printf "%s" "$s"
}

# Selects only one device with minimum capacity
#
__select_smallest_drive()
{
	local dev curr min=0

	for dev in $multi_targets; do
		curr="$(get_disk_size "$dev")"
		if [ -z "$target" ] || [ "$min" -gt "$curr" ]; then
			target="$dev"
			min="$curr"
		fi
	done
}

# Selects only one device with maximum capacity
#
__select_biggest_drive()
{
	local dev curr max=0

	for dev in $multi_targets; do
		curr="$(get_disk_size "$dev")"
		if [ -z "$target" ] || [ "$max" -lt "$curr" ]; then
			target="$dev"
			max="$curr"
		fi
	done
}

# Checks the target disk size
#
check_target_size()
{
	local r s

	r="$(requested_device_size)"
	s="$(get_disk_size "$target")"
	[ "$r" -le "$s" ] ||
		fatal F000 "Not enough space on the target device!"
	r="$(size2human "$r")"
	s="$(size2human "$s")"
	log "Requested space: %s, target size: %s" "$r" "$s"
}

# Sets the $target variable in a multi-drives configuration.
# The default implementation just selects only one device
# with the maximum capacity. It can be reimplemented in
# $utility/part/$partitioner.sh or $backup/$partitioner.sh
#
multi_drives_setup()
{
	__select_biggest_drive
	[ -z "$target" ] || check_target_size
}

# Prepares partition scheme for the target disk,
# it can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_pt_scheme()
{
	preppart=
	esp_part=
	bbp_part=
	bootpart=
	swappart=
	rootpart=
	var_part=
	homepart=

	disk_layout="$workdir/disk-layout.tmp"
	${partitioner}_make_scheme >"$disk_layout"
	fdump "$disk_layout"
}

# Placeholder: this function must be reimplemented in
# $utility/part/$partitioner.sh or $backup/$partitioner.sh,
# it must assign paths for all partition device nodes
#
define_parts()
{
	local msg="%s MUST BE overridden in partitioner!"

	fatal F000 "$msg" "define_parts()"
}

# Placeholder: this function must be reimplemented in
# $utility/part/$partitioner.sh or $backup/$partitioner.sh,
# it creates a disk label and applies a new partition scheme
#
apply_scheme()
{
	local msg="%s MUST BE overridden in partitioner!"

	fatal F000 "$msg" "apply_scheme()"
}

# Placeholder: this function must be reimplemented in
# $utility/part/$partitioner.sh or $backup/$partitioner.sh,
# it deinitializes all disk subsystems after unmounting
# partitions and before finalizing the primary action
#
deinit_disks()
{
	: # Do nothing by default
}

# A wrapper function which looks for a target device if one is not specified
#
search_target_device()
{
	[ -n "$num_targets" ] && is_number "$num_targets" ||
		num_targets=1
	__search_tgtdev_intl

	# Should we use delimiter between target device and partition number?
	if [ "$ppartsep" != 1 ] && [ "$ppartsep" != 0 ]; then
		case "$target" in
		*[0-9])	ppartsep=1;;
		*)	ppartsep=0;;
		esac
	fi
}

# Internal part of the function search_target_device()
#
__search_tgtdev_intl()
{
	local dev msz xsz dsz=""

	# We will restore to the same disk drive where the backup was created
	if [ "$action" = fullrest ] || [ "$action" = sysrest ]; then
		[ -n "$target" ] ||
			target="$(head -n1 -- "$workdir"/TARGETS  2>/dev/null ||:)"
		target="$(readlink -fv -- "/dev/${target##/dev/}" 2>/dev/null ||:)"
		[ -z "$target" ] ||
			get_whole_disk dev "$target"
		[ -b "$target" ] && [ "${dev-}" = "$target" ] ||
			fatal F000 "Target device (%s) not found!" "$target"
		! in_array "$target" $protected_devices ||
			fatal F000 "Target device (%s) is write protected!" "$target"
		get_disk_info
		log "Selected target device: $target: $diskinfo"
		return 0
	fi

	# Calculating bounds of the target device capacity
	[ -z "$target_min_capacity" ] && msz="" ||
		msz="$(human2size "$target_min_capacity")"
	[ -z "$target_max_capacity" ] && xsz="" ||
		xsz="$(human2size "$target_max_capacity")"

	local srcdisks="" models="" cnt=0

	# Building a list of disks by specified pattern
	if [ -n "$target_model_pattern" ]; then
		srcdisks="$(glob "/dev/disk/by-id/$target_model_pattern" |
				grep -vsE '\-part[0-9]+$')"
		for dev in $srcdisks; do
			dev="$(readlink -fv -- "$dev" 2>/dev/null ||:)"
			[ -z "$dev" ] || in_array "$dev" $models  ||
				models="${models:+$models }$dev"
		done
		srcdisks=
	fi

	# Checking an explicitly specified target device
	if [ -n "$target" ]; then
		get_whole_disk dev "$target"
		[ -b "$target" ] && [ "${dev-}" = "$target" ] ||
			fatal F000 "Invalid target device specified: '%s'!" "$target"
		! in_array "$target" $protected_devices ||
			fatal F000 "Target device (%s) is write protected!" "$target"
		[ -z "$msz" ] && [ -z "$xsz" ] ||
			dsz="$(get_disk_size "$target")"
		[ -z "$msz" ] || [ "$dsz" -ge "$msz" ] 2>/dev/null ||
			fatal F000 "Specified target device (%s) is too small!" "$target"
		[ -z "$xsz" ] || [ "$dsz" -le "$xsz" ] 2>/dev/null ||
			fatal F000 "Specified target device (%s) is too big!" "$target"
		[ -z "$target_model_pattern" ] || in_array "$target" $models ||
			fatal F000 "Target device (%s) and pattern mismatch!" "$target"
		get_disk_info
		check_target_size
		log "Specified target device: $target: $diskinfo"
		return 0
	fi

	# Reading IMSM devices list
	if [ -n "$imsm_container" ]; then
		target="$(mdadm --detail-platform 2>/dev/null    |
				grep -E '^[[:space:]]+Port[0-9]' |
				grep -v 'no device attached'     |
				awk '{print $3;}')"
	fi

	skip_dev()
	{
		log "Skipping /dev/%s because it %s" "$dev" "$1"
	}

	# Looking for target device(s)
	for dev in $(ls /sys/block/); do
		case "$dev" in
		loop[0-9]*|ram[0-9]*|sr[0-9]*|dm-[0-9]*|md[0-9]*)
			continue
			;;
		esac

		if [ ! -b "/dev/$dev" ]; then
			skip_dev "is not a block special device"
			continue
		fi

		if [ -r "/sys/block/$dev/ro" ]; then
			if read -r dsz <"/sys/block/$dev/ro" && [ "$dsz" != 0 ]; then
				skip_dev "is a read-only device"
				continue
			fi
		fi

		if in_array "/dev/$dev" $protected_devices; then
			skip_dev "is a write protected device"
			continue
		fi

		if [ -z "$removable" ] && [ -r "/sys/block/$dev/removable" ]; then
			if read -r dsz <"/sys/block/$dev/removable" && [ "$dsz" != 0 ]; then
				skip_dev "is a removable disk drive"
				continue
			fi
		fi

		if [ "$action" != scandisk ]; then
			if [ -n "$msz" ] || [ -n "$xsz" ]; then
				dsz="$(get_disk_size "/dev/$dev")"
			fi
			if [ -n "$msz" ] && [ "$dsz" -lt "$msz" ] 2>/dev/null; then
				skip_dev "is less than allowed capacity"
				continue
			fi
			if [ -n "$xsz" ] && [ "$dsz" -gt "$xsz" ] 2>/dev/null; then
				skip_dev "is more than allowed capacity"
				continue
			fi
			if [ -n "$target_model_pattern" ]; then
				if ! in_array "/dev/$dev" $models; then
					skip_dev "does not match the model pattern"
					continue
				fi
			fi
			if [ -n "$imsm_container" ]; then
				if ! in_array "/dev/$dev" $target; then
					skip_dev "is not an IMSM disk drive"
					continue
				fi
			fi
			if [ -n "$multi_targets" ]; then
				if ! in_array "/dev/$dev" $multi_targets; then
					skip_dev "is not listed"
					continue
				fi
			fi
		fi

		srcdisks="${srcdisks:+$srcdisks }/dev/$dev"
		log "Device found: %s" "/dev/$dev"
		cnt=$((1 + $cnt))
	done

	# Checking the counter
	if [ "$cnt" = 0 ]; then
		fatal F000 "Target disk drive(s) not found!"
	elif [ "$cnt" -lt "$num_targets" ]; then
		dev="Not enough devices found! Requested: %s, gotten: %s."
		fatal F000 "$dev" "$num_targets" "$cnt"
	elif [ "$cnt" != "$num_targets" ] && [ "$action" != scandisk ]; then
		dev="Too many devices found! Requested: %s, gotten: %s."
		fatal F000 "$dev" "$num_targets" "$cnt"
	fi

	# Final steps
	if [ "$cnt" = 1 ]; then
		target="$srcdisks"
		multi_targets=
		get_disk_info
		check_target_size
		log "The target device found: %s: %s" "$target" "$diskinfo"

		if [ "$action" = scandisk ]; then
			msg "%s: %s" "$target" "$diskinfo"
			exit 0
		fi
	else
		multi_targets="$srcdisks"
		log "Creating a multi-drives configuration..."

		for target in $srcdisks; do
			log "  - %s" "$target"
			get_disk_info
		done

		if [ "$action" = scandisk ]; then
			for target in "${diskinfo[@]}"; do
				msg "# %s" "$target"
			done
			exit 0
		fi

		target=
		multi_drives_setup
		[ -n "$target" ] ||
			fatal F000 "Couldn't create multi-drives setup!"
		log "The target device will be created: %s" "$target"
	fi
}

# Returns unchangeble udev path for specified device, for example:
# /dev/disk/by-id/nvme-SAMSUNG_MZVL21T0HCLR-00B00_S767NX0T854545
#
get_disk_id()
{
	local dev="$1"

	dev="$(mountpoint -x -- "$dev")"
	dev="$(grep -s 'S:disk/by-id/' /run/udev/data/"b$dev" \
			2>/dev/null |head -n1 |cut -c3-)"
	if [ -n "$dev" ] && [ -L "/dev/$dev" ]; then
		printf "/dev/%s" "$dev"
	else
		printf "%s" "$1"
	fi
}

# Return the partition device name given the target device name and
# partition number.  To correctly combine these parts, the ppartsep
# flag is used.
#
devnode()
{
	case "$ppartsep" in
	0) printf "%s%s" "$target" "$1";;
	1) printf "%s%s%s" "$target" "p" "$1";;
	*) fatal F000 "%s flag is not set!" "ppartsep";;
	esac
}

# Wipes specified devices and all partitions on them, it can be
# overridden in $utility/part/$partitioner.sh or $backup/$partitioner.sh
#
wipe_targets()
{
	local dev plist devices="$*"

	# Stopping all subsystems only once
	if [ -z "${__subsystems_stopped-}" ]; then
		log "Stopping all subsystems..."

		( set +e
		  set +E
		  swapoff -a
		  vgchange -a n
		  mdadm --stop --scan
		  vgchange -a n
		  mdadm --stop --scan
		) &>/dev/null ||:

		__subsystems_stopped=1
	fi

	[ -n "$devices" ] ||
		devices="${multi_targets:-$target}"
	log "Wiping device(s): %s..." "$devices"

	for dev in $devices; do
		plist="$(set +f; ls -r -- "$dev"?* 2>/dev/null ||:)"

		( set +e
		  set +E
		  [ -z "$plist" ] ||
			wipefs -a $plist
		  mdadm --zero-superblock "$dev"
		  dd if=/dev/zero bs=1M count=2 of="$dev"
		  wipefs -a "$dev"
		  sync "$dev"
		  udevadm trigger -q "$dev"
		) &>/dev/null ||:
	done

	run udevadm settle -t5 >/dev/null ||:
}

# Tells the kernel to reread a partition table on the specified device
# and waits for new partitions to be ready. If device is not specified,
# the target disk drive will be used.
#
rereadpt()
{
	local n junk partname start lenght device="${1-}"
	local cmd="LC_ALL=C sfdisk -q -f -l --color=never"

	[ -n "$device" ] ||
		device="$target"
	log "Telling the kernel that the partition table on %s has been changed" "$device"

	run sync "$device" ||:

	run $cmd -- "$device" |sed '1d;s/  */ /g' |
	while IFS=' ' read -r partname start lenght junk; do
		case "$device" in
		*[0-9])	n="${device}p"
			n="${partname##$n}"
			;;
		*)	n="${partname##$device}"
			;;
		esac
		run addpart "$device" "$n" "$start" "$lenght" >/dev/null ||:
	done

	run udevadm trigger -q "$device" >/dev/null ||:

	junk=( $($cmd -- "$device" |sed '1d;s/ .*//g') )
	n="${#junk[@]}"; lenght="$n"
	log "Waiting for new partitions from the kernel to appear..."

	while :; do
		for partname in "${junk[@]}"; do
			[ ! -b "$partname" ] ||
				n=$(( $n - 1 ))
		done
		[ "$n" -gt 0 ] ||
			break
		n="$lenght"
		sleep .2
	done

	run udevadm settle -t5 >/dev/null ||:
}

# Returns the UUID of the file system on the specified device
#
get_fs_uuid() {
	run blkid -c /dev/null -o value -s UUID -- "$1"
}

# Returns the LABEL of the file system on the specified device
#
get_fs_label() {
	run blkid -c /dev/null -o value -s LABEL -- "$1"
}

# Reads or writes a partition GUID on the specified GUID/GPT disk
#
gpt_part_guid()
{
	local device="$1" partno="$2" guid="${3-}"
	local cmd="LC_ALL=C sfdisk -q -f --part-uuid"

	[ -n "$device" ] && [ "$device" != '-' ] ||
		device="$target"
	if [ -n "$label" ]; then
		run $cmd -- "$device" "$partno" "$guid" >/dev/null ||:
	else
		run $cmd -- "$device" "$partno" ||:
	fi
}

# Reads or writes a partition label on the specified GUID/GPT disk
#
gpt_part_label()
{
	local device="$1" partno="$2" label="${3-}"
	local cmd="LC_ALL=C sfdisk -q -f --part-label"

	[ -n "$device" ] && [ "$device" != '-' ] ||
		device="$target"
	if [ -n "$label" ]; then
		run $cmd -- "$device" "$partno" "$label" >/dev/null ||:
	else
		run $cmd -- "$device" "$partno" ||:
	fi
}

