###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#######################################################
### Optional cleanup rootfs after deploy or restore ###
#######################################################

# /home
#
__cleanup_home()
{
	local entry item
	local f="$workdir/CLEANUP.HOME"

	log "Cleanup /home..."
	[ -z "$dryrun" ] ||
		return 0
	find . -maxdepth 1 -type d -and ! -name '.' |
		cut -c3- >"$f"
	fdump "$f"

	while read -r entry; do
		[ "$entry" != 'lost+found'  ] ||
			continue
		[ -d "$entry" ] ||
			continue
		[ -f "$entry/.bash_profile" ] ||
		[ -f "$entry/.bash_logout"  ] ||
		[ -f "$entry/.bashrc"       ] ||
			continue
		log "  - User found: '$entry'"
		( set +e
		  cd "$entry/"
		  entry="$(glob '.xsession-errors*')"
		  [ -z "$entry" ] || run rm -f -- $entry
		  for item in cache dbus local linuxmint config/caja	 \
				config/gconf config/goa-1.0 config/menus \
				config/mintmenu config/parcellite	 \
				config/pulse xsession.d apt
		  do
			[ ! -d ".$item" ] ||
				run rm -rf -- ".$item"
		  done
		  for item in config/Trolltech.conf config/monitors.xml  \
				ICEauthority bash_history ssh/agent
		  do
			[ ! -e ".$item" ] ||
				run rm -f -- ".$item"
		  done
		) 2>/dev/null
	done <"$f"

	run rm -f -- "$f"
}

# /var/log
#
__cleanup_logs()
{
	local entry

	log "Cleanup /var/log..."
	[ -z "$dryrun" ] ||
		return 0
	( set +e
	  entry="$(glob 'journal/???*')"
	  [ -z "$entry" ] ||
		run rm -rf -- $entry
	  run find . -type f -name '*.old' -delete
	  run rm -f -- Xorg.0.log alterator-net-iptables rpmpkgs
	  find . -type f -and ! -empty |
		cut -c3- |
		grep -vE '^README$' |
	  while read -r entry; do
		log "Wiping '$entry'..."
		:> "$entry"
	  done
	) 2>/dev/null
}

# /var
#
__cleanup_var()
{
	local entry

	log "Cleanup /var..."
	[ -z "$dryrun" ] ||
		return 0
	( set +e
	  [ ! -f lib/openvpn/etc/resolv.conf ] ||
		run sed -i '/^(nameserver|search) /d' lib/openvpn/etc/resolv.conf
	  [ ! -f resolv/etc/resolv.conf ] ||
		run sed -i '/^(nameserver|search) /d' resolv/etc/resolv.conf
	  [ ! -d lib/ldm/.dbus/session-bus ] ||
		run rm -rf -- lib/ldm/.dbus/session-bus
	  entry="$(glob 'cache/fontconfig/*.cache-?*')"
	  [ -z "$entry" ] || run rm -f -- $entry
	  entry="$(glob 'lib/NetworkManager/dhclient-*.lease')"
	  [ -z "$entry" ] || run rm -f -- $entry
	  entry="$(glob 'lib/NetworkManager/dhclient-*.conf')"
	  [ -z "$entry" ] || run rm -f -- $entry
	  entry="$(glob 'lib/dhcpcd/*.lease')"
	  [ -z "$entry" ] || run rm -f -- $entry
	  for entry in lib/NetworkManager/timestamps lib/dbus/machine-id   \
			run/alteratord/alteratord.log run/avahi-daemon/pid \
			run/alteratord.pid run/cupsd.pid lib/random-seed   \
			lib/systemd/random-seed
	  do
		[ ! -f "$entry" ] || run rm -f -- "$entry"
	  done
	) 2>/dev/null
}

# /boot
#
__cleanup_boot()
{
	local entry

	log "Cleanup /boot..."
	[ -z "$dryrun" ] ||
		return 0
	( set +e
	  entry="$(glob 'initrd-[2-5]*.img')"
	  [ -z "$entry" ] || run rm -f -- $entry
	  run rm -f -- grub/grub.cfg grub/grubenv
	) 2>/dev/null
}

