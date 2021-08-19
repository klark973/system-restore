###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

############################################################
### Create 'id' directory for sub-profile auto-detection ###
############################################################

[ -d /sys/class/dmi/id ] ||
	fatal F000 "DMI Information not supported on this platform."
cd "$backup"/
mkdir -p id

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
	[ -r "/sys/class/dmi/id/$field" ] ||
		continue
	v="$(head -n1 "/sys/class/dmi/id/$field" 2>/dev/null ||:)"
	[ -z "$v" ] || echo "$v" >"id/$field"
done

# Try to remove empty directory
rmdir id 2>/dev/null && fatal F000 "DMI Information records not found." ||:

exit 0

