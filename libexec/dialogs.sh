###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

#####################################
### Dialog forms and sub-routines ###
#####################################

# Outputs a fatal error message
#
show_error()
{
	local fcode="${1:1}" fmt="$2"
	local msg="${F000-%s fatal[%s]}"
	local title="${F000-Fatal error}"
	local i norm='\033[00m'
	local d err='\033[01;31m'
	local text width height=2

	shift 2
	i="$workdir"/imgscript.sh
	d="$workdir"/dialogrc.error
	text="$(printf "$fmt" "$@")"
	width=$((4 + ${#text}))

	if [ "$width" -lt 40 ]; then
		width=40
	elif [ "$width" -gt 76 ]; then
		height=$(( $width / 76 + 2 ))
		width=76
	fi

	cat >"$i" <<-EOF
	#!/bin/sh -efu

	export DIALOGRC="$d"

	dialog \\
	  --backtitle "ALT System Restore"	\\
	  --title "[ $title ]"			\\
	  --msgbox "\n$text"			\\
	  $((5 + $height)) $width ||:
	EOF

	chmod -- 0755 "$i"
	dialog --create-rc -- "$d"
	sed -i -E 's/^(use_shadow).*$/\1 = ON/' "$d"
	sed -i -E 's/^(use_colors).*$/\1 = ON/' "$d"
	sed -i -E 's/^(screen_color).*$/\1 = (WHITE,RED,ON)/' "$d"
	tmux new-session "$i" >/dev/null
	rm -f -- "$i" "$d"

	msg "${err}$msg: $fmt${norm}" "$progname" "$fcode" "$@" >&2
}

# Outputs a progress bar while the image checksum is being calculated
#
checksum_dlg()
{
	local utilname="$1" filename="$2" testsum="$3"
	local i="$workdir"/imgscript.sh
	local p="$workdir"/image.pipe
	local d="$workdir"/DIAG.txt
	local msg="${L0000-checksum}"
	local m pid msg1 msg2=""

	case "$utilname" in
	"md5sum")	msg="MD5";;
	"sha1sum")	msg="SHA-1";;
	"sha256sum")	msg="SHA-256";;
	esac

	[ "$action" = validate ] ||
		msg2="${L0000-Press Ctrl-Alt-Del to abort the system restore.}"
	msg1="${L0000-Please wait, calculating %s for %s...}"
	msg="$(printf "$msg1" "$msg" "$filename")"

	cat >"$i" <<-EOF
	#!/bin/sh -efu

	( pv -n -s "$testsum" -- "$p" |"$utilname" |
	  sed -E 's/\\s+.+\$//g' >"$workdir"/testsum.chk
	) 2>&1 |dialog \
	  --backtitle "ALT System Restore"	\\
	EOF

	if [ -s "$d" ]; then
		m="$(wc -l -- "$d" |sed 's/ .*//g')"
		m="$((4 + $m))"
		cat >>"$i" <<-EOF
		  --keep-window --no-kill --begin 2 2	\\
		  --title "[ Diagnostics ]"		\\
		  --tailboxbg "$d" $m 60		\\
		  --and-widget --begin $(( $m - 1 )) 3	\\
		EOF
	fi

	if [ -n "$msg2" ]; then
		cat >>"$i" <<-EOF
		  --title "[ Validating checksums ]"	\\
		  --gauge "\\n$msg\\n$msg2" 9 70
		exit 0
		EOF
	else
		cat >>"$i" <<-EOF
		  --title "[ Validating checksums ]"	\\
		  --gauge "\\n$msg" 8 70
		exit 0
		EOF
	fi

	rm -f -- "$p"
	chmod -- 0755 "$i"
	mkfifo -m 0660 -- "$p"
	read_file "$filename" >"$p" & pid=$!
	tmux new-session "$i" >/dev/null
	wait $pid
	rm -f -- "$p" "$i"
}

