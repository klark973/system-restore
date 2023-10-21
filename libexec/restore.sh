###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

# Bootstrap
[ -z "$cleanup_after" ] ||
	. "$supplimental"/cleanup.sh
. "$supplimental"/restpart.sh
. "$supplimental"/format.sh
. "$supplimental"/chroot.sh

# Can be overrided in $backup/restore.sh
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

setup_privates()
{
	local dsz=0

	[ "$action" = sysrest ] ||
		dsz="$(get_disk_size "$target")"
	if [ "$dsz" -gt "$(human2size 2T)" ]; then
		if [ "$action" = fullrest ]; then
			dsz="Use deploy mode for restore from "
			dsz="$dsz this backup to the disks >2Tb!"
			[ "$pt_schema" = gpt ] ||
				fatal F000 "$dsz"
		elif [ "$action" = deploy ]; then
			dsz="DOS/MBR labeling is inpossible with disks >2Tb!"
			[ -z "$force_mbr_label" ] ||
				fatal F000 "$dsz"
			pt_schema=gpt
		fi
	fi

	[ -z "$unique_clone" ] ||
		make_unique_hostname
	setup_privates_platform
}

# Can be overrided in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_new_fstab()
{
	. "$supplimental"/fstab.sh

	__make_new_fstab
}

# Can be overrided in $backup/restore.sh
# or $backup/$profile/restore.sh
#
make_new_grubcfg()
{
	. "$supplimental"/grubcfg.sh

	__make_new_grubcfg
}

__replace_uuids()
{
	[ ! -s "$destdir"/etc/fstab ] ||
		make_new_fstab
	[ ! -s "$destdir"/etc/sysconfig/grub2 ] ||
		make_new_grubcfg
}

# Can be overrided in $backup/restore.sh
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

# Can be overrided in $backup/restore.sh
# or $backup/$profile/restore.sh
#
rename_iface()
{
	__rename_iface
}

# Can be overrided in $backup/restore.sh
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

# Can be overrided in $backup/restore.sh
# or $backup/$profile/restore.sh
#
record_nvram()
{
	[ -n "$have_nvram" ] ||
		return 0
	: TODO...
}

umount_parts()
{
	run sync
	[ -z "$esp_part" ] ||
		run umount -- "$destdir"/boot/efi 2>/dev/null ||
			run umount -fl -- "$destdir"/boot/efi
	[ -z "$bootpart" ] ||
		run umount -- "$destdir"/boot 2>/dev/null ||
			run umount -fl -- "$destdir"/boot
	[ -z "$homepart" ] ||
		run umount -- "$destdir"/home 2>/dev/null ||
			run umount -fl -- "$destdir"/home
	[ -z "$var_part" ] ||
		run umount -- "$destdir"/var 2>/dev/null ||
			run umount -fl -- "$destdir"/var
	run umount -- "$destdir" 2>/dev/null ||
		run umount -fl -- "$destdir" ||:
	run rmdir  -- "$destdir" 2>/dev/null ||:
	run swapoff -a 2>/dev/null ||:
}

# Including user-defined hooks
if [ -n "$use_hooks" ] && [ -n "$unique_clone" ]; then
	[ ! -s "$backup"/restore.sh ] ||
		. "$backup"/restore.sh
	[ -z "$profile" ] || [ ! -s "$backup/$profile"/restore.sh ] ||
		. "$backup/$profile"/restore.sh
fi

