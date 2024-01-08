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
	# BIOS Boot partition default size
	bbp_size=1M
}

# Called before starting any recovery action, it
# modifies platform-specific settings and performs
# a final check after the configuration is complete
#
platform_setup_internals()
{
	[ -z "$uefiboot" ] && [ -z "$esp_size" ] ||
		fatal F000 "UEFI boot is not supported on %s!" "$platform"
	[ "$pt_scheme" = dos ] || [ -n "$bbp_size" ] ||
		fatal F000 "BIOS Boot partition size is not defined!"
	[ "$pt_scheme" = gpt ] || bbp_size=
	biosboot_too=
	uefi2bios=
	bios2uefi=
	prepsize=
}

# Called from the chroot, it installs one
# or more platform-specific bootloader(s)
#
setup_bootloaders_platform()
{
	log "Installing %s for BIOS/CSM boot mode..." "grub-pc"
	run grub-install \
		--target=i386-pc $grub_install_opts \
		--boot-directory=/boot --recheck -- "$target"
	need_grub_update=1
}

