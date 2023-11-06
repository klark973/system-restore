###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Bootstrap
. "$utility"/restore.sh
. "$utility"/slayout.sh

do_sysrest_action()
{
	setup_internals
	check_pt_scheme
	[ -z "$showdiag" ] ||
		. "$utility"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$utility"/validate.sh
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

