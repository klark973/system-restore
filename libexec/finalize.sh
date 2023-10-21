###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

# Unmounting BACKUP as needed
cd / && mountpoint -q -- "$backup" &&
	umount -- "$backup" 2>/dev/null ||:
mount -o remount,exec /tmp  2>/dev/null ||:

# Creating last stage script
cat >/tmp/finish.sh <<EOF
#!/bin/sh

if mountpoint -q -- "\$1"; then
   umount -- "\$1" 2>/dev/null ||
      umount -fl -- "\$1" ||:
fi

exec $finalact
exit $UNKNOWN_ERROR
EOF
fdump /tmp/finish.sh
chmod 0755 /tmp/finish.sh

# Ignoring status
exit_handler ||:

# Footer text
case "$action" in
deploy|fullrest|sysrest)
	msg ""
	msg "%s '%s' successfully restored!" "$(get_chassis_type)" "$computer"
	msg "Enjoy! ;-)"
	msg ""
esac

# Finishing
exec /tmp/finish.sh "${scriptname%/*}"
#
exec $finalact
exit $UNKNOWN_ERROR

