###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Called before including restore.ini files
# supplied with the backup and/or sub-profile,
# it changes platform-specific defaults and
# checks platform-specific requirements
#
check_prereq_platform()
{
	# /boot partition default size
	bootsize=512M
}

# Called before starting any recovery action, it
# modifies platform-specific settings and performs
# a final check after the configuration is complete
#
setup_privates_platform()
{
	[ -z "$uefiboot" ] ||
		fatal F000 "UEFI boot is not supported on %s!" "$platform"
	[ -n "$bootsize" ] ||
		fatal F000 "/boot size is not defined!"
	add_chroot_var bootpart
	biosboot_too=
	uefi2bios=
	bios2uefi=
	prepsize=
	esp_size=
	bbp_size=
}

