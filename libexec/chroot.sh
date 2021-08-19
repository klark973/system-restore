###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

# Add variable(s) to the list for transfer it to the chroot
#
add_chroot_var()
{
	chroot_vars="$chroot_vars $*"
}

# Add specified files and/or directories to the chroot
#
add_chroot_files()
{
	local fpath d="$destdir/run/$progname"

	[ -d "$d" ] ||
		fatal F000 "Call add_chroot_files() from here disallowed!"

	for fpath in "$@"; do
		if [ "${fpath:0:1}" = / ] && [ -e "$fpath" ]; then
			run cp -Lrf -- "$fpath" "$d"/
		elif [ -n "$profile" ] && [ -e "$backup/$profile/$fpath" ]; then
			run cp -Lrf -- "$backup/$profile/$fpath" "$d"/
		elif [ -e "$backup/$fpath" ]; then
			run cp -Lrf -- "$backup/$fpath" "$d"/
		else
			d="%s not found in the backup and/or profile!"
			fatal F000 "$d" "$fpath"
		fi
	done
}

# Chroot preparator
#
prepare_chroot()
{
	local v d="$destdir/run/$progname"
	local var f="$d/slave-launcher.sh"

	run mkdir -p -m0755 -- "$d"

	cat >"$f" <<-EOF
	#!/bin/sh -efu

	export PATH="$chroot_PATH"
	export LC_ALL="$chroot_LC_ALL"
	export TERM="$chroot_TERM"
	export USER=root
	EOF

	for var in $chroot_vars _; do
		[ "$var" != _ ] ||
			continue
		eval "v=\"\${$var-}\""
		[ -n "$v" ] ||
			continue
		cat >>"$f" <<-EOF
		export $var="$v"
		EOF
	done

	cat >>"$f" <<-EOF
	export chroot_vars="$chroot_vars"
	export rundir="/run/$progname"
	export lang=en_US

	cd "\$rundir/"
	exec "\$rundir/slave.sh"
	exit 1
	EOF

	fdump "$f"

	if [ -n "$use_hooks" ]; then
		[ ! -s "$backup"/chroot.sh ] ||
			run cp -Lf -- "$backup"/chroot.sh "$d"/
		[ -z "$profile" ] || [ ! -s "$backup/$profile"/chroot.sh ] ||
			run cp -Lf -- "$backup/$profile"/chroot.sh "$d"/profile.sh
	fi

	run cp -Lf -- "$supplimental/arch/$platform.sh" "$d"/platform.sh
	run cp -Lf -- "$supplimental"/version.sh "$d"/
	run cp -Lf -- "$supplimental"/logger.sh "$d"/
	run cp -Lf -- "$supplimental"/slave.sh "$d"/
	run chmod -- 0755 "$d"/slave.sh "$f"
	prepare_chroot_tbh
}

# This is a hook for user-defined function,
# can be overrided in $backup/restore.sh
# and/or in $backup/$profile/restore.sh
#
before_chroot()
{
	log "before_chroot() hook called"
}

# Chroot launcher
#
exec_chroot()
{
	local cmd f=

	if [ -n "$dryrun" ]; then
		log "Execution in the chroot will be skipped in dry-run mode"
		return 0
	fi

	if [ -n "$logfile" ]; then
		f="$destdir/run/$progname/log"
		:> "$f"
		run mount --bind -- "$logfile" "$f"
	fi
	if [ -f /etc/resolv.conf ] && [ -d "$destdir"/etc ]; then
		[ ! -f "$destdir"/etc/resolv.conf ] ||
			run mv -f -- "$destdir"/etc/resolv.conf "$workdir"/
		run cp -Lf -- /etc/resolv.conf "$destdir"/etc/
	fi
	run mount --bind -- /dev "$destdir"/dev
	cmd="$(command -v chroot)"
	log "Chroot prepared"

	run env -i "$cmd" "$destdir" "/run/$progname/slave-launcher.sh" ||
		fatal F000 "Execution in the chroot failed."
	[ ! -f "$workdir"/resolv.conf ] ||
		run mv -f -- "$workdir"/resolv.conf "$destdir"/etc/
	[ -z "$f" ] || run umount -- "$f" 2>/dev/null ||
		run umount -fl -- "$f"
	run umount -- "$destdir"/dev 2>/dev/null ||
		run umount -fl -- "$destdir"/dev
	log "Chroot finished"
}

# This is a hook for user-defined function,
# can be overrided in $backup/restore.sh
# and/or in $backup/$profile/restore.sh
#
after_chroot()
{
	log "after_chroot() hook called"
}

# Chroot cleaner
#
cleanup_chroot()
{
	run rm -rf --one-file-system -- "$destdir/run/$progname"
}

