###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Called before including restore.ini files
# supplied with the backup and/or profile,
# it changes platform-specific defaults and
# checks platform-specific requirements
#
check_prereq_platform()
{
	# IBM Power PReP partition default size
	prepsize=4M

	# ppc64le supports NVRAM
	have_nvram=1
}

# Called before starting any recovery action, it
# modifies platform-specific settings and performs
# a final check after the configuration is complete
#
platform_setup_internals()
{
	[ -z "$uefiboot" ] && [ -z "$esp_size" ] ||
		fatal F000 "UEFI boot is not supported on %s!" "$platform"
	[ -n "$prepsize" ] ||
		fatal F000 "PReP partition size is not defined!"
	add_chroot_var preppart
	biosboot_too=
	uefi2bios=
	bios2uefi=
	bbp_size=
}

# Called from the chroot, it installs one
# or more platform-specific bootloader(s)
#
setup_bootloaders_platform()
{
	local v img="/boot/grub/powerpc-ieee1275/core.elf"

	if [ -s "$img" ]; then
		log "Copying bootloader part for %s to the PReP partition..." "$platform"
		[ -n "$keep_uuids" ] && [ -s /boot/grub/grub.cfg ] ||
			need_grub_update=1
		dd if="$img" of="$preppart" bs=1M >/dev/null 2>&1 ||:
	else
		log "Installing bootloader %s for %s..." "grub-ieee1275" "$platform"
		need_grub_update=1

		for v in ${multi_targets:-$target}; do
			run grub-install \
				--target=powerpc-ieee1275 $grub_install_opts \
				--boot-directory=/boot --recheck -- "$v"
		done
	fi
}

