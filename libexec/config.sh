###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

# Special hook for platform-specific function,
# it can be overridden in arch/$platform.sh
#
check_prereq_platform()
{
	: # Do nothing by default
}

# Special hook for platform-specific function,
# it can be overridden in arch/$platform.sh
#
platform_setup_internals()
{
	: # Do nothing by default
}

# It is called before parsing the configuration
#
check_prerequires()
{
	local v="s/\s*Hypervisor vendor:\s+//p"

	# Is this script running under hypervisor?
	hypervisor="$(LC_ALL=C lscpu 2>/dev/null |sed -n -E "$v")"

	# Determinating UEFI-boot mode
	[ ! -d /sys/firmware/efi ] ||
		uefiboot=1

	# Determinating platform
	platform="$(uname -m)"
	case "$platform" in
	i?86|pentium|athlon)
		platform=i586
		;;
	esac

	# Including support for this platform
	v="Platform '%s' is not supported yet!"
	[ -s "$libdir/arch/$platform.sh" ] ||
		fatal F000 "$v" "$platform"
	. "$libdir/arch/$platform.sh"
	check_prereq_platform
}

# Default implementation for check <volume>.sfdisk files
# and auto-detect partitioning scheme inside the backup.
# In some cases this is not very good when underlying disks
# aren't partitioned, it can be overridden in $backup/config.sh
#
check_volume_layouts()
{
	local v llba=0 secsz=0 cnt=0

	pt_scheme=

	for v in $(cat TARGETS); do
		[ -s "$v.sfdisk" ] ||
			fatal F000 "%s.sfdisk is required!" "$v"
		llba="$(sed -n -E 's/^last\-lba: //p' "$v.sfdisk")"
		secsz="$(sed -n -E 's/^sector\-size: //p' "$v.sfdisk")"

		if grep -qsE '^label: gpt$' "$v.sfdisk"; then
			pt_scheme=gpt
		elif [ -z "$pt_scheme" ] &&
			grep -qsE '^label: dos$' "$v.sfdisk"
		then
			pt_scheme=dos
		fi

		cnt=$((1 + $cnt))
	done

	[ -n "$pt_scheme" ] &&
	is_number "$llba" && is_number "$secsz" &&
	[ "$llba" -gt 6 ] && [ "$secsz" -ge 512 ] ||
		fatal F000 "Metadata for target device(s) not found!"

	if [ "$cnt" != 1 ]; then
		case "$action" in
		fullrest|sysrest)
			fatal F000 "Use deployment mode to restore from this backup!"
			;;
		esac
	elif [ "$action" = fullrest ]; then
		case "$secsz" in
		512)	v="$(( (1 + $llba) / 2 ))";;
		4096)	v="$(( (1 + $llba) * 4 ))";;
		*)	fatal F000 "Unsupported sector size (%s) in metadata!" "$secsz";;
		esac
		target_max_capacity=
		target_min_capacity="${v}K"
	fi
}

