###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2022-2023, ALT Linux Team

# Output the list of additional required tools
#
get_proto_requires()
{
	echo "stat"
}

# Return 0 if write operations at remote side is allowed
#
has_write_access()
{
	return 0
}

# Return 0 if specified directory exists at remote side
#
is_dir_exists()
{
	[ -d "$backup/$1" ] ||
		return $DISK_IO_ERROR
}

# Return 0 if specified file at remote side is non-empty
#
is_file_exists()
{
	[ -s "$backup/$1" ] ||
		return $DISK_IO_ERROR
}

# Display specified file size (in bytes), if it exists at remote side
#
get_file_size()
{
	[ -r "$backup/$1" ] &&
	run stat -L --printf="%s" -- "$backup/$1" ||
		return $DISK_IO_ERROR
}

# Create specified directory at remote side
#
create_directory()
{
	run mkdir -m700 -- "$backup/$1" ||
		return $DISK_IO_ERROR
}

# Read specified file at remote side and write it to stdout
#
read_file()
{
	run cat -- "$backup/$1" ||
		return $DISK_IO_ERROR
}

# Write to specified file at remote side, read it from stdin
#
write_file()
{
	cat >"$backup/$1" ||
		return $DISK_IO_ERROR
}

