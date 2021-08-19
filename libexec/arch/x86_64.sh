###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

# Called before including restore.ini files
# supplied with the backup and/or sub-profile,
# it changes platform-specific defaults and
# checks platform-specific requirements
#
check_prereq_platform()
{
	# BIOS Boot partition default size
	bbp_size=1M

	# EFI System partition default size
	esp_size=256M

	# x86_64 supports NVRAM in UEFI-boot mode
	have_nvram="$uefiboot"
}

# Called before starting any recovery action, it
# modifies platform-specific settings and performs
# a final check after the configuration is complete
#
setup_privates_platform()
{
	# Resetting BIOS Boot partition
	if [ "$pt_schema" = dos ]; then
		bbp_size=
	elif [ "$pt_schema" = gpt ]; then
		[ -z "$uefiboot" ] || [ -n "$biosboot_too" ] ||
			bbp_size=
	fi

	# Determinating convert mode
	if [ -s "$backup"/esp.tgz ] ||
		[ -s "$workdir"/esp.uuid ] ||
		grep -sE '^UUID=' "$workdir"/FSTABLE |
			grep -qsE '\s+\/boot\/efi\s+'
	then
		[ -n "$uefiboot" ] || uefi2bios=1
	else
		[ -z "$uefiboot" ] || bios2uefi=1
	fi

	# Convert allowed with deploy action only
	if [ -n "$uefi2bios" ] || [ -n "$bios2uefi" ]; then
		local msg="Use deploy mode for restore from this backup!"
		[ "$action" = deploy ] || fatal F000 "$msg"
	fi
}

# Called from the chroot, it install one
# or more platform-specific bootloader(s)
#
setup_bootloaders_platform()
{
	if [ -z "$uefiboot" ] || [ -n "$biosboot_too" ]; then
		log "Installing %s for BIOS/CSM boot mode..." "grub-pc"
		run grub-install --target=i386-pc $grub_install_opts \
			--boot-directory=/boot --recheck -- "$target"
		need_grub_update=1
	fi

	if [ -n "$uefiboot" ]; then
		local f="BOOT/BOOTX64.EFI"

		[ -n "$safe_uefi_boot" ] && [ -s "/boot/efi/EFI/$f" ] ||
			f="$efi_distributor/grubx64.efi"

		if [ -s /boot/grub/x86_64-efi/core.efi ] && [ -s "/boot/efi/EFI/$f" ]; then
			[ -n "$keep_uuids" ] && [ -s /boot/grub/grub.cfg ] ||
				need_grub_update=1
			log "Bootloader %s for %s already installed" "grub-efi" "$platform"
		else
			log "Installing bootloader %s for %s..." "grub-efi" "$platform"
			run grub-install --target=x86_64-efi $grub_install_opts \
				--efi-directory=/boot/efi --recheck \
				--boot-directory=/boot -- "$target"
			need_grub_update=1
		fi
	fi
}

