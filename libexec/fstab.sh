###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#######################################################
### Default implementation of the /etc/fstab editor ###
#######################################################

__make_new_fstab()
{
	local f old_uuid

	# Don't touch real /etc/fstab in dry-run mode
	[ -n "$dryrun" ] && f="$workdir/FSTABLE" ||
		f="$destdir/etc/fstab"

	# Editing ESP (EFI System Partition) entry
	if [ -n "$esp_part" ] && [ -n "$esp_uuid" ]; then
		if [ -z "$keep_uuids" ] && [ -z "$bios2uefi" ]; then
			old_uuid="$(head -n1 "$workdir/esp.uuid" |sed 's,\-,\\-,g')"
			run sed -i -e "s,^UUID=$old_uuid,UUID=$esp_uuid," "$f"
		elif [ -n "$bios2uefi" ]; then
			cat >>"$f" <<-EOF
			UUID=$esp_uuid	/boot/efi vfat	$esp_opts	1 2
			EOF
		fi
	elif [ -n "$uefi2bios" ]; then
		old_uuid="$(head -n1 "$workdir/esp.uuid" |sed 's,\-,\\-,g')"
		run sed -i -E "/^UUID=$old_uuid\s+/d" "$f"
		run sed -i -E "/\s+\/boot\/efi\s+/d" "$f"
	fi

	# Editing SWAP partition entry
	if [ -n "$swappart" ] && [ -n "$swapuuid" ]; then
		if [ -z "$keep_uuids" ] && [ -s "$workdir/swap.uuid" ]; then
			old_uuid="$(head -n1 "$workdir/swap.uuid" |sed 's,\-,\\-,g')"
			run sed -i -e "s,^UUID=$old_uuid,UUID=$swapuuid," "$f"
		elif [ ! -s "$workdir/swap.uuid" ]; then
			cat >>"$f" <<-EOF
			UUID=$swapuuid	swap swap	defaults	0 0
			EOF
		fi
	elif [ -s "$workdir/swap.uuid" ]; then
		old_uuid="$(head -n1 "$workdir/swap.uuid" |sed 's,\-,\\-,g')"
		run sed -i -E "/^UUID=$old_uuid\s+/d" "$f"
		run sed -i -E "/\s+swap\s+swap\s+/d" "$f"
	fi

	# Editing system partitions entries
	if [ -z "$keep_uuids" ] && [ -n "$bootpart" ] && [ -n "$bootuuid" ]; then
		old_uuid="$(head -n1 "$workdir/boot.uuid" |sed 's,\-,\\-,g')"
		run sed -i -e "s,^UUID=$old_uuid,UUID=$bootuuid," "$f"
	fi
	if [ -z "$keep_uuids" ] && [ -n "$rootpart" ] && [ -n "$rootuuid" ]; then
		old_uuid="$(head -n1 "$workdir/root.uuid" |sed 's,\-,\\-,g')"
		run sed -i -e "s,^UUID=$old_uuid,UUID=$rootuuid," "$f"
	fi
	if [ -z "$keep_uuids" ] && [ -n "$var_part" ] && [ -n "$var_uuid" ]; then
		old_uuid="$(head -n1 "$workdir/var.uuid" |sed 's,\-,\\-,g')"
		run sed -i -e "s,^UUID=$old_uuid,UUID=$var_uuid," "$f"
	fi

	# Editing /home partition entry
	if [ -n "$homepart" ] && [ -n "$homeuuid" ]; then
		if [ -z "$keep_uuids" ] && [ -s "$workdir/home.uuid" ]; then
			old_uuid="$(head -n1 "$workdir/home.uuid" |sed 's,\-,\\-,g')"
			run sed -i -e "s,^UUID=$old_uuid,UUID=$homeuuid," "$f"
		elif [ ! -s "$workdir/home.uuid" ]; then
			cat >>"$f" <<-EOF
			UUID=$homeuuid	/home	ext4	relatime,nosuid	1 2
			EOF
		fi
	fi

	# Optimizations for SSD/NVME
	[ -z "$use_ssd" ] ||
		run sed -i -e "s/relatime/noatime,discard/" "$f"

	# Log results
	fdump "$f"
}

