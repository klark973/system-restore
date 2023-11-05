###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023 ALT Linux Team

# Called before including restore.ini files
# supplied with the backup and/or profile,
# it changes platform-specific defaults and
# checks platform-specific requirements
#
check_prereq_platform()
{
	# EFI System partition default size
	esp_size=256M

	# aarch64 supports NVRAM
	have_nvram=1
}

# Called before starting any recovery action, it
# modifies platform-specific settings and performs
# a final check after the configuration is complete
#
setup_privates_platform()
{
	[ -n "$uefiboot" ] && [ -n "$esp_size" ] ||
		fatal F000 "UEFI boot and ESP are required for %s!" "$platform"
	biosboot_too=
	uefi2bios=
	bios2uefi=
	prepsize=
	bbp_size=
}

# Called from the chroot, it installs one
# or more platform-specific bootloader(s)
#
setup_bootloaders_platform()
{
	local v f="BOOT/BOOTAA64.EFI"

	[ -n "$safe_uefi_boot" ] && [ -s "/boot/efi/EFI/$f" ] ||
		f="$efi_distributor/bootaa64.efi"

	if [ -s /boot/grub/arm64-efi/core.efi ] && [ -s "/boot/efi/EFI/$f" ]; then
		[ -n "$keep_uuids" ] && [ -s /boot/grub/grub.cfg ] ||
			need_grub_update=1
		log "Bootloader %s for %s already installed" "grub-efi" "$platform"
	else
		log "Installing bootloader %s for %s..." "grub-efi" "$platform"
		need_grub_update=1

		for v in ${multi_targets:-$target}; do
			run grub-install \
				--target=arm64-efi $grub_install_opts \
				--efi-directory=/boot/efi --recheck \
				--boot-directory=/boot -- "$v"
		done
	fi
}

