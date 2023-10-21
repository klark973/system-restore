###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

######################################
### Validator of the backup images ###
######################################

checksum()
{
	local chkfile="$1" utilname="$2"
	local validsum filename testsum

	while read -r validsum filename; do
		log "Validating '$PWD/$filename'..."
		[ -s "$filename" ] ||
			exit $METADATA_ERROR
		pv "$filename" | "$utilname" |
			awk '{print $1;}' >"$workdir/testsum.chk"
		read -r testsum <"$workdir/testsum.chk" ||:
		rm -f -- "$workdir/testsum.chk"
		echo -n "$filename=$testsum"
		if [ "$testsum" != "$validsum" ]; then
			echo " (FAIL)"
			exit $BAD_CHECKSUM
		fi
		echo " (OK)"
	done <"$chkfile"
}

validate_in_the_dir()
{
	local bkpdir="$1"
	local digests="${2:-.}"

	cd "$bkpdir"/
	[ ! -s "$digests"/checksum.MD5 ] ||
		checksum "$digests"/checksum.MD5 md5sum
	[ ! -s "$digests"/checksum.SHA ] ||
		checksum "$digests"/checksum.SHA sha1sum
	[ ! -s "$digests"/checksum.256 ] ||
		checksum "$digests"/checksum.256 sha256sum
	cd -
}

validate_backup_images()
{
	local msg="${L0000-Press Ctrl-Alt-Del to abort the computer restore.}"

	[ -n "$validate" ] ||
		return 0
	[ "$action" = validate ] ||
		echo "$msg"
	log "Validating backup images..."
	msg="${L0000-Please wait, validating backup images...}"
	echo "$msg"
	[ ! -s "$backup/update.$ziptype" ] ||
		validate_in_the_dir "$backup"
	[ -z "$profile" ] || [ ! -s "$backup/$profile/update.$ziptype" ] ||
		validate_in_the_dir "$backup/$profile"
	validate_in_the_dir "$backup" "$workdir"
	msg="Backup images validated successfully!"
	[ "$action" != validate ] ||
		fatal F000 "$msg"
	log "$msg"
	echo
}

validate_backup_images

