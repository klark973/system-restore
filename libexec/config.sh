###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

# Special hook for platform-specific function,
# can be overrided in arch/$platform.sh
#
check_prereq_platform()
{
	: # Nothing by default
}

# Special hook for platform-specific function,
# can be overrided in arch/$platform.sh
#
setup_privates_platform()
{
	: # Nothing by default
}

check_prerequires()
{
	local rg="^Hypervisor vendor\:"

	# Is this script running under hypervisor?
	hypervisor="$(LC_ALL=C lscpu 2>/dev/null |
			grep -sE "$rg" |
			sed -E 's,$rg\s*,,')"

	# Determinating UEFI-boot mode
	[ ! -d /sys/firmware/efi ] ||
		uefiboot=1

	# Determinating platform
	platform="$(uname -m)"
	[ "x$platform" != xi686 ] ||
		platform=i586

	# Including support for this platform
	rg="Platform '%s' not supported at now!"
	[ -s "$supplimental/arch/$platform.sh" ] ||
		fatal F000 "$rg" "$platform"
	. "$supplimental/arch/$platform.sh"
	check_prereq_platform
}

check_metadata_and_archives()
{
	local v cnt=0

	# Creating temporary directory
	workdir="$(mktemp -dt -- "$progname-XXXXXXXX.tmp")" ||
		fatal F000 "Can't create working directory!"
	trap exit_handler EXIT

	# Checking the backup
	echo "Checking backup and metadata..."
	for v in tgz tbz2 txz; do
		[ -s "$backup/META.$v" ] && [ -s "$backup/root.$v" ] ||
			continue
		ziptype="$v"
		break
	done
	[ -n "$ziptype" ] ||
		fatal F000 "META and root archives required!"
	cd "$workdir"/
	tar -xpf "$backup/META.$ziptype" 2>/dev/null ||
		fatal F000 "Can't unpack META.$ziptype!"
	v="$(head -n1 VERSION 2>/dev/null ||:)"
	case "$v" in
	0.[1-9]*)
		;;
	*)	fatal F000 "Unsupported backup verison: %s" "$v"
		;;
	esac
	#
	[ -s ARCH    ] &&
	[ -s FSTABLE ] &&
	[ -s LOADERS ] &&
	[ -s RELEASE ] &&
	[ -s RNDSEED ] &&
	[ -s TARGETS ] &&
	[ -s VOLUMES ] &&
	[ -s ZIPTYPE ] &&
	[ -s root.size ] &&
	[ -s root.uuid ] &&
	[ -s blkid.tab ] ||
		fatal F000 "Invalid metadata contents!"
	v="$(head -n1 ZIPTYPE ||:)"
	[ "x$v" = "x$ziptype" ] ||
		fatal F000 "Unsupported archives type in the backup: '%s'!" "$v"
	v="$(head -n1 ARCH ||:)"
	[ "x$v" != xi686 ] ||
		v=i586
	[ "x$v" = "x$platform" ] ||
		fatal F000 "This backup for '%s' platform only!" "$v"
	#
	while IFS=' ' read -r v; do
		[ -s "$v.sfdisk" ] ||
			fatal F000 "%s.sfdisk required!" "$v"
		if grep -qsE '^label: gpt$' "$v.sfdisk"; then
			pt_schema=gpt
		elif [ -z "$pt_schema" ] &&
			grep -qsE '^label: dos$' "$v.sfdisk"
		then
			pt_schema=dos
		fi
		cnt=$((1 + $cnt))
	done <TARGETS
	#
	[ -n "$pt_schema" ] ||
		fatal F000 "Metadata for target device not found!"
	[ "$cnt" = 1 ] || [ "$action" != fullrest ] && [ "$action" != sysrest ] ||
		fatal F000 "Use deploy mode for restore from this backup!"
	[ ! -s "$backup/esp.$ziptype"  ] || [ -s esp.size  ] && [ -s esp.uuid  ] ||
		fatal F000 "Metadata for '%s' not found!" "esp.$ziptype"
	[ ! -s "$backup/boot.$ziptype" ] || [ -s boot.size ] && [ -s boot.uuid ] ||
		fatal F000 "Metadata for '%s' not found!" "boot.$ziptype"
	[ ! -s "$backup/var.$ziptype"  ] || [ -s var.size  ] && [ -s var.uuid  ] ||
		fatal F000 "Metadata for '%s' not found!" "var.$ziptype"
	[ ! -s "$backup/home.$ziptype" ] || [ -s home.size ] && [ -s home.uuid ] ||
		fatal F000 "Metadata for '%s' not found!" "home.$ziptype"
	[ ! -f esp.size  ] && [ ! -f esp.uuid  ] || [ -s "$backup/esp.$ziptype"  ] ||
		fatal F000 "Backup '%s' not found!" "esp.$ziptype"
	[ ! -f boot.size ] && [ ! -f boot.uuid ] || [ -s "$backup/boot.$ziptype" ] ||
		fatal F000 "Backup '%s' not found!" "boot.$ziptype"
	[ ! -f var.size  ] && [ ! -f var.uuid  ] || [ -s "$backup/var.$ziptype"  ] ||
		fatal F000 "Backup '%s' not found!" "var.$ziptype"
	if [ ! -s "$backup/home.$ziptype" ] && [ -z "$create_users" ]; then
		[ ! -f home.size ] && [ ! -f home.uuid ] ||
			fatal F000 "Backup '%s' not found!" "home.$ziptype"
	fi

	# Changing defaults
	[ ! -s ORGHOST ] ||
		template="$(head -n1 ORGHOST |cut -f1 -d.)"
	[ -s checksum.256 ] ||
	[ -s checksum.SHA ] ||
	[ -s checksum.MD5 ] ||
	[ -s "$backup/update.$ziptype" ] ||
	[ -n "$profile" ] && [ -s "$backup/$profile/update.$ziptype" ] ||
		validate=

	# Loading partition sizes
	[ ! -s "$backup/esp.$ziptype" ] ||
		esp_size="$(head -n1 esp.size)M"
	[ ! -s bbp.size  ] ||
		bbp_size="$(head -n1 bbp.size)M"
	[ ! -s prep.size ] ||
		prepsize="$(head -n1 prep.size)M"
	[ ! -s swap.size ] ||
		swapsize="$(head -n1 swap.size)M"
	[ ! -s "$backup/boot.$ziptype" ] ||
		bootsize="$(head -n1 boot.size)M"
	rootsize="$(head -n1 root.size)M"
	[ -n "$create_users"         ] ||
	[ -s "$backup/var.$ziptype"  ] ||
	[ -s "$backup/home.$ziptype" ] ||
		rootsize=

	[ "$action" != chkmeta ] ||
		fatal F000 "Metadata checked successfully."
	cd -
}