# Checks archives and metadata of the backup
#
check_backup_metadata()
{
	local v

	# Creating a temporary directory
	workdir="$(mktemp -dt -- "$progname-XXXXXXXX.tmp")" ||
		fatal F000 "Can't create working directory!"
	trap exit_handler EXIT

	# Checking the backup
	msg "${L0000-Checking backup and metadata...}"
	for v in tgz txz tbz2; do
		is_file_exists "META.$v" && is_file_exists "root.$v" ||
			continue
		ziptype="$v"
		break
	done
	[ -n "$ziptype" ] ||
		fatal F000 "META and root archives are required!"
	case "$ziptype" in
	tgz)	v=z;;
	txz)	v=J;;
	tbz2)	v=j;;
	esac
	cd -- "$workdir"/
	read_file "META.$ziptype" |tar -xp${v}f - ||
		fatal F000 "Can't unpack 'META.%s'!" "$ziptype"
	v="$(head -n1 VERSION 2>/dev/null ||:)"
	case "$v" in
	0.[1-9]*)
		# It's OK
		;;
	*)	fatal F000 "Unsupported backup verison: %s" "$v"
		;;
	esac
	#
	[ -s ARCH    ] &&
	[ -s FSTABLE ] &&
	[ -s LOADERS ] &&
	[ -s RELEASE ] &&
	[ -s TARGETS ] &&
	[ -s VOLUMES ] &&
	[ -s ZIPTYPE ] &&
	[ -s root.size ] &&
	[ -s root.uuid ] &&
	[ -s blkid.tab ] ||
		fatal F000 "Invalid metadata contents!"
	v="$(head -n1 ZIPTYPE ||:)"
	[ "$v" = "$ziptype" ] ||
		fatal F000 "Unsupported archives type in the backup: '%s'!" "$v"
	v="$(head -n1 ARCH ||:)"
	case "$v" in
	i?86|pentium|athlon)
		v=i586
		;;
	esac
	[ "$v" = "$platform" ] ||
		fatal F000 "This backup is for '%s' platform only!" "$v"
	check_volume_layouts
	#
	for v in boot esp var home; do
		if is_file_exists "$v.$ziptype"; then
			[ -s "$v.size" ] && [ -s "$v.uuid" ] ||
				fatal F000 "Metadata for '%s' not found!" "$v.$ziptype"
		elif [ "$v" != home ] || [ -z "$create_users_list" ]; then
			[ ! -f "$v.size" ] && [ ! -f "$v.uuid" ] ||
				fatal F000 "Backup '%s' not found!" "$v.$ziptype"
		fi
	done

	# Changing defaults
	[ -n "$template"  ] || [ ! -s ORGHOST    ] ||
		template="$(head -n1 ORGHOST |cut -f1 -d.)"
	[ -s checksum.256 ] || [ -s checksum.SHA ] || [ -s checksum.MD5 ] ||
	[ -n "$profile" ] && is_file_exists "$profile/update.$ziptype" ||
	is_file_exists "update.$ziptype" ||
		validate=

	# Loading partition sizes
	is_file_exists "boot.$ziptype" &&
		bootsize="$(head -n1 boot.size)M" ||:
	is_file_exists "esp.$ziptype"  &&
		esp_size="$(head -n1 esp.size)M"  ||:
	[ ! -s bbp.size  ] ||
		bbp_size="$(head -n1 bbp.size)M"
	[ ! -s prep.size ] ||
		prepsize="$(head -n1 prep.size)M"
	[ ! -s swap.size ] ||
		swapsize="$(head -n1 swap.size)M"
	rootsize="$(head -n1 root.size)M"

	if [ -n "$create_users_list" ] || is_file_exists "home.$ziptype"; then
		datapart_mp=/home
	elif is_file_exists "var.$ziptype"; then
		datapart_mp=/var
	else
		rootsize=
	fi

	[ "$action" != chkmeta ] ||
		fatal F000 "Metadata checked successfully!"
	cd - >/dev/null ||:
}

# Try to include config file or script with the user-defined hooks
#
user_config()
{
	local cfg

	is_file_exists "$1" ||
		return 0

	if [ "$backup_proto" = file ]; then
		cfg="$backup/$1"
	else
		cfg="$workdir/tmp-user.sh"
		read_file "$1" >"$cfg"
	fi

	( . "$cfg" ) >/dev/null 2>&1 ||
		fatal F000 "Invalid source or config file: %s" "$1"
	. "$cfg"
	[ "$backup_proto" = file ] || rm -f -- "$cfg"
}

# Load profiles list from the remote server
#
get_profiles_list()
{
	local pdir dname

	if [ "$backup_proto" = file ]; then
		find "$backup" -mindepth 2 -maxdepth 2 -type d -name id |
		while read -r pdir; do
			dname="${pdir%/*}"
			echo "${dname##*/}"
		done
	elif is_file_exists PROFILES; then
		read_file PROFILES
	fi
}

