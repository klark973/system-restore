#!/bin/sh -efu
###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Variables which could be empty
for var_name in $chroot_vars; do
	eval "$var_name=\${$var_name-}"
done
unset var_name

# Chroot defaults
logfile="$rundir"/log
[ -e "$logfile" ] ||
	logfile=
need_grub_update=
use_logger=
old_kernel=
efivarfs=


# Default ALT-specific logic with make-initrd,
# can be overrided in arch/$platform.sh
#
__specialize_kver()
{
	local flavour="$1" kver="$2"

	log "Linux kernel found: '%s'" "$kver"

	# Explicity ignoring keep_uuids:
	# image cleanup required for deploy
	if [ -s "/boot/initrd-$kver.img" ]; then
		log "Initramfs image found: %s" "/boot/initrd-$kver.img"
	else
		if [ ! -f "$rundir/initrd-$kver.conf" ]; then
			run make-initrd -k "$kver"
		else
			run cp -Lf -- "$rundir/initrd-$kver.conf" /etc/initrd.mk
			run make-initrd -k "$kver"
		fi
		log "Initramfs image created: %s" "/boot/initrd-$kver.img"
	fi

	[ -e "/boot/initrd-$flavour.img" ] ||
		run ln -snf -- "initrd-$kver.img" "/boot/initrd-$flavour.img"
	[ -e "/boot/initrd.img" ] ||
		run ln -snf -- "initrd-$kver.img" "/boot/initrd.img"
	log "Symbolic links to '%s' checked" "initrd-$kver.img"
}

# Default ALT-specific logic with make-initrd,
# can be overrided in arch/$platform.sh
#
__specialize_platform()
{
	local flavour kver

	[ -n "$kernel_flavours" ] ||
		return 0
	if [ -e /etc/initrd.mk ]; then
		run cp -Lf -- /etc/initrd.mk "$rundir"/
		[ ! -L /etc/initrd.mk ] ||
			run rm -f /etc/initrd.mk
	fi

	for flavour in $kernel_flavours; do
		for kver in $(ls -X1 /lib/modules/); do
			[ -z "${kver##*-$flavour-*}" ] ||
				continue
			[ "x$kver" != "x$old_kernel" ] ||
				continue
			[ -d "/lib/modules/$kver" ] ||
				continue
			if [ -n "$have_rpmdb" ]; then
				rpm -qf -- "/lib/modules/$kver" 2>&1 |
					grep -qs -- "kernel-image-" ||
						continue
			fi
			__specialze_kver "$flavour" "$kver"
		done
	done

	[ ! -e "$rundir"/initrd.mk ] ||
		run mv -f -- "$rundir"/initrd.mk /etc/
	return 0
}

# Special hook for platform-specific function,
# it can be overrided in arch/$platform.sh
#
setup_bootloaders_platform()
{
	log "setup_bootloaders_platform() not used"
}

# It can be overrided in $backup/chroot.sh
# and/or in $backup/$profile/chroot.sh
#
specialize()
{
	__specialize_platform
}

# Can be overrided in $backup/chroot.sh
# and/or in $backup/$profile/chroot.sh
#
setup_bootloaders()
{
	setup_bootloaders_platform
}

# Can be overrided in $backup/chroot.sh
# and/or in $backup/$profile/chroot.sh
#
chroot_main()
{
	log "chroot_main() hook called"
}


# Set SYSREST_VERSION and SYSREST_BUILD_DATE
. "$rundir"/version.sh

# Setup the logger
. "$rundir"/logger.sh

# Including platform-specific support
. "$rundir"/platform.sh

# Mounting special FS
run mount -t proc none /proc
run mount -t sysfs none /sys
run mount -t devpts none /dev/pts

# Adding NVRAM support
if [ -n "$have_nvram" ]; then
	if ! mountpoint -q -- /sys/firmware/efi/efivars; then
		run mount -t efivarfs efivarfs /sys/firmware/efi/efivars \
			2>/dev/null && efivarfs=1 ||:
	fi
fi

log "Execution continued in the chroot."

# Including scripts supplied with the backup and profile
[ ! -s "$rundir"/chroot.sh  ] || . "$rundir"/chroot.sh
[ ! -s "$rundir"/profile.sh ] || . "$rundir"/profile.sh

# Determinating old Linux kernel name
if [ -n "$remove_kernel_pattern" ]; then
	old_kernel="/lib/modules/$remove_kernel_pattern"
	old_kernel="$(set +f; eval "ls -d $old_kernel" 2>/dev/null ||:)"
	[ -z "$old_kernel" ] || log "OLD Linux kernel detected: %s" "$old_kernel"
fi

# Determinating target system has rpm executable and valid RPM database
if [ -z "$have_rpmdb" ] && command -v rpm >/dev/null; then
	[ "x$(rpm -qa 2>/dev/null |wc -l)" = x0 ] || have_rpmdb=1
elif [ "$have_rpmdb" = 2 ]; then
	have_rpmdb=
fi

# Specializing for current hardware
specialize

# Installing platform-specific bootloader(s)
setup_bootloaders

# Creating SSH host keys
if [ -n "$unique_clone" ] && [ -d /etc/openssh ] &&
	command -v ssh-keygen >/dev/null
then
	log "Creating SSH host keys..."
	run ssh-keygen -A
fi

# Backup/profile defined logic here
chroot_main

# Removing old Linux kernel with modules
if [ -n "$old_kernel" ] && [ -n "$have_rpmdb" ]; then
	old_kernel="$(rpm -qf -- $old_kernel 2>/dev/null ||:)"

	if [ -n "$old_kernel" ]; then
		modules="$(rpm -e -- $old_kernel 2>&1 |
				awk '{print $8;}' |
				tr '\n' ' ' ||:)"
		run rpm -e -- $modules $old_kernel
		need_grub_update=
	fi
fi

# Updating grub boot menu
if [ -n "$need_grub_update" ] && [ -d /etc/sysconfig ] &&
	command -v update-grub >/dev/null
then
	log "Updating grub configuration..."
	run update-grub
fi

log "Execution in the chroot finished successfully!"

# Finishing
{ run sync
  [ -z "$efivarfs" ]  ||
	run umount -fl /sys/firmware/efi/efivars ||:
  run umount /dev/pts || run umount -fl /dev/pts ||:
  run umount /sys     || run umount -fl /sys     ||:
  run umount /proc    || run umount -fl /proc    ||:
} 2>/dev/null