get_profiles_list()
{
	local pdir dname

	find "$backup" -mindepth 2 -maxdepth 2 -type d -name id |
	while read -r pdir; do
		dname="${pdir%/*}"
		echo " ${dname##*/}"
	done
}

is_this_profile()
{
	local dir1 dir2 f l r list

	dir1="/sys/class/dmi/id"
	dir2="$backup/$profile/id"
	[ -d "$dir1" ] && [ -d "$dir2" ] ||
		return 1
	list="$(set +f; ls -- "$dir2"/)"

	for f in $list _; do
		[ -r "$dir2/$f" ] ||
			continue
		[ -e "$dir1/$f" ] ||
			return 1
		l=""; r=""
		read -r l <"$dir1/$f" 2>/dev/null ||:
		read -r r <"$dir2/$f" 2>/dev/null ||:
		[ -n "$l" ] && [ "x$l" = "x$r" ]  ||
			return 1
	done
}

__setup_profile()
{
	[ -n "$profile" ] || [ -z "$hypervisor" ] ||
		profile=virtual

	if [ -n "$profile" ]; then
		[ -f "$backup/$profile"/restore.ini     ] ||
		[ -f "$backup/$profile"/config.sh       ] ||
		[ -s "$backup/$profile/update.$ziptype" ] ||
		[ -d "$backup/$profile/id"              ] ||
			profile=
	else
		for profile in $(get_profiles_list) _; do
			is_this_profile && break || profile=
		done

		[ -n "$profile" ] && [ -d "$backup/$profile" ] || profile=
	fi

	if [ -z "$hypervisor" ] && [ "$profile" != virtual ]; then
		baremetal="${profile:-1}"
	else
		baremetal=
	fi
}

__check_config()
{
	local tool

	if [ -z "$uefiboot" ]; then
		biosboot_too=
		safe_uefi_boot=
		esp_size=
	fi

	[ -s "$backup/boot.$ziptype" ] ||
		bootsize=
	[ -n "$create_users"         ] ||
	[ -s "$backup/var.$ziptype"  ] ||
	[ -s "$backup/home.$ziptype" ] ||
		rootsize=
	[ "$action" != validate ] ||
		validate=1
	[ -s "$workdir"/checksum.256 ] ||
	[ -s "$workdir"/checksum.SHA ] ||
	[ -s "$workdir"/checksum.MD5 ] ||
	[ -s "$backup/update.$ziptype" ] ||
	[ -n "$profile" ] && [ -s "$backup/$profile/update.$ziptype" ] ||
		validate=

	if [ "$action" = deploy ]; then
		if [ "x$swapsize" = xAUTO ]; then
			swapsize="$(grep -sE '^MemTotal:' /proc/meminfo |
					head -n1 |awk '{print $2;}')"
			swapsize="$(( $swapsize / 1024 / 1024 + 1 ))"
			[ "$swapsize" -gt 4 ] 2>/dev/null ||
				swapsize="$(( $swapsize * 2 ))"
			swapsize="$(( $swapsize * 1024 ))M"
		fi
		[ -z "$force_mbr_label" ] ||
			pt_schema=dos
		[ -z "$force_gpt_label" ] ||
			pt_schema=gpt
		unique_clone=1
	fi

	[ -n "$unique_clone" ] ||
		cleanup_after=
	[ -z "$hypervisor" ] && [ "$profile" != virtual ] ||
		baremetal=
	[ -z "$uefiboot" ] || [ -z "$biosboot_too" ] || [ -n "$bbp_size" ] ||
		fatal F000 "BIOS Boot partition size not defined!"
	[ -z "$uefiboot" ] && [ -z "$prepsize" ] ||
		required_tools="$required_tools efibootmgr"
	[ -z "$use_logger" ] ||
		required_tools="$required_tools logger"
	[ -z "$use_dialog" ] ||
		required_tools="$required_tools dialog"

	for tool in $required_tools _; do
		[ "$tool" != _ ] || continue
		command -v "$tool" >/dev/null ||
			fatal F000 "Required tool not found: '%s'!" "$tool"
	done

	[ "$action" != chkconf ] ||
		fatal F000 "Configuration checked successfully."
	uefi2bios=
	bios2uefi=
}

# Can be overrided in $backup/config.sh
#
setup_profile()
{
	__setup_profile
}

# Can be overrided in $backup/config.sh
# or $backup/$profile/config.sh
#
check_config()
{
	__check_config
}

