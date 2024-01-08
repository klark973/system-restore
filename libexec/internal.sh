###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2024, ALT Linux Team

##########################################################
### Internal variables.  Don't use them in restore.ini ###
### inside backup and/or profile directories. They are ###
### undocumented and can only be changed by the system ###
### administrator.                                     ###
###                                                    ###
### You can still set defaults for some internals only ###
### in the global /etc/system-backup/restore.conf.     ###
##########################################################

# Backup directory on local file system
# (the current working directory by default)
backup="${backup-$(realpath .)}"

# Account information of the remote backup storage
backup_proto="${backup_proto-file}"
remote_server="${remote_server-}"
remote_path="${remote_path-}"
remote_user="${remote_user-}"
remote_pass="${remote_pass-}"

# Empty (by default): do not show diagnostics before
# performing the primary action, 1: show diagnostics
# before performing the primary action
show_diag="${show_diag-}"

# 1 (by default): allow to use user-defined hooks
# and scripts supplied with the backup and/or profile
use_hooks="${use_hooks-1}"

# 1 (by default): show dialogs, empty: use stdout/stderr only
use_dialog="${use_dialog-1}"

# Empty (by default): do nothing, exit only;
# "reboot": reboot the computer after successful recovery;
# "poweroff": turn off the power after successful recovery.
finalact="${finalact-}"

# Empty (by default): overwrite the log file any time,
# 1: append to an existing log file at any time
append_log="${append_log-}"

# Empty (by default): do not use syslog, 1: use syslog
use_logger="${use_logger-}"

# Full path to the log file or empty to disable logging
logfile="${logfile-/var/log/$progname.log}"

# Syslog priority
readonly logprio="${logprio-user.info}"

# Initial mount points for auto-detecting write-protected devices
protected_mpoints="${protected_mpoints-/ /image /mnt/autorun /mnt/backup}"

# Specified action name (required)
action=

# Auto-detected or specified profile name (optional)
profile=

# Auto-detected target disk information
diskinfo=

# Auto-detected hardware platform name
platform=

# Devices list to installing the boot loader
boot_devices=

# Temporary working directory (created in run-time)
workdir=

# Auto-detected native language code, such as 'en_US'
lang=

# 1 (by default): check the backup and metadata
use_backup=1

# Empty (by default): target disk drive not used, 1: target
# disk drive must be found before start the primary action
# (this is set automaticaly in run-time)
use_target=

# Empty (by default): deployment or restore to a bare metal
# hypervisor name: we are working inside hypervisor (this is
# set automaticaly in run-time)
hypervisor=

# Creating disk label type (auto-detected in run-time)
# "dos": DOS/MBR partitioning scheme will be used
# "gpt": GUID/GPT partitioning scheme will be used
pt_scheme=

# 1: UEFI boot mode (auto-detected in run-time)
uefiboot=

# 1: Need to convert UEFI-boot in the source backup
# to BIOS/CSM-boot mode (auto-detected in run-time)
uefi2bios=

# 1: Need to convert BIOS/CSM-boot in the source backup
# to UEFI-boot mode (auto-detected in run-time)
bios2uefi=

# 1: NVRAM is supported on this platform (empty by default)
have_nvram=

# Auto-detected mke2fs features for ext4 partitions:
# empty: if e2fsprogs <= 1.42.x (64bit turned OFF, by default)
# 1: if e2fsprogs >= 1.43.x (64bit+metadata_csum can be used)
new_mkfs=

# Non-empty: TBH bootable device name or "1", if
# TBH exists (this is auto-detected in run-time)
have_tbh=

# Archive files type in the backup (auto-detected in run-time)
ziptype=

# Auto-detected names of the partition devices
# (only $rootpart is strictly required by default)
#
# $preppart is required for install grub-ieee1275 on IBM Power
# $bbp_part is required for install grub-pc to GUID/GPT disk label
# $esp_part is needed for /boot/efi (is required for UEFI-boot mode)
# $bootpart is needed for /boot (is required only on e2k* platforms)
# $swappart is needed for SWAP
# $rootpart is needed for / (system rootfs)
# $datapart is needed for /home, /var and so on
#
preppart=
esp_part=
bbp_part=
bootpart=
swappart=
rootpart=
datapart=

# File system UUIDs
esp_uuid=
bootuuid=
swapuuid=
rootuuid=
datauuid=

# Temporary file for sfdisk
disk_layout=

# 1: nothing to do, no destructive actions, check only
dryrun=

# 1: log debug messages, empty: disable debugging (by default)
debugging=

# Additional devices list for write protection while search
# the target disk drive, restore or deployment the system
protected_devices=

# Tools which must be installed inside rescue system before recovery
required_tools="blkid mkfs.ext4 mkfs.fat mkswap pv readlink sfdisk"
required_tools="$required_tools md5sum sha1sum sha256sum addpart"
required_tools="$required_tools tar dd touch uname unpigz wipefs"
required_tools="$required_tools mountpoint blockdev"

# Variables list which must be visible in the chroot
chroot_vars="unique_clone keep_uuids remove_kernel_pattern kernel_flavours"
chroot_vars="$chroot_vars biosboot_too efi_distributor grub_install_opts"
chroot_vars="$chroot_vars hypervisor platform pt_scheme uefiboot target"
chroot_vars="$chroot_vars debugging have_tbh have_nvram no_nvram have_rpmdb"

# Temporary mount point for restore rootfs and chroot
readonly destdir=/mnt/target

# IBM Power PReP partition GUID for grub-ieee1275 only
readonly prepguid="9E1A2D38-C612-4316-AA26-8B49521E5A8B"

# BIOS Boot partition GUID for grub-pc and grub-efi
readonly bbp_guid="21686148-6449-6E6F-744E-656564454649"

# Linux RAID member partition GUID
readonly raidguid="A19D880F-05FC-4D3B-A006-743F0F84911E"

# LVM2 Physical Volume partition GUID
readonly lvm2guid="E6D6D379-F507-44C2-A23C-238F2A3DF928"

# Microsoft Basic Data partition GUID
readonly msdataguid="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"

# Linux specific data partition GUID
readonly lnxdataguid="0FC63DAF-8483-4772-8E79-3D69D8477DE4"

# Exit codes
readonly EXIT_SUCCESS=0
readonly UNKNOWN_ERROR=1
readonly INVALID_USAGE=2
readonly METADATA_ERROR=3
readonly BAD_CHECKSUM=4
readonly ACCESS_ERROR=5
readonly DISK_IO_ERROR=6
readonly RESTORE_ERROR=7

