###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#############################################################
### Creates 'id' directory for sub-profile auto-detection ###
#############################################################

d=/sys/class/dmi/id
[ -d "$d" ] ||
	d=/sys/devices/virtual/dmi/id
[ -d "$d" ] ||
	fatal F000 "DMI information is not supported on this platform."
mkdir -p -m0755 id
umask 0022

for field in \
	bios_vendor \
	board_name \
	board_vendor \
	board_version \
	chassis_type \
	chassis_vendor \
	chassis_version \
	product_family \
	product_name \
	product_sku \
	product_uuid \
	product_version \
	sys_vendor
do
	[ -r "$d/$field" ] ||
		continue
	v="$(head -n1 -- "$d/$field" 2>/dev/null ||:)"

	if [ -n "$v" ]; then
		echo "$v" >"id/$field"
		echo "$field" >>id/FILELIST
	fi
done

# Trying to remove an empty directory
rmdir id &>/dev/null && fatal F000 "DMI information records not found." ||:

exit 0
