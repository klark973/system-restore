###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

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

protect_boot_devices()
{
	local number sysfs mp pdev wdev

	for mp in $protected_mpoints; do
		[ -d "$mp" ] && mountpoint -q -- "$mp" ||
			continue
		number="$(mountpoint -d -- "$mp")"
		sysfs="$(readlink -fv -- "/sys/dev/block/$number")"
		pdev="$(grep -sE ^DEVNAME= "$sysfs"/uevent |cut -f2 -d=)"
		[ -n "$pdev" ] ||
			continue
		pdev="/dev/$pdev"
		[ -b "$pdev" ] ||
			continue
		wdev="$pdev"
		get_whole_disk wdev "$pdev"
		in_array "$wdev" $protected_devices ||
			protected_devices="$protected_devices $wdev"
	done

	log "Protected boot devices:$protected_devices"
}

get_disk_size()
{
	local dname="$1" nblocks disksize
	local sysfs="/sys/block/${dname##/dev/}"

	if [ ! -s "$sysfs/size" ]; then
		disksize="$(blockdev --getsize64 -- "/dev/${dname##/dev/}")"
	else
		read -r nblocks <"$sysfs/size" 2>/dev/null ||:
		disksize="$(( ${nblocks:-0} * 512 ))"
	fi

	echo -n "$disksize"
}

get_disk_info()
{
	local field=
	local dev="${target##/dev/}"

	[ ! -r "/sys/block/$dev/device/model" ] ||
		read -r field <"/sys/block/$dev/device/model" ||:
	[ -z "$field" ] ||
		diskinfo="$field"
	field=
	[ ! -r "/sys/block/$dev/device/serial" ] ||
		read -r field <"/sys/block/$dev/device/serial" ||:
	[ -z "$field" ] ||
		diskinfo="${diskinfo:+$diskinfo }${field}"
}

search_target_drive()
{
	local dev dsz cnt=0 msz=""

	# Calculating minimal required capacity of the target disk drive
	if [ -n "$min_target_size" ] && [ "$action" = deploy ]; then
		msz="$(human2size "$min_target_size")"
	elif [ "$action" = fullrest ]; then
		: TODO...
	elif [ "$action" = deploy ]; then
		: TODO...
	fi

	# Checking the explicity specified target disk drive
	if [ -n "$target" ]; then
		[ -b "$target" ] ||
			fatal F000 "Invalid target disk drive specified!"
		! in_array "$target" $protected_devices ||
			fatal F000 "Specified target disk drive is protected!"
		if [ -n "$msz" ]; then
			dsz="$(get_disk_size "$target")"
			[ "$dsz" -ge "$msz" ] 2>/dev/null ||
				fatal F000 "Specified target disk drive is too small!"
		fi
		get_disk_info
		log "Target disk drive checked: ${target}${diskinfo:+ ($diskinfo)}"
		return 0
	fi

	# Searching target disk drive
	for dev in $(ls /sys/block/); do
		case "$dev" in
		loop[0-9]*|ram[0-9]*|sr[0-9]*|dm-[0-9]*|md[0-9]*|_)
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
	log "Target disk drive found: ${target}${diskinfo:+ ($diskinfo)}"
}

# Wipe the target disk drive and all partitions
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

# Create disk label and apply the partitioning schema
#
apply_schema()
{
	: TODO...
}

define_parts()
{
	: TODO...
}

