###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#########################################
### The command-line arguments parser ###
#########################################

show_usage()
{
	local msg="Invalid command-line usage."
	msg="$msg\nTry '%s -h' for more details."

	if [ "$#" != 0 ]; then
		local fmt="$1"; shift
		printf "$fmt\n" "$@" >&2
	fi

	fatal F000 "$msg" "$progname"
}

set_action()
{
	local msg="${L0000:-The action already specified: '%s'.}"

	[ -z "$action" ] ||
		show_usage "$msg" "$action"
	action="$1"
}

check_arg()
{
	local msg="${L0000:-After option '%s' must specify %s!.}"

	[ -n "$2" ] && [ "x$2" != "x--" ] ||
		show_usage "$msg" "$1" "$3"
	return 0
}

show_version()
{
	local SYSREST_VERSION=
	local SYSREST_BUILD_DATE=

	. "$supplimental"/version.sh

	printf "%s %s %s\n" "$progname" "$SYSREST_VERSION" "$SYSREST_BUILD_DATE"
	exit 0
}

show_help()
{
	local help="$supplimental/l10n/$lang/help.msg"

	[ -s "$help" ] ||
		help="$supplimental/l10n/en_US/help.msg"
	sed "s/@PROG@/$progname/g" "$help"
	exit 0
}

parse_cmdline()
{
	local msg=
	local l_opts="check-only,scan-only,validate,deploy,full,system"
	      l_opts="$l_opts,check-config,check-conf,check-meta,make-id"
	      l_opts="$l_opts,check-target,reboot,poweroff,backup:,profile:"
	      l_opts="$l_opts,exclude:,logfile:,show-diag,no-dialog,dry-run"
	      l_opts="$l_opts,no-hooks,no-log,show-diags,no-dialogs,dryrun"
	      l_opts="$l_opts,append,syslog,debug,version,help"
	local s_opts="+cCtvdfsmb:p:x:l:PRnauDVh"

	l_opts=$(getopt -n "$progname" -o "$s_opts" -l "$l_opts" -- "$@") ||
		show_usage
	eval set -- "$l_opts"
	while [ "$#" != 0 ]; do
		case "$1" in
		-c|--check-only|--check-meta)
			set_action chkmeta
			;;
		-C|--check-conf|--check-config)
			set_action chkconf
			;;
		-t|--scan-only|--check-target)
			set_action chkdisk
			use_target=1
			use_backup=
			;;
		-v|--validate)
			set_action validate
			;;
		-d|--deploy)
			set_action deploy
			use_target=1
			unique_clone=1
			hostnaming=hw6
			;;
		-f|--full)
			set_action fullrest
			partitioner=fullrest
			use_target=1
			keep_uuids=1
			;;
		-s|--system)
			set_action sysrest
			use_target=1
			keep_uuids=1
			;;
		-m|--make-id)
			set_action make-id
			use_backup=
			;;

		-b|--backup)
			check_arg --backup "${2-}" "${L0000:-backup directory or storage}"
			case "${2-}" in
			ftp://*)
				backup=
				backup_proto=ftp
				remote_server="${2:6}"
				;;
			http://*)
				backup=
				backup_proto=http
				remote_server="${2:7}"
				;;
			rsync://*)
				backup=
				backup_proto=rsync
				remote_server="${2:8}"
				;;
			ssh://*)
				backup=
				backup_proto=ssh
				remote_server="${2:6}"
				;;
			file://*)
				msg="${L0000:-Directory not found: '%s'.}"
				[ -d "${2:7}" ] ||
					show_usage "$msg" "${2:7}"
				backup="$(realpath -- "${2:7}")"
				backup_proto=file
				;;
			*) # local filesystem too
				msg="${L0000:-Directory not found: '%s'.}"
				[ -d "$2" ] ||
					show_usage "$msg" "$2"
				backup="$(realpath -- "$2")"
				backup_proto=file
				;;
			esac
			shift
			;;

		-p|--profile)
			check_arg --profile "${2-}" "${L0000:-profile name}"
			msg="${L0000:-Invalid profile name: '%s'.}"
			[ "$2" != virtual ] ||
				show_usage "$msg" "$2"
			profile="$2"
			shift
			;;

		-x|--exclude)
			check_arg --exclude "${2-}" "${L0000:-device or mount point}"
			msg="${L0000:-Value of '%s' must be device or mount point.}"
			[ -b "$2" ] || mountpoint -q -- "$2" ||
				show_usage "$msg" "--exclude"
			protected_mpoints="$protected_mpoints $2"
			shift
			;;

		-l|--logfile)
			check_arg --logfile "${2-}" "${L0000:-log file path}"
			if [ "x$2" = "x-" ]; then
				logfile=
			else
				msg="${L0000:-Invalid path to the log file: '%s'.}"
				[ -d "${2%/*}" ] ||
					show_usage "$msg" "$2"
				[ -n "${2##*/*}" ] && logfile="$(realpath .)/$2" ||
					logfile="$(realpath -- "${2%/*}")/${2##*/}"
			fi
			shift
			;;

		-P|--poweroff)
			finalact=poweroff
			;;
		-R|--reboot)
			finalact=reboot
			;;
		--no-log)
			logfile=
			;;
		--no-hooks)
			use_hooks=
			;;
		--no-dialogs|--no-dialog)
			use_dialog=
			;;
		--show-diag|--show-diags)
			show_diag=1
			;;
		-n|--dry-run|--dryrun)
			dryrun=1
			;;
		-a|--append)
			append_log=1
			;;
		-u|--syslog)
			use_logger=1
			;;
		-D|--debug)
			debugging=1
			;;
		-V|--version)
			show_version
			;;
		-h|--help)
			show_help
			;;

		--)	shift
			break
			;;
		-*)	msg="${L0000:-Unsupported option: '%s'.}"
			show_usage "$msg" "$1"
			;;
		*)	break
			;;
		esac
		shift
	done

	# Action required
	[ -n "$action" ] ||
		show_usage "${L0000:-Action must be specified!}"
	msg="${L000:-%s: the target must be an existing block special device!}"

	# Optional target(s)
	if [ "$#" = 1 ]; then
		[ -b "$1" ] ||
			show_usage "$msg" "$1"
		target="$1"
	elif [ "$#" -gt 1 ]; then
		multi_targets="$*"
		n_targets=0

		for target in $multi_targets; do
			[ -b "$target" ] ||
				show_usage "$msg" "$target"
			n_targets=$((1 + $n_targets))
		done

		target=
	fi

	# Creating 'id' sub-directory if it was requested
	[ "$action" != make-id ] || . "$supplimental"/make-id.sh

	# Require support for the protocol with remote server
	. "$supplimental"/proto/"$backup_proto".sh
}

