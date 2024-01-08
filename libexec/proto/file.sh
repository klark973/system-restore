###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2022-2024, ALT Linux Team

# Outputs the list of additional required tools
#
get_proto_requires()
{
	echo "stat"
}

# Returns 0 if write operations at remote side is allowed
#
has_write_access()
{
	return 0
}

# Returns 0 if specified directory exists at remote side
#
is_dir_exists()
{
	[ -d "$backup/$1" ] ||
		return $DISK_IO_ERROR
}

# Returns 0 if specified file at remote side is non-empty
#
is_file_exists()
{
	[ -s "$backup/$1" ] ||
		return $DISK_IO_ERROR
}

# Displays specified file size (in bytes), if it exists at remote side
#
get_file_size()
{
	[ -r "$backup/$1" ] &&
	run stat -L --printf="%s" -- "$backup/$1" ||
		return $DISK_IO_ERROR
}

# Creates specified directory at remote side
#
create_directory()
{
	run mkdir -m700 -- "$backup/$1" ||
		return $DISK_IO_ERROR
}

# Reads specified file at remote side and writes it to stdout
#
read_file()
{
	run cat -- "$backup/$1" ||
		return $DISK_IO_ERROR
}

# Writes to specified file at remote side, reads it from stdin
#
write_file()
{
	cat >"$backup/$1" ||
		return $DISK_IO_ERROR
}

