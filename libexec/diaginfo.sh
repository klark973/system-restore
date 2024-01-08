###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

###########################
### Showing diagnostics ###
###########################

show_diag_info()
{
	local bold="\033[01;37m"
	local norm="\033[00m"
	local tbh="$have_tbh"

	show_src_list()
	{
		printf "Source devices:\n"

		while [ "$#" -gt 0 ]; do
			printf  "  - %s\n" "$1"
			shift
		done
	}

	if [ "${1-}" = "--nc" ]; then
		bold=
		norm=
		shift
	fi

	printf "\n"
	[ -z "$profile" ] ||
		printf "Profile name:   %s\n" "$profile"
	printf "Computer name:  %s\n" "$computer"
	printf "Partitioner:    %s (%s)\n" "$partitioner" "$pt_scheme"

	if [ -z "$multi_targets" ]; then
		printf "Target device:  %s\n" "${target}${diskinfo:+ ($diskinfo)}"
	elif [ -z "$imsm_container" ]; then
		printf "Target device:  %s\n" "$target"
		show_src_list "${diskinfo[@]}"
	else
		printf "IMSM container: %s\n" "$imsm_container"
		printf "Target array:   %s\n" "$target"
		show_src_list "${diskinfo[@]}"
	fi

	[ "$tbh" = 1 ] && tbh="" ||
		tbh=" (${bold}${tbh}${norm})"
	printf "System time:    %s\n" "$(LC_TIME=C date +'%F %H:%M %Z')"

	[ -z "$hypervisor" ] ||
		printf "Hypervisor:     Yes (${bold}%s${norm})\n" "$hypervisor"
	[ -z "$baremetal"  ] ||
		printf "Bare metal:     Yes (${bold}%s${norm})\n" "$baremetal"
	[ -z "$check_tbh"  ] || [ -z "$have_tbh" ] ||
		printf "Trusted boot:   Yes$tbh\n"
	[ -z "$preppart"   ] ||
		printf "PReP size:      %s (%s)\n" "$prepsize" "$preppart"
	[ -z "$esp_part"   ] ||
		printf "ESP size:       %s (%s)\n" "$esp_size" "$esp_part"
	[ -z "$bbp_part"   ] ||
		printf "BBP size:       %s (%s)\n" "$bbp_size" "$bbp_part"
	[ -z "$bootpart"   ] ||
		printf "BOOT size:      %s (%s)\n" "$bootsize" "$bootpart"
	[ -z "$swappart"   ] ||
		printf "SWAP size:      %s (%s)\n" "$swapsize" "$swappart"
	[ -z "$rootpart"   ] ||
		printf "ROOT size:      %s (%s)\n" "${rootsize:-*}" "$rootpart"
	[ -z "$datapart"   ] ||
		printf "DATA size:      * (%s)\n" "$datapart"
	printf "\n"
}

[ -z "$use_dialog" ] ||
	show_diag_info --nc >"$workdir"/DIAG.txt
show_diag_info
echo "All devices:"
lsblk -f
printf "\n"