# / (root)
#
__cleanup_root()
{
	local m kernel

	log "Cleanup / (root)..."
	[ -z "$dryrun" ] ||
		return 0
	( set +e
	  [ ! -f etc/resolv.conf ] ||
		run sed -i '/^(nameserver|search) /d' etc/resolv.conf
	  m="$(glob 'etc/openssh/ssh_host_*key*')"
	  [ -z "$m" ] || run rm -f -- $m
	  m="$(glob 'etc/udev/rules.d/*persistent*.rules')"
	  [ -z "$m" ] || run rm -f -- $m
	  m="$(glob 'run/blkid/blkid*')"
	  [ -z "$m" ] || run rm -f -- $m
	  m="$(glob 'tmp/.private/*')"
	  [ -z "$m" ] || run rm -f -- $m
	  m="$(glob 'etc/*.bak')"
	  [ -z "$m" ] || run rm -f -- $m
	  m="$(glob 'etc/*.old')"
	  [ -z "$m" ] || run rm -f -- $m
	  [ ! -d root/.cache ] ||
		run rm -rf root/.cache
	  [ ! -d root/.loacl ] ||
		run rm -rf root/.local
	  [ ! -d tmp/alterator ] ||
		run rm -rf tmp/alterator
	  [ ! -d tmp/hsperfdata_root ] ||
		run rm -rf tmp/hsperfdata_root
	  run rm -f etc/resolv.conf.dnsmasq
	  run rm -f etc/firsttime.flag
	  run rm -f etc/machine-id
	  run rm -f root/.bash_history
	  run rm -f run/messagebus.pid
	  for kernel in $(glob 'lib/modules/*') _
	  do
		[ "$kernel" != _ ] ||
			continue
		m="$kernel/kernel/drivers/block"
		[ ! -d "$m/drbd" ] && [ ! -d "$m/zram" ] ||
			continue
		run rm -rf -- "$kernel"
	  done
	) 2>/dev/null
}

# Default implementation of the common cleanup logic
#
__cleanup_parts()
{
	if [ -d "$destdir"/boot ]; then
		cd "$destdir"/boot/
		cleanup_boot
		cd -
	fi

	if [ "$action" != sysrest ] || [ ! -s "$backup/var.$ziptype" ]; then
		if [ -d "$destdir"/var/log ]; then
			cd "$destdir"/var/log/
			cleanup_logs
			cd -
		fi
		if [ -d "$destdir"/var ]; then
			cd "$destdir"/var/
			cleanup_var
			cd -
		fi
	fi

	if [ -d "$destdir"/home ] && [ "$action" != sysrest ]; then
		cd "$destdir"/home/
		cleanup_home
		cd -
	fi

	cd "$destdir"/
	cleanup_root
	cd -
}

# It can be overridden in $backup/cleanup.sh
# or $backup/$profile/cleanup.sh
#
cleanup_home()
{
	__cleanup_home
}

# It can be overridden in $backup/cleanup.sh
# or $backup/$profile/cleanup.sh
#
cleanup_logs()
{
	__cleanup_logs
}

# It can be overridden in $backup/cleanup.sh
# or $backup/$profile/cleanup.sh
#
cleanup_var()
{
	__cleanup_var
}

# It can be overridden in $backup/cleanup.sh
# or $backup/$profile/cleanup.sh
#
cleanup_boot()
{
	__cleanup_boot
}

# It can be overridden in $backup/cleanup.sh
# or $backup/$profile/cleanup.sh
#
cleanup_root()
{
	__cleanup_root
}

# It can be overridden in $backup/cleanup.sh
# or $backup/$profile/cleanup.sh
#
cleanup_parts()
{
	__cleanup_parts
}

# Including user-defined hooks
if [ -n "$use_hooks" ] && [ -n "$unique_clone" ]; then
	[ ! -s "$backup"/cleanup.sh ] ||
		. "$backup"/cleanup.sh
	[ -z "$profile" ] || [ ! -s "$backup/$profile"/cleanup.sh ] ||
		. "$backup/$profile"/cleanup.sh
fi

