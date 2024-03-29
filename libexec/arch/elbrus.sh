###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

# Called before including restore.ini files
# supplied with the backup and/or profile,
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
platform_setup_internals()
{
	[ -z "$uefiboot" ] && [ -z "$esp_size" ] ||
		fatal F000 "UEFI boot is not supported on %s!" "$platform"
	[ -n "$bootsize" ] ||
		fatal F000 "/boot size is not defined!"
	[ "$pt_scheme" = dos ] ||
		fatal F000 "This platform only supports the DOS/MBR disk label!"
	add_chroot_var bootpart
	biosboot_too=
	uefi2bios=
	bios2uefi=
	prepsize=
	bbp_size=
}

