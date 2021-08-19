###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

#####################################################
### Internal variables, don't use in restore.ini! ###
#####################################################

# Specified action name (required)
action=

# Auto-detected or specified sub-profile name (optional)
profile=

# Auto-detected information about target disk drive
diskinfo=

# Auto-detected hardware platform name
platform=

# Temporary work directory (created in run-time)
workdir=

# Auto-detected native language code, such as 'en_US'
lang=

# Backup directory (current work directory by default)
backup="$(realpath .)"

# empty: do not show diagnostics before primary action
# (by default), 1: show diagnostics before primary action
show_diag=

# 1 (by default): check the backup and metadata
use_backup=1

# 1 (by default): enable to use user-defined hooks and
# scripts supplied with the backup and/or sub-profile
use_hooks=1

# 1 (by default): show dialogs, empty: use stdout only
use_dialog=1

# empty (by default): target disk drive not used
# 1: target disk drive must be found before start
# the primary action (this is set in run-time)
use_target=

# empty: deploy or restore on the bare-metal (by default)
# hypervisor name if work inside hypervisor (set in run-time)
hypervisor=

# Creating disk label type (auto-detected in run-time)
# "dos": DOS/MBR partitioning schema will be used
# "gpt": GUID/GPT partitioning schema will be used
pt_schema=

# 1: UEFI boot mode (auto-detected in run-time)
uefiboot=

# 1: Need to convert UEFI boot in the source backup
# to BIOS/CSM boot mode (auto-detected in run-time)
uefi2bios=

# 1: Need to convert BIOS/CSM boot in the source backup
# to UEFI boot mode (auto-detected in run-time)
bios2uefi=

# Auto-detected mke2fs features for ext4 partitions:
# empty: if e2fsprogs <= 1.42.x (64bit turned OFF, by default)
# 1: if e2fsprogs >= 1.43.x (64bit+metadata_csum can be used)
new_mkfs=

# non-empty: TBH bootable device name or "1", if
# TBH exists (this is auto-detected in run-time)
have_tbh=

# Archive files type in the backup (auto-detected in run-time)
ziptype=

# Auto-detected names of the partition devices
# (only $rootpart is strictly required by default)
#
# $preppart required for install grub-ieee1275 on IBM Power
# $bbp_part required for install grub-pc to GUID/GPT disk label
# $esp_part need for /boot/efi (required for UEFI boot mode)
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

# "poweroff": turn power OFF after success restore
# "reboot": reboot machine after success restore
# empty (by default): nothing to do, exit only
finalact=

# 1: nothing to do, no destructive actions, check only
dryrun=

# 1: log debug messages, empty: disable debugging (by default)
debugging=

# empty: rewrite log file any time, 1: append to existing log file
append_log=

# empty: disable system logger (by default), 1: use system logger
use_logger=

# Full path to the log file or empty for logging turn OFF
logfile="/var/log/$progname.log"

# System logger priority
logprio="${SYSREST_LOGPRIO:-user.info}"

# Temporary mount point for restore rootfs and chroot
destdir=/mnt/target

# Mount points for auto-detecting write-protected devices
protected_mpoints="/ /image /mnt/autorun"

# Additional devices list for write protection when search
# the target disk drive
protected_devices=

# IBM Power PReP partition GUID for grub-ieee1275
prepguid="9E1A2D38-C612-4316-AA26-8B49521E5A8B"

# BIOS Boot partition GUID for grub-pc and grub-efi
bbp_guid="21686148-6449-6E6F-744E-656564454649"

# Tools wich must be installed inside rescue system before recovery
required_tools="blkid dd lspcu mkfs.ext4 mkfs.fat mkswap pv readlink"
required_tools="$required_tools sfdisk tar touch uname unpigz wipefs"
required_tools="$required_tools blockdev md5sum sha1sum sha256sum"
required_tools="$required_tools addpart delpart"

# Variables list for transfer to the chroot'ed scripts
chroot_vars="unique_clone keep_uuids remove_kernel_pattern kernel_flavours"
chroot_vars="$chroot_vars biosboot_too efi_distributor grub_install_opts"
chroot_vars="$chroot_vars hypervisor platform pt_schema uefiboot target"
chroot_vars="$chroot_vars debugging have_tbh have_nvram have_rpmdb"

# Exit codes
EXIT_SUCCESS=0
UNKNOWN_ERROR=1
INVALID_USAGE=2
METADATA_ERROR=3
BAD_CHECKSUM=4
ACCESS_ERROR=5
DISK_IO_ERROR=6
RESTORE_ERROR=7

