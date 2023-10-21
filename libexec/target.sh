###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Determines the device name of the whole disk drive
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

		sysfs="$(readlink -fv -- "/sys/dev/block/$number" 2>/dev/null)" &&
		pdev="$(sed -n -E 's/^DEVNAME=//p' "$sysfs"/uevent 2>/dev/null)" &&
		[ -n "$pdev" ] ||
			skip_mp_dev "$mp" && continue
		pdev="/dev/$pdev"
		[ -b "$pdev" ] ||
			skip_mp_dev "$mp" && continue
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

# Determines a size of the specified whole disk drive
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

	echo -n "$disksize"
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

# Tries to auto-detect the target device if one has not been specified
#
search_target_device()
{
	local dev msz xsz dsz cnt=0

	# Calculating bounds of the target device capacity
	[ -z "$target_min_capacity" ] && msz="" ||
		msz="$(human2size "$target_min_capacity")"
	[ -z "$target_max_capacity" ] && xsz="" ||
		xsz="$(human2size "$target_max_capacity")"
	dsz=""

	# Checking an explicity specified target device
	if [ -n "$target" ]; then
		get_whole_disk dev "$target"
		[ -b "$target" ] && [ "${dev-}" = "$target" ] && [ -z "$multi_targets" ] ||
			fatal F000 "Invalid target device specified: '%s'!" "$target"
		! in_array "$target" $protected_devices ||
			fatal F000 "Specified target device (%s) is write protected!" "$target"
		[ -z "$msz" ] && [ -z "$xsz" ] ||
			dsz="$(get_disk_size "$target")"
		[ -z "$msz" ] || [ "$dsz" -ge "$msz" ] 2>/dev/null ||
			fatal F000 "Specified target device (%s) is too small!" "$target"
		[ -z "$xsz" ] || [ "$dsz" -le "$xsz" ] 2>/dev/null ||
			fatal F000 "Specified target device (%s) is too big!" "$target"
		get_disk_info
		log "Specified target device: ${target}${diskinfo:+ - $diskinfo}"
		return 0
	fi

	# Searching the target device
	for dev in $(ls /sys/block/); do
		case "$dev" in
		loop[0-9]*|ram[0-9]*|sr[0-9]*|dm-[0-9]*|md[0-9]*)
			continue
			;;
		esac
		[ -b "/dev/$dev" ] ||
			continue
		! in_array "/dev/$dev" $protected_devices ||
			continue
		if [ -z "$removable" ]; then
			: TODO...
		fi
		if [ -n "$msz" ]; then
			dsz="$(get_disk_size "$dev")"
			[ "$dsz" -ge "$msz" ] 2>/dev/null ||
				continue
		fi
		cnt=$((1 + $cnt))
		target="/dev/$dev"
	done

	[ "$cnt" != 0 ] ||
		fatal F000 "Target disk drive not found!"
	[ "$cnt" = 1 ] && [ -n "$target" ] ||
		fatal F000 "Target disk drive must be specified!"
	target="/dev/$target"
	get_disk_info
	log "Target device found: ${target}${diskinfo:+ - $diskinfo}"
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

