###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

# Bootstrap
[ -z "$cleanup_after" ] ||
	. "$libdir"/cleanup.sh
. "$libdir"/chroot.sh


do_deploy_action()
{
	setup_internals
	make_pt_scheme
	[ -z "$showdiag" ] ||
		. "$libdir"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$libdir"/validate.sh
	wipe_target
	apply_scheme
	define_parts
	format_parts
	restsys_parts
	restdata_part
	[ -z "$cleanup_after" ] ||
		cleanup_parts
	replace_uuids
	rename_iface
	make_unique
	prepare_chroot
	before_chroot
	[ -z "$clear_nvram" ] ||
		clear_nvram
	run_in_chroot
	after_chroot
	cleanup_chroot
	[ -z "$uefiboot" ] ||
		record_nvram
	umount_parts
}

do_fullrest_action()
{
	setup_internals
	use_pt_scheme
	[ -z "$showdiag" ] ||
		. "$libdir"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$libdir"/validate.sh
	wipe_target
	apply_scheme
	define_parts
	format_parts
	restsys_parts
	restdata_part
	[ -z "$cleanup_after" ] ||
		cleanup_parts
	replace_uuids
	rename_iface
	make_unique
	prepare_chroot
	before_chroot
	[ -z "$clear_nvram" ] ||
		clear_nvram
	run_in_chroot
	after_chroot
	cleanup_chroot
	[ -z "$uefiboot" ] ||
		record_nvram
	umount_parts
}

do_sysrest_action()
{
	setup_internals
	check_pt_scheme
	[ -z "$showdiag" ] ||
		. "$libdir"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$libdir"/validate.sh
	format_parts
	restsys_parts
	[ -z "$cleanup_after" ] ||
		cleanup_parts
	replace_uuids
	rename_iface
	make_unique
	prepare_chroot
	before_chroot
	[ -z "$clear_nvram" ] ||
		clear_nvram
	run_in_chroot
	after_chroot
	cleanup_chroot
	[ -z "$uefiboot" ] ||
		record_nvram
	umount_parts
}

restsys_parts()
{
	: TODO...
}

restdata_part()
{
	: TODO...
}

# Creates a file system on a specified device
#
fmt_part()
{
	local pfx="$1"
	local device display opts=
	local label= uuid= fstype=ext4

	eval "device=\"\$${pfx}part\""
	eval "display=\"\$${pfx}name\""
	msg "${L0000-Formatting %s (%s)...}" "$display" "$device"

	if [ "$pfx" = prep ] || [ "$pfx" = bbp_ ]; then
		log "Complete cleaning the device %s..." "$device"
		run dd if=/dev/zero of="$device" bs=1M >/dev/null ||:
		return 0
	fi

	log "Creating a %s file system on the device %s..." "$fstype" "$device"

	case "$pfx" in
	esp_)
		uuid="$(head -n1 -- "$workdir/esp.uuid" |sed 's,\-,\\-,g')"
		run mkfs.fat -F32 -f2 -n "$label" -- "$esp_part"
		pfx=
		;;
	boot)
		[ "${platform:0:3}" != e2k ] ||
			fstype=ext3
		;;
	swap)
		run mkswap -L "$label" -- "$swappart"
		pfx=
		;;
	esac

	if [ -n "$pfx" ]; then
		run "mkfs.$fstype" -q -j -L "$label" -- "$device"
	fi
}

#
#
format_target()
{
	local post_fmt=

	# Boot partitions
	[ -z "$preppart" ] ||
		fmt_part prep
	[ -z "$esp_part" ] ||
		fmt_part esp_
	[ -z "$bbp_part" ] ||
		fmt_part bbp_

	# System and data partitions
	if [ -n "$swappart" ]; then
		[ ! -b "$swappart" ] && post_fmt=1 ||
			fmt_part swap
	fi
	if [ -n "$rootpart" ]; then
		[ ! -b "$rootpart" ] && post_fmt=1 ||
			fmt_part root
	fi
	if [ -n "$datapart" ]; then
		[ ! -b "$datapart" ] && post_fmt=1 ||
			fmt_part data
	fi

	# Post-format
	[ -z "$post_fmt" ] ||
		${partitioner}_post_format
	log "All partitions on the target device have been formatted"
}

