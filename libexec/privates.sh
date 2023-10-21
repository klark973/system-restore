###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

########################################################
### Internal variables, don't use it in restore.ini! ###
########################################################

# Specified action name (required)
action=

# Auto-detected or specified sub-profile name (optional)
profile=

# Auto-detected target disk information
diskinfo=

# Auto-detected hardware platform name
platform=

# Temporary working directory (created in run-time)
workdir=

# Auto-detected native language code, such as 'en_US'
lang=

# Backup directory on the local filesystem
# (current working directory by default)
backup="$(realpath .)"

# Account information for remote backup storage
backup_proto=file
remote_server=
remote_path=
remote_user=
remote_pass=

# Empty: don't show diagnostics before primary action
# (by default), 1: show diagnostics before primary action
show_diag=

# 1 (by default): check the backup and metadata
use_backup=1

# 1 (by default): enable to use user-defined hooks and
# scripts supplied with the backup and/or sub-profile
use_hooks=1

# 1 (by default): show dialogs, empty: use stdout/stderr only
use_dialog=1

# Empty (by default): target disk drive not used, 1: target
# disk drive must be found before start the primary action
# (this is set automaticaly in run-time)
use_target=

# Empty (by default): deploy or restore to the bare metal
# hypervisor name: if working inside hypervisor (this is
# set automaticaly in run-time)
hypervisor=

# Creating disk label type (auto-detected in run-time)
# "dos": DOS/MBR partitioning schema will be used
# "gpt": GUID/GPT partitioning schema will be used
pt_schema=

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
# $preppart required for install grub-ieee1275 on IBM Power
# $bbp_part required for install grub-pc to GUID/GPT disk label
# $esp_part need for /boot/efi (required for UEFI-boot mode)
# $bootpart need for /boot (required only on e2k* platforms)
# $swappart need for SWAP
# $rootpart need for /
# $var_part need for /var
# $homepart need for /home
#
preppart=
esp_part=
bbp_part=
bootpart=
swappart=
rootpart=
var_part=
homepart=

# Partitions UUID's
esp_uuid=
bootuuid=
swapuuid=
rootuuid=
var_uuid=
homeuuid=

# Empty (by default): nothing to do, exit only;
# "reboot": reboot machine after success restore;
# "poweroff": turn power OFF after success restore
finalact=

# 1: nothing to do, no destructive actions, check only
dryrun=

# 1: log debug messages, empty: disable debugging (by default)
debugging=

# Empty: rewrite log file any time, 1: append to existing log file
append_log=

# Empty: disable system logger (by default), 1: use system logger
use_logger=

# Full path to the log file or empty for logging turn OFF
logfile="/var/log/$progname.log"

# System logger priority
logprio="${SYSREST_LOGPRIO:-user.info}"

# Temporary mount point for restore rootfs and chroot
destdir=/mnt/target

# Initial mount points for auto-detecting write-protected devices
protected_mpoints="/ /image /mnt/autorun /mnt/backup"

# Additional devices list for write protection while search
# the target disk drive, restore or deploy the system
protected_devices=

# Tools which must be installed inside rescue system before recovery
required_tools="blkid lsblk mkfs.ext4 mkfs.fat mkswap pv readlink sfdisk"
required_tools="$required_tools md5sum sha1sum sha256sum addpart delpart"
required_tools="$required_tools tar dd touch uname unpigz wipefs"
required_tools="$required_tools mountpoint blockdev"

# Variables list for transfer to the chroot'ed scripts
chroot_vars="unique_clone keep_uuids remove_kernel_pattern kernel_flavours"
chroot_vars="$chroot_vars biosboot_too efi_distributor grub_install_opts"
chroot_vars="$chroot_vars hypervisor platform pt_schema uefiboot target"
chroot_vars="$chroot_vars debugging have_tbh have_nvram no_nvram have_rpmdb"

# IBM Power PReP partition GUID for grub-ieee1275
readonly prepguid="9E1A2D38-C612-4316-AA26-8B49521E5A8B"

# BIOS Boot partition GUID for grub-pc and grub-efi
readonly bbp_guid="21686148-6449-6E6F-744E-656564454649"

# Exit codes
readonly EXIT_SUCCESS=0
readonly UNKNOWN_ERROR=1
readonly INVALID_USAGE=2
readonly METADATA_ERROR=3
readonly BAD_CHECKSUM=4
readonly ACCESS_ERROR=5
readonly DISK_IO_ERROR=6
readonly RESTORE_ERROR=7

