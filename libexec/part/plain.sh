###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

#####################################
### Disk layouting in deploy mode ###
#####################################

# GUID/GPT partitioning
#
__prepare_gpt_layout()
{
	local i=1

	# IBM Power PReP partition
	if [ -n "$prepsize" ]; then
		echo ",$prepsize,$prepguid"
		preppart="$i"
		i=$((1 + $i))
	fi

	# EFI System partition
	if [ -n "$esp_size" ]; then
		echo ",$esp_size,U"
		esp_part="$i"
		i=$((1 + $i))
	fi

	# BIOS Boot partition
	if [ -n "$bbp_size" ]; then
		echo ",$bbp_size,$bbp_guid"
		bbp_part="$i"
		i=$((1 + $i))
	fi

	# /boot partition
	if [ -n "$bootsize" ]; then
		echo ",$bootsize"
		bootpart="$i"
		i=$((1 + $i))
	fi

	# SWAP partition
	if [ -n "$swapsize" ]; then
		echo ",$swapsize,S"
		swappart="$i"
		i=$((1 + $i))
	fi

	# ROOT partition
	echo ",$rootsize"
	rootpart="$i"

	# DATA partition
	if [ -n "$rootsize" ]; then
		i=$((1 + $i))
		echo ","
		if [ -s "$backup/var.$ziptype" ]; then
			var_part="$i"
		else
			homepart="$i"
		fi
	fi
}

# Simple DOS/MBR layout
#
__simple_dos_layout()
{
	local i=1

	# IBM Power PReP partition
	if [ -n "$prepsize" ]; then
		echo ",$prepsize,7"
		preppart="$i"
		i=$((1 + $i))
	fi

	# EFI System partition
	if [ -n "$esp_size" ]; then
		echo ",$esp_size,U"
		esp_part="$i"
		i=$((1 + $i))
	fi

	# /boot partition
	if [ -n "$bootsize" ]; then
		echo ",$bootsize,L,*"
		bootpart="$i"
		i=$((1 + $i))
	fi

	# SWAP partition
	if [ -n "$swapsize" ]; then
		echo ",$swapsize,S"
		swappart="$i"
		i=$((1 + $i))
	fi

	# ROOT partition
	if [ -z "$bootsize" ]; then
		echo ",$rootsize,L,*"
	else
		echo ",$rootsize"
	fi
	rootpart="$i"

	# DATA partition
	if [ -n "$rootsize" ]; then
		i=$((1 + $i))
		echo ","
		if [ -s "$backup/var.$ziptype" ]; then
			var_part="$i"
		else
			homepart="$i"
		fi
	fi
}

# Complex DOS/MBR layout
#
__complex_dos_layout()
{
	local i=1

	# IBM Power PReP partition
	if [ -n "$prepsize" ]; then
		echo ",$prepsize,7"
		preppart="$i"
		i=$((1 + $i))
	fi

	# EFI System partition
	if [ -n "$esp_size" ]; then
		echo ",$esp_size,U"
		esp_part="$i"
		i=$((1 + $i))
	fi

	# /boot partition
	if [ -n "$bootsize" ]; then
		echo ",$bootsize,L,*"
		bootpart="$i"
		i=$((1 + $i))
	fi

	# SWAP partition
	if [ -n "$swapsize" ]; then
		echo ",$swapsize,S"
		swappart="$i"
		i=$((1 + $i))
	fi

	# Extended partition
	if [ "$i" = 4 ]; then
		echo ",,E"
		i=5
	fi

	# ROOT partition
	if [ -z "$bootsize" ]; then
		echo ",$rootsize,L,*"
	else
		echo ",$rootsize"
	fi
	rootpart="$i"

	# DATA partition
	if [ -n "$rootsize" ]; then
		if [ "$i" -ge 5 ]; then
			i=$((1 + $i))
		else
			echo ",,E"
			i=5
		fi
		echo ","
		if [ -s "$backup/var.$ziptype" ]; then
			var_part="$i"
		else
			homepart="$i"
		fi
	fi
}

# DOS/MBR partitioning
#
__prepare_dos_layout()
{
	local i=1

	# Counting partitions
	[ -z "$prepsize" ] ||
		i=$((1 + $i))
	[ -z "$esp_size" ] ||
		i=$((1 + $i))
	[ -z "$bootsize" ] ||
		i=$((1 + $i))
	[ -z "$swapsize" ] ||
		i=$((1 + $i))
	[ -z "$rootsize" ] ||
		i=$((1 + $i))

	# Selecting MBR layout
	if [ "$i" -le 3 ]; then
		__simple_dos_layout
	else
		__complex_dos_layout
	fi
}

# Prepare target disk partitioning schema.
# Can be overrided in $backup/restore.sh
# or $backup/$profile/restore.sh.
#
make_pt_schema()
{
	disk_layout="$workdir/disk-layout.tmp"
	__prepare_${pt_schema}_layout >"$disk_layout"
}