# Compare DMI information with specified profile
#
is_it_that_profile()
{
	local dir1=/sys/class/dmi/id
	local dir2="$profile/id" f l r list

	[ -d "$dir1" ] && is_file_exists "$dir2"/FILELIST ||
		return 1
	list="$(read_file "$dir2"/FILELIST)"

	for f in $list; do
		[ -r "$dir1/$f" ] && is_file_exists "$dir2/$f" ] ||
			return 1
		l="$(head -n1 -- "$dir1/$f" ||:)"
		r="$(read_file   "$dir2/$f" ||:)"
		[ "$l" = "$r" ] || return 1
	done

	return 0
}

# Default implementation for check specified profile,
# it can be overridden in $backup/config.sh
#
check_profile()
{
	is_file_exists "$profile"/id/FILELIST     ||
	is_file_exists "$profile"/restore.ini     ||
	is_file_exists "$profile"/config.sh       ||
	is_file_exists "$profile/update.$ziptype" ||
		fatal F000 "Invalid profile specified: '%s'." "$profile"
}

# Default implementation for auto-detect profile,
# it can be overridden in $backup/config.sh
#
search_profile()
{
	for profile in $(get_profiles_list); do
		is_it_that_profile && break ||
			profile=
	done
}

# System-wide wrapper over search_profile() and
# check_profile(), don't override this function
#
setup_profile()
{
	if [ -n "$profile" ]; then
		check_profile
	else
		if [ -n "$hypervisor" ]; then
			profile=virtual
		else
			search_profile
		fi
		if [ -n "$profile" ]; then
			is_dir_exists "$profile" ||
				profile=
		fi
	fi
	if [ -n "$hypervisor" ] || [ "$profile" = virtual ]; then
		baremetal=
	elif [ -z "$baremetal" ]; then
		baremetal="${profile:-1}"
	fi
}

# An additional single-drive configuration checker,
# it can be overridden in $libdir/part/$partitioner.sh
# or $backup/$partitioner.sh
#
single_drive_config()
{
	: # Do nothing by default
}

# Default implementation of the additional multi-drives configuration
# checker, it can be overridden in $libdir/part/$partitioner.sh or
# $backup/$partitioner.sh
#
multi_drives_config()
{
	[ "$action" != fullrest ] && [ "$action" != sysrest ] ||
		fatal F000 "Use deployment mode with the multi-drives configuration."
}

# Here is a place to safely setup user-defined hooks once
# the configuration is complete, it can be overridden in
# $backup/config.sh or $backup/$profile/config.sh
#
post_config_setup()
{
	: # Do nothing by default
}

