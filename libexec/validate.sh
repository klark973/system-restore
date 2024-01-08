###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

###################################
### The backup images validator ###
###################################

checksum()
{
	local i subdir="$1" chkfile="$2" utilname="$3"
	local n validsum filename testsum msg1 msg2 pid

	n="$(wc -l -- "$chkfile" |sed 's/ .*//g')"

	for i in $(seq 1 $n); do
		validsum="$(sed -n "${i}p" "$chkfile" |sed -E 's/\s+.+$//g')"
		filename="$(sed -n "${i}p" "$chkfile" |sed -E 's/^\w+\s+//g')"
		is_file_exists "${subdir}$filename" ||
			fatal F000 "The backup image not found: %s" "${subdir}$filename"
		log "Validating '%s'..." "${subdir}$filename"
		testsum="$(get_file_size "${subdir}$filename")"

		if [ -z "$use_dialog" ]; then
			read_file "${subdir}$filename" |pv -s "$testsum" |"$utilname" |
				sed -E 's/\s+.+$//g' >"$workdir/testsum.chk"
		elif [ "$testsum" -le 10485760 ]; then
			read_file "${subdir}$filename" |"$utilname" |
				sed -E 's/\s+.+$//g' >"$workdir/testsum.chk"
		else
			checksum_dlg "$utilname" "${subdir}$filename" "$testsum"
		fi

		read -r testsum <"$workdir/testsum.chk" 2>/dev/null ||
			testsum=
		rm -f -- "$workdir/testsum.chk"
		printf "%s" "${subdir}$filename=${testsum:-ERROR}"
		if [ "$testsum" = "$validsum" ]; then
			printf " (%s)\n" "${L0000-OK}"
		else
			printf " (%s)\n" "${L0000-FAIL}"
			fatal F000 "The backup image checksum mismatch."
		fi
	done
}

validate_in_subdir()
{
	local subdir="$1"
	local digests="${2-}"

	if [ -z "$digests" ]; then
		digests="$workdir"

		if is_file_exists "${subdir}update.MD5"; then
			read_file "${subdir}update.MD5" >"$digests"/update.MD5
			checksum "$subdir" "$digests"/update.MD5 md5sum
			run rm -f -- "$digests"/update.MD5
		fi

		if is_file_exists "${subdir}update.SHA"; then
			read_file "${subdir}update.SHA" >"$digests"/update.SHA
			checksum "$subdir" "$digests"/update.SHA sha1sum
			run rm -f -- "$digests"/update.SHA
		fi

		if is_file_exists "${subdir}update.256"; then
			read_file "${subdir}update.256" >"$digests"/update.256
			checksum "$subdir" "$digests"/update.256 sha256sum
			run rm -f -- "$digests"/update.256
		fi
	fi

	[ ! -s "$digests"/checksum.MD5 ] ||
		checksum "" "$digests"/checksum.MD5 md5sum
	[ ! -s "$digests"/checksum.SHA ] ||
		checksum "" "$digests"/checksum.SHA sha1sum
	[ ! -s "$digests"/checksum.256 ] ||
		checksum "" "$digests"/checksum.256 sha256sum
	return 0
}

validate_backup_images()
{
	local msg

	[ -n "$validate" ] ||
		return 0
	echo "${L0000-Please wait, validating backup images...}"
	msg="${L0000-Press Ctrl-Alt-Del to abort the system restore.}"
	[ "$action" = validate ] ||
		echo "$msg"
	log "Validating backup images..."

	if [ -n "$profile" ] && is_file_exists "$profile/update.$ziptype"; then
		validate_in_subdir "$profile/"
	elif is_file_exists "update.$ziptype"; then
		validate_in_subdir ""
	else
		validate_in_subdir "" "$workdir"
	fi

	msg="Backup images validated successfully!"
	[ "$action" != validate ] ||
		fatal F000 "$msg"
	log "$msg"
	echo
}

validate_backup_images

