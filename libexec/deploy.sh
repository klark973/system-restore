###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Bootstrap
. "$utility"/restore.sh
. "$utility"/dlayout.sh

do_deploy_action()
{
	setup_privates
	make_pt_scheme
	[ -z "$showdiag" ] ||
		. "$utility"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$utility"/validate.sh
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

do_deploy_action

