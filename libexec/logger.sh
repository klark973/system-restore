###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

###################################################################
### Setup the logger and user interface for long-life processes ###
###################################################################

# Adds a record to the log file and/or sends a message to the system log
#
log()
{
	local msg fmt="$1"; shift

	[ -n "$use_logger" ] || [ -n "$logfile" ] ||
		return 0
	msg="$(msg "$fmt" "$@")"
	( [ -z "$use_logger" ] ||
		logger -t "$progname" -p "$logprio" -- "$msg" ||:
	  [ -z "$logfile" ] ||
		printf "[%s] %s\n" "$(LC_ALL=C date '+%F %T')" "$msg" >>"$logfile" ||:
	) 2>/dev/null
}

# Runs a command with an optional debug logging
#
run()
{
	[ -z "$debugging" ] ||
		log "RUN: %s" "$*"
	"$@" || return $?
}

# Dumps contents of the file "$1" to the log file in debug mode
#
fdump()
{
	[ -n "$debugging" ] && [ -n "$logfile" ] ||
		return 0
	log "%s contents:" "$1"
	( echo "########################################"
	  cat -- "$1"
	  echo "########################################"
	) >>"$logfile" 2>/dev/null ||:
}

# Setup the logger
#
setup_logger()
{
	[ -z "$logfile" ] ||
		mkdir -p -m0755 -- "${logfile%/*}"
	[ -n "$append_log" ] || [ -z "$logfile" ] ||
		:> "$logfile"
	[ -z "$use_dialog" ] ||
		. "$utility"/dialogs.sh
	log "Started with arguments: %s" "$*"
}

setup_logger "$@"

