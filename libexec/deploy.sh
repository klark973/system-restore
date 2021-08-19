###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

# Bootstrap
. "$supplimental"/restore.sh
. "$supplimental"/dlayout.sh

do_deploy_action()
{
	setup_privates
	make_pt_schema
	[ -z "$showdiag" ] ||
		. "$supplimental"/diaginfo.sh
	[ -z "$validate" ] ||
		. "$supplimental"/validate.sh
	wipe_target
	apply_schema
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

