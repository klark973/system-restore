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

# An additional multi-drives configuration checker
#
multi_drives_config()
{
	[ "$imsm_container" != 1 ] || imsm_container=/dev/md0
}

# Settings the $target variable in a multi-drives configuration
#
multi_drives_setup()
{
	target=/dev/md0
	[ "$imsm_container" != "$target" ] || target=/dev/md1
}

# Creates a disk label and applies a new partition scheme
#
apply_scheme()
{
	local cmd="LC_ALL=C sfdisk -q -f --no-reread -W always"

	msg "${L0000-Please wait, initializing target devices...}"
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
			-n $num_targets "$imsm_container" $multi_targets
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
	run wipefs -a $(set +f; ls -r -- "$target"?*) >/dev/null ||:
	rm -f -- "$disk_layout"
}

