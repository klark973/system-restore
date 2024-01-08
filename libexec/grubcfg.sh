###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

########################################################
### Default implementation of the grub config editor ###
########################################################

__make_new_grubcfg()
{
	local f k v s cmdline

	# Don't touch real grub config in dry-run mode
	[ -n "$dryrun" ] && f="$workdir/GRUBCFG" ||
		f="$destdir/etc/sysconfig/grub2"

	# Store original /proc/cmdline
	k="GRUB_CMDLINE_LINUX_DEFAULT"
	v="$(grep -sE "^$k=" "$f" |
		cut -f2- -d= |
		sed -E 's,^[\'\"],,' |
		sed -E 's,[\'\"]$,,')"
	cmdline="$v"

	# Remove invalid 'smem=1' on ALT 8SP
	run sed -i 's, smem=1,,' "$f"

	# Change SWAP partition UUID
	if [ -z "$swappart" ] || [ -z "$swapuuid" ]; then
		[ -n "${cmdline##*resume=*}" ] ||
			v="$(echo -n "$cmdline" |
				sed -E 's,resume=[^\s]*\s*,,')"
	else
		s="resume=/dev/disk/by-uuid/$swapuuid"
		if [ -n "${cmdline##*resume=*}" ]; then
			v="$s $cmdline"
		else
			v="$(echo -n "$cmdline" |
				sed -E "s,resume=[^\s]*,$s,")"
		fi
	fi
	run sed -i -E "s,^$k=.*$,$k='$v'," "$f"

	# Change drive ID for valid grub auto-update
	v="$(mountpoint -x -- "$target" 2>/dev/null ||:)"
	if [ -z "$v" ] || [ ! -s "/run/udev/data/b$v" ]; then
		fatal F000 "Can't retrive the target drive ID!"
	else
		v="$(grep -s 'S:disk/by-id/' "/run/udev/data/b$v" |cut -f2- -d:)"
		if [ -z "$v" ] || [ ! -L "/dev/$v" ]; then
			fatal F000 "Can't retrive the target drive ID!"
		else
			k="GRUB_AUTOUPDATE_DEVICE"
			s="Invalid target drive ID, may be device is damaged?"
			# Sic! This is a checked way for detecting damaged media!
			run sed -i -E "s,^(#?\s*$k)=.*$,\1='/dev/$v '," "$f" 2>/dev/null ||
				fatal F000 "$s"
		fi
	fi

	# Log results
	fdump "$f"

	# Make early grub config for UEFI boot mode
	if [ -n "$uefiboot" ] && [ -n "$esp_part" ]; then
		v="$(grep -sE '^GRUB_BOOTLOADER_ID=' "$f" |cut -f2- -d=)"
		eval "v=$v" 2>/dev/null ||:
		v="${v:-altlinux}"
		[ -n "$dryrun" ] && f="$workdir/GRUBCFG" ||
			f="$destdir/boot/efi/EFI/$v/grub.cfg"
		if [ -n "$bootpart" ] && [ -n "$bootuuid" ]; then
			run mkdir -p "$destdir/boot/efi/EFI/$v"
			cat >"$f" <<-EOF
			search.fs_uuid $bootuuid root 
			set prefix=(\$root)'/grub'
			configfile \$prefix/grub.cfg
			EOF
			fdump "$f"
		elif [ -n "$rootpart" ] && [ -n "$rootuuid" ]; then
			run mkdir -p "$destdir/boot/efi/EFI/$v"
			cat >"$f" <<-EOF
			search.fs_uuid $rootuuid root 
			set prefix=(\$root)'/boot/grub'
			configfile \$prefix/grub.cfg
			EOF
			fdump "$f"
		fi
	fi
}

