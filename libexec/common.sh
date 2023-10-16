###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

##########################################################
### Common functions which can used also in the chroot ###
##########################################################

# Try to include NLS configuration
#
nls_config()
{
	[ ! -s "$supplimental/l10n/$lang/$1.sh" ] ||
		. "$supplimental/l10n/$lang/$1.sh"
}

# Enable native language support
#
nls_locale_setup()
{
	lang="${LANG:-en_US.utf8}"
	lang="${LC_ALL:-$lang}"
	lang="${LC_MESSAGES:-$lang}"
	lang="${lang%.*}"
	[ -n "$lang" ] && [ -s "$supplimental/l10n/$lang"/help.msg ] ||
		lang="en_US"
	nls_config common
}

# Return 0 if argument is an integer number
#
is_number()
{
	[ -n "${1##*[!0-9]*}" ] && [ "$1" -ge 0 ] 2>/dev/null
}

# Serach element "$1" in the array "$@" and return 0 if it found
#
in_array()
{
	local needle="$1"; shift

	while [ "$#" -gt 0 ]; do
		[ "$needle" != "$1" ] ||
			return 0
		shift
	done

	return 1
}

# Base implementation, it will be overrided in logger.sh
#
log()
{
	: # Nothing by default
}

# Base implementation, it will be overrided in logger.sh
#
run()
{
	"$@" || return $?
}

# Base implementation, it will be overrided in dialogs.sh
#
show_error()
{
	local fcode="$1" fmt="$2"; shift 2
	local msg="${F000:-%s fatal[%s]}"

	printf "$msg: $fmt\n" "$progname" "$fcode" "$@" >&2
}

# Default implementation of the exit handler
#
__exit_handler()
{
	local rv=$?

	trap - EXIT; cd /
	[ -z "$workdir" ] || [ ! -d "$workdir" ] ||
		run rm -rf --one-file-system -- "$workdir"
	log "${L0000:-Terminated with exit code %s.}" "$rv"
	return $rv
}

# Can be overrided in $backup/config.sh, $backup/restore.sh,
# $backup/$profile/config.sh or $backup/$profile/restore.sh
#
exit_handler()
{
	__exit_handler || return $?
}

# Fatal situation handler
#
fatal()
{
	local fcode="$1" fmt="$2"
	local msg rv="${fcode:1:1}"

	shift 2
	nls_config fatal
	is_number "$rv" ||
		rv="$UNKNOWN_ERROR"
	eval "msg=\"\${$fcode-}\""
	msg="${msg:-$fmt}"

	if [ "$rv" = "$EXIT_SUCCESS" ]; then
		log "SUCCESS[%s]: $fmt" "$fcode" "$@"
		printf "$msg\n" "$@"
		exit $EXIT_SUCCESS
	fi

	log "FATAL[%s]: $fmt" "$fcode" "$@"
	show_error "$fcode" "$msg" "$@"
	trap - ERR
	exit $rv
}

# Unexpected error handler
#
unexpected_error()
{
	local rv="$?"

	trap - ERR
	fatal F000 "Unexpected error #%s catched in %s[#%s]!" "$rv" "$2" "$1"
}

# Output files list sorted by specified pattern(s)
#
glob()
{
	(set +f; eval ls -X1 -- "$@" ||:) 2>/dev/null
}

# Convert human-readable size's to the long integer bytes
#
human2size()
{
	local input="$1" rv=
	local slen="${#input}"
	slen="$(($slen - 1))"
	local data="${input:0:$slen}"
	local lchar="${input:$slen:1}"

	case "$lchar" in
	[0-9])	rv="$input";;

	K)	rv="$(( $data * 1024 ))";;
	M)	rv="$(( $data * 1024 * 1024 ))";;
	G)	rv="$(( $data * 1024 * 1024 * 1024 ))";;
	T)	rv="$(( $data * 1024 * 1024 * 1024 * 1024 ))";;

	b)	slen="$(($slen - 1))"
		data="${input:0:$slen}"
		lchar="${input:$slen:2}"

		case "$lchar" in
		Kb) rv="$(( $data * 1024 ))";;
		Mb) rv="$(( $data * 1024 * 1024 ))";;
		Gb) rv="$(( $data * 1024 * 1024 * 1024 ))";;
		Tb) rv="$(( $data * 1024 * 1024 * 1024 * 1024 ))";;
		esac
		;;

	B)	slen="$(($slen - 1))"
		data="${input:0:$slen}"
		lchar="${input:$slen:2}"

		case "$lchar" in
		KB) rv="$(( $data * 1000 ))";;
		MB) rv="$(( $data * 1000 * 1000 ))";;
		GB) rv="$(( $data * 1000 * 1000 * 1000 ))";;
		TB) rv="$(( $data * 1000 * 1000 * 1000 * 1000 ))";;
		esac
		;;
	esac

	is_number "$rv" ||
		fatal F000 "Can't convert to the number!"
	echo -n "$rv"
}

