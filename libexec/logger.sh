###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

###################################################################
### Setup the logger and user interface for long-life processes ###
###################################################################

# Add record to the log file and/or send message to the system log
#
log()
{
	[ -n "$use_logger" ] || [ -n "$logfile" ] ||
		return 0

	local msg fmt="$1"; shift

	msg="$(printf "$fmt" "$@")"
	( [ -z "$use_logger" ] ||
		logger -t "$progname" -p "$logprio" -- "$msg" ||:
	  [ -z "$logfile" ] ||
		printf "[%s] %s\n" "$(LC_ALL=C date '+%F %T')" "$msg" >>"$logfile" ||:
	) 2>/dev/null
}

# Run the command with the optional debug logging
#
run()
{
	[ -z "$debugging" ] ||
		log "RUN: $*"
	"$@" || return $?
}

# Dump contents of the file "$1" to the log file in debug mode
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
	[ -n "$append_log" ] || [ -z "$logfile" ] ||
		:> "$logfile" 2>/dev/null ||:
	[ -z "$use_dialog" ] ||
		. "$supplimental"/dialogs.sh
	log "Started with arguments: $*"
}