# The default implementation for mounting the target partition
# at the specified destination
#
mnt_part()
{
	local part="$1" dest="$2"
	local fstype=ext4 opts=relatime

	if [ ! -b "$part" ]; then
		${partitioner}_mnt_part "$part" "$dest"
		return 0
	elif [ "$dest" = "$destdir/boot" ] && [ "${platform:0:3}" = e2k ]; then
		fstype=ext3
	elif [ "$dest" = "$destdir/boot/efi" ]; then
		fstype=vfat
		opts="$esp_opts"
	fi

	run mount -t "$fstype" -o "$opts" -- "$part" "$dest"
	log "The %s partition '%s' has been mounted to '%s'" "$fstype" "$part" "$dest"
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_unique_hostname()
{
	local iface hw

	iface="$(ip route 2>/dev/null |
			grep -sE '^default via ' |
			awk '{print $5;}')"
	[ -n "$iface" ] ||
		iface="$(ls -1 /sys/class/net/ |
				grep -sv lo |
				head -n1)"
	hw="$(ip link show dev "${iface:-eth0}" 2>/dev/null |
		tail -n1 |
		awk '{print $2;}' |
		sed 's,:,,g' |
		cut -c7-12)"
	[ -z "$hw" ] ||
		computer="$computer-$hw"
	log "Unique computer name is '%s'" "$computer"
}

setup_internals()
{
	local dsz=0

	[ "$action" = sysrest ] ||
		dsz="$(get_disk_size "$target")"
	if [ "$dsz" -gt "$(human2size 2T)" ]; then
		if [ "$action" = fullrest ]; then
			dsz="Use deployment mode for restore from "
			dsz="$dsz this backup to the disks >2Tb!"
			[ "$pt_scheme" = gpt ] ||
				fatal F000 "$dsz"
		elif [ "$action" = deploy ]; then
			dsz="DOS/MBR labeling is not possible with disks >2Tb!"
			[ -z "$force_mbr_label" ] ||
				fatal F000 "$dsz"
			pt_scheme=gpt
		fi
	fi

	[ -z "$unique_clone" ] ||
		make_unique_hostname
	platform_setup_internals
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_new_fstab()
{
	. "$libdir"/fstab.sh

	__make_new_fstab
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_new_grubcfg()
{
	. "$libdir"/grubcfg.sh

	__make_new_grubcfg
}

__replace_uuids()
{
	[ ! -s "$destdir"/etc/fstab ] ||
		make_new_fstab
	[ ! -s "$destdir"/etc/sysconfig/grub2 ] ||
		make_new_grubcfg
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
replace_uuids()
{
	__replace_uuids
}

__rename_iface()
{
	[ -n "$wired_iface" ] &&
	[ "x$wired_iface" != xeth0 ] &&
	[ -d "$destdir"/etc/net/ifaces/eth0 ] ||
		return 0
	run mv -f -- "$destdir"/etc/net/ifaces/eth0 \
			"$destdir/etc/net/ifaces/$wired_iface"
	log "Wired network interface was renamed to '%s'." "$wired_iface"
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
rename_iface()
{
	__rename_iface
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_unique()
{
	local f

	log "Personification..."
	msg ""; msg "Personification..."

	if [ -d "$destdir"/etc ]; then
		f="$destdir/etc/machine-id"
		run dbus-uuidgen >"$f"
		[ ! -d "$destdir"/var/lib/dbus ] ||
			run cp -Lf -- "$f" "$destdir"/var/lib/dbus/
		fdump "$f"

		f="$destdir/etc/sysconfig/network"
		if [ "x$template" != "x$computer" ] &&
			[ -s "$f" ] && grep -qws "$template" "$f"
		then
			run sed -i "s,$template,$computer," "$f"
			fdump "$f"
		fi
	fi

	f="$(head -n1 "$workdir"/RNDSEED 2>/dev/null ||:)"
	if [ -n "$f" ] && [ -d "${destdir}${f%/*}" ]; then
		run head -c512 /dev/urandom >"${destdir}${f}"
		run chmod 600 -- "${destdir}${f}"
	fi
}

clear_nvram()
{
	local bootnum junk

	( efibootmgr -q -D ||:
	  efibootmgr -q -N ||:

	  efibootmgr |
		grep -sE "^Boot[0-9A-F][0-9A-F][0-9A-F][0-9A-F]" |
	  while read -r bootnum junk; do
		efibootmgr -q -B -b "${bootnum:4:4}" ||:
	  done

	  efibootmgr -q -O ||:
	) >/dev/null 2>&1
}

# It can be overridden in $backup/restore.sh
# or $backup/$profile/restore.sh
#
record_nvram()
{
	[ -n "$have_nvram" ] ||
		return 0
	: TODO...
}

# Unmounts all partitions which was mounted to $destdir
#
unmount_all()
{
	local mp

	run sync; run cd /

	( grep -s -- " $destdir/" /proc/mounts	|
		cut -f2 -d ' '			|
		grep -- "$destdir/"		|
		tac
	  grep -s -- " $destdir " /proc/mounts	|
		cut -f2 -d ' '			|
		grep -- "$destdir"		|
		sort -u
	) |
	while read -r mp; do
		run umount -- "$mp" || run umount -fl -- "$mp"
		log "The partition '%s' has been unmounted" "$mp"
	done
}


# Using user-defined hooks
if [ -n "$use_hooks" ]; then
	user_config restore.sh
	[ -z "$profile" ] ||
		user_config "$profile"/restore.sh
fi

