###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#######################################################
### The "raid" disk partitioning in deployment mode ###
#######################################################

# Essentially, we use the same layout, but on multiple disks
. "$utility/part/plain.sh"

readonly MDADM_ARRAY_NAME="${MDADM_ARRAY_NAME-altlinux}"
readonly IMSM_CONTAINER_NAME="${IMSM_CONTAINER_NAME-imsm}"

# Returns a list of partitioner requirements
#
raid_requires()
{
	local r

	r="$(plain_requires)"
	r="${r:+$r }mdadm"
	[ -n "$no_md_sync" ] ||
		r="$r tput"
	printf "%s" "$r"
}

# An additional multi-drives configuration checker
#
multi_drives_config()
{
	[ "$imsm_container" != 1 ] ||
		imsm_container=/dev/md0
}

# Sets the $target variable in a multi-drives configuration
#
multi_drives_setup()
{
	__select_smallest_drive

	if [ -n "$target" ]; then
		check_target_size

		if [ "$imsm_container" = "$target" ]; then
			target=/dev/md1
		else
			target=/dev/md0
		fi
	fi
}

# Prepares partition scheme in the target array
#
raid_make_scheme()
{
	plain_make_scheme
}

# Creates a disk label and applies a new partition scheme
#
apply_scheme()
{
	local cmd="LC_ALL=C sfdisk -q -f --no-reread -W always"

	msg "${L0000-Please wait, initializing the target device(s)...}"
	wipe_targets $multi_targets

	if [ -z "$imsm_container" ]; then
		log "Creating the RAID array: %s..." "$target"
		run mdadm --create --verbose --level=raid1 --metadata=1.0	\
			  --homehost=$computer --name=$MDADM_ARRAY_NAME		\
			  --raid-devices=$num_targets "$target" $multi_targets
		run sync
	else
		log "Creating the IMSM container: %s..." "$imsm_container"
		run mdadm --create --verbose --level=container --metadata=imsm	\
			  --homehost=$computer --name=$IMSM_CONTAINER_NAME	\
			  --raid-devices=$num_targets "$imsm_container" $multi_targets
		run sync; run udevadm settle -t5 >/dev/null ||:
		log "Creating the RAID array: %s..." "$target"
		run mdadm --create --verbose --level=raid1			\
			  --homehost=$computer --name=$MDADM_ARRAY_NAME		\
			  --raid-devices=$num_targets "$target" "$imsm_container"
		run sync
	fi

	run udevadm settle -t5 >/dev/null ||:
	wipe_targets "$target"
	log "Initializing the RAID array: %s..." "$target"
	run $cmd -X "$pt_scheme" -- "$target" <"$disk_layout"
	rereadpt "$target"
	run wipefs -a -- $(set +f; ls -r -- "$target"?*) >/dev/null ||:
	run rm -f -- "$disk_layout"
}

# Partitioner hook that is called after rootfs unpacking
#
raid_post_unpack()
{
	local fname

	# Editing /etc/initrd.mk
	fname="$destdir/etc/initrd.mk"
	if [ ! -f "$fname" ]; then
		echo "FEATURES += mdadm" >"$fname"
	else
		grep -sw FEATURES "$fname" |grep -qsw mdadm ||
			echo "FEATURES += mdadm" >>"$fname"
	fi

	# Creating /etc/mdadm.conf
	fname="$destdir/etc/mdadm.conf"
	if [ ! -f "$fname" ]; then
		if [ -s "$fname.sample" ]; then
			cp -Lf -- "$fname.sample" "$fname"
		else
			cat >"$fname" <<-MDADMCONF
			# /etc/mdadm.conf  --  mdadm configuration
			#
			MAILADDR root
			PROGRAM /sbin/mdadm-syslog-events
			DEVICE partitions
			#
			## EOF ##
			MDADMCONF
		fi
	fi

	# Editing /etc/mdadm.conf
	grep -qsE "^DEVICE " "$fname" ||
		echo "DEVICE partitions" >>"$fname"
	run mdadm --detail --scan --verbose |
		awk '/ARRAY/ {print}' >>"$fname"
	fdump "$fname"
}

# Returns TRUE if one of the MD-arrays is not synchronized
#
md_not_synced() {
	local md state=

	set +f

	for md in /sys/block/md*/md/sync_action; do
		[ "$md" != '/sys/block/md*/md/sync_action' ] ||
			continue
		read -r state <"$md" 2>/dev/null ||:

		if [ "$state" != idle ]; then
			set -f
			return 0
		fi
	done

	set -f

	return 1
}

# Synchronizes MD-arrays in a console mode after partitions
# are unmounted and before finalizing the primary action
#
__sync_arrays_tty()
{
	local msg="${L0000-Syncing MD-RAID(s), press ENTER to skip...}"
	local tmpstat="$workdir/mdstat.tmp"
	local cols rows lines f=10000000

	# Speeding up MD-synchronization
	lines=/proc/sys/dev/raid/speed_limit_max
	if [ -r "$lines" ]; then
		read -r rows <"$lines"
		if is_number "$rows" && [ "$f" -gt "$rows" ]; then
			log "MD-sync speed max: %s -> %s" "$rows" "$f"
			echo "$f" >"$lines"
		fi
	fi
	lines=/proc/sys/dev/raid/speed_limit_min
	if [ -r "$lines" ]; then
		read -r cols <"$lines"
		if is_number "$cols" && [ "$f" -gt "$cols" ]; then
			log "MD-sync speed min: %s -> %s" "$cols" "$f"
			echo "$f" >"$lines"
		fi
	fi

	# Show current status
	echo "$msg"
	tput cud1			# Move a cursor down

	while md_not_synced; do
		cols="$(tput cols)"
		lines="$(tput lines)"
		cat /proc/mdstat >"$tmpstat"
		rows="$(cat -- "$tmpstat" |
				wc -l |
				awk '{print $1;}')"
		is_number "$lines" && [ "$lines" -gt 0 ] &&
		is_number "$rows"  && [ "$rows"  -gt 0 ] &&
		is_number "$cols"  && [ "$cols"  -gt 0 ] ||
			break

		if [ "$((3 + $rows))" -ge "$lines" ]; then
			tput cup 0 0	# Move to the up left corner
			tput ed		# Clear all terminal
			echo "$msg"
			tput cud1	# Move the cursor down
			head -n $(($lines - 3)) -- "$tmpstat" |cut -c1-$cols
			tput cup 2 0	# Move the cursor to beginning of the row 3
		else
			tput ed		# Clear to the end of terminal
			head -n $rows -- "$tmpstat" |cut -c1-$cols

			for f in {1..$rows}; do
			    tput cuu1	# Move the cursor up
			done
		fi

		# 5 sec timeout for press ENTER and continue
		read -s -t 5 f && break ||:
	done

	# Move the cursor up twice and clear to the end of terminal
	( echo cuu1; echo cuu1; echo ed ) |tput -S

	# Garbage collection
	run rm -f -- "$tmpstat"
}

# Deinitializes all disk subsystems after partitions
# are unmounted and before finalizing the primary action
#
deinit_disks()
{
	if [ -n "$no_md_sync" ]; then
		cat /proc/mdstat
	else
		__sync_arrays_tty
	fi

	run mdadm --stop "$target"
	[ -z "$imsm_container" ] ||
		run mdadm --stop "$imsm_container"
	run mdadm --stop --scan >/dev/null ||:
}