# Default implementation of the configuration checker
#
__check_config()
{
	local i list=

	# Resetting unused flags
	if [ -z "$uefiboot" ]; then
		biosboot_too=
		safe_uefi_boot=
		esp_size=
		have_nvram=
	fi

	# Changing defaults
	is_file_exists "boot.$ziptype" ||
		bootsize=
	[ -n "$create_users_list" ]    ||
	is_file_exists "var.$ziptype"  ||
	is_file_exists "home.$ziptype" ||
		rootsize=
	[ -s checksum.256 ] || [ -s checksum.SHA ] || [ -s checksum.MD5 ] ||
	[ -n "$profile" ] && is_file_exists "$profile/update.$ziptype" ||
	is_file_exists "update.$ziptype" ||
		validate=
	[ "$action" != validate ] ||
		validate=1

	# Tune some deployment settings
	if [ "$action" = deploy ]; then
		if [ "$swapsize" = AUTO ]; then
			swapsize="s/^MemTotal:\s+([0-9]*) .*$/\1/p"
			swapsize="$(sed -n -E "$swapsize" /proc/meminfo)"
			swapsize="$(( $swapsize / 1024 / 1024 + 1 ))"
			if [ "$swapsize" -gt 8 ]; then
				swapsize=8
			elif [ "$swapsize" -lt 4 ]; then
				swapsize="$(( $swapsize * 2 ))"
			fi
			swapsize="$(( $swapsize * 1024 ))M"
		fi
		[ -z "$force_mbr_label" ] ||
			pt_scheme=dos
		[ -z "$force_gpt_label" ] ||
			pt_scheme=gpt
		[ "$partitioner" = raid ] ||
			imsm_container=
		unique_clone=1
	fi

	# Target(s) configuration
	if [ -n "$target" ]; then
		[ -n "$num_targets" ] ||
			num_targets=1
		target="$(readlink -fv -- "/dev/${target##/dev/}" 2>/dev/null ||:)"
		[ "$num_targets" = 1 ] && [ -b "$target" ] && [ -z "$multi_targets" ] ||
			fatal F000 "Invalid target drive configuration!"
		single_drive_config
	elif [ -n "$multi_targets" ]; then
		num_targets=0
		ppartsep=

		for i in $multi_targets; do
			i="$(readlink -fv -- "/dev/${i##/dev/}" 2>/dev/null ||:)"

			if in_array "$i" $list || [ ! -b "$i" ]; then
				list=
				break
			fi

			list="$list $i"
			num_targets=$((1 + $num_targets))
		done

		[ -n "$list" ] && [ "$num_targets" -gt 1 ] ||
			fatal F000 "Invalid multi-drives configuration!"
		multi_targets="${list:1}"
		multi_drives_config
	elif [ -n "$num_targets" ]; then
		is_number "$num_targets" && [ "$num_targets" -ge 1 ] ||
			fatal F000 "Invalid target drive(s) configuration!"
		[ "$num_targets" = 1 ] ||
			multi_drives_config
		ppartsep=
	fi

	# Changing defaults
	[ -n "$unique_clone" ] ||
		cleanup_after=
	[ -z "$hypervisor" ] && [ -n "$profile" ] && [ "$profile" != virtual ] ||
		baremetal=
	[ -z "$uefiboot" ] || [ -z "$biosboot_too" ] || [ -n "$bbp_size" ] ||
		fatal F000 "BIOS Boot partition size is not defined!"
	[ -z "$have_nvram" ] ||
		required_tools="$required_tools efibootmgr"
	[ -z "$use_logger" ] ||
		required_tools="$required_tools logger"
	[ -z "$use_dialog" ] ||
		required_tools="$required_tools dialog tmux"
	i="$(get_proto_requires)"
	[ -z "$i" ] ||
		required_tools="$required_tools $i"
	uefi2bios=
	bios2uefi=

	# Checking the partitioner and including appropriate support
	if [ -n "$use_target" ]; then
		eval "${partitioner}_requires() {
			: Do nothing by default
		}"
		eval "${partitioner}_make_scheme() {
			: Do nothing by default
		}"
		eval "${partitioner}_post_unpack() {
			: Do nothing by default
		}"

		if [ -s "$libdir/part/$partitioner.sh" ]; then
			. "$libdir/part/$partitioner.sh"
		elif [ "$partitioner" != none ]; then
			i="The partitioner '%s' not found!"
			is_file_exist "$partitioner.sh" ||
				fatal F000 "$i" "$partitioner"
			user_config "$partitioner.sh"
		fi

		i="$(${partitioner}_requires)"
		[ -z "$i" ] || required_tools="$required_tools $i"
	fi

	# Checking pre-requires
	for i in $required_tools; do
		command -v "$i" >/dev/null 2>&1 ||
			fatal F000 "Required tool not found: '%s'!" "$i"
	done

	# Final steps
	[ "$action" != chkconf ] ||
		fatal F000 "Configuration checked successfully!"
	post_config_setup
}

# Check the final configuartion, inclusive user
# data, it can be overridden in $backup/config.sh
# or $backup/$profile/config.sh
#
check_config()
{
	__check_config
}

