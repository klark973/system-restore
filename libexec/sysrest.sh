###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

# Bootstrap
. "$supplimental"/restore.sh
. "$supplimental"/slayout.sh

do_sysrest_action()
{
	setup_privates
	check_pt_schema
	[ -z "$showdiag" ] ||
		. "$supplimental"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$supplimental"/validate.sh
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

do_sysrest_action

