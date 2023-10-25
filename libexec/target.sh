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
	if [ -n "$mult_targets" ]; then
		diskinfo=( "${diskinfo[@]}" "$target=$di" )
	else
		diskinfo="$di"
	fi
}

# Placeholder: this function must be reimplemented in
# $supplimental/part/$partitioner.sh or $backup/$partitioner.sh,
# it must setup the target= variable in multi-drives configuration
#
multi_drives_setup()
{
	local msg="%s MUST BE overrided in partitioner!"

	fatal F000 "$msg" "multi_drives_setup()"
}

# Searches for the target device if it is not specified
#
search_target_device()
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
		log "Selected target device: ${target}${diskinfo:+ - $diskinfo}"
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
				grep -vE '\-part[0-9]+$')"
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
		log "Specified target device: ${target}${diskinfo:+ - $diskinfo}"
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

		if [ "$action" != chkdisk ]; then
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
	elif [ "$cnt" != "$num_targets" ] && [ "$action" != chkdisk ]; then
		dev="Too many devices found! Requested: %s, gotten: %s."
		fatal F000 "$dev" "$num_targets" "$cnt"
	fi

	# Final steps
	if [ "$cnt" = 1 ]; then
		target="$srcdisks"
		multi_targets=
		get_disk_info
		log "The target device found: %s" "${target}${diskinfo:+ - $diskinfo}"

		if [ "$action" = chkdisk ]; then
			msg "%s" "${target}${diskinfo:+ - $diskinfo}"
			exit 0
		fi
	else
		multi_targets="$srcdisks"
		log "Creating multi-drives configuration..."

		for target in $srcdisks; do
			log "  - %s" "$target"
			get_disk_info
		done

		if [ "$action" = chkdisk ]; then
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
# partition number, to correctly combine these parts the ppart flag
# is used
#
devnode()
{
	case "$ppartsep" in
	0) printf "%s%s" "$target" "$1";;
	1) printf "%s%s%s" "$target" "p" "$1";;
	*) fatal F000 "%s flag is not set!" "ppartsep";;
	esac
}

# Wipe a target disk drive and all partitions
#
wipe_target()
{
	: TODO...
}

rereadpt()
{
	local i ndev="$1"
	local start lenght
	local partname devpath

	for i in $(seq 1 $ndev); do
		partname="$(devnode $i)"
		devpath="$(LC_ALL=C sfdisk -f -l -- "$target" |
				grep -s "$partname " |
				sed 's/  */ /g')"
		start="$(echo "$devpath" |cut -f2 -d' ')"
		lenght="$(echo "$devpath" |cut -f4 -d' ')"
		run addpart "$target" "$i" "$start" "$lenght" >/dev/null 2>&1 ||:
	done

	start=0

	while [ "$start" != "$ndev" ]
	do
		start=0
		sleep .2
		for i in $(seq 1 $ndev); do
			[ ! -b "$(devnode $i)" ] ||
				start=$((1 + $start))
		done
	done
}

gpt_part_label()
{
	local cmd="sfdisk -q -f --part-label"

	LC_ALL=C run $cmd - "$target" "$1" "$2" >/dev/null 2>&1 ||:
}

# Create disk label and apply a partitioning schema
#
apply_schema()
{
	: TODO...
}

define_parts()
{
	: TODO...
}

