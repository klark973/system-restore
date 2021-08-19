###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021, ALT Linux Team

#####################################################
### Common options for deploy and restore actions ###
#####################################################

# Source images and deploy system version in numeric
# format MAJOR[.MINOR] or empty value (by default)
# if versioning not used
release=

# Default path to RELEASE file in the target system
release_file=/etc/rootfs-release

# non-empty when deploy or restore on the bare-metal,
# by default set as profile name, but can be changed
# in the restore.ini supplied with the profile, not
# used with 'virtual' profile
baremetal=

# Target whole disk drive DEVICE name (optional)
target=

# Target whole disk drive MODEL name pattern,
# this is not used if value is empty (by default)
target_model_pattern=

# Minimum of the target device size for auto-detection,
# empty value (by default) for calculate this value by
# sizes summa of the all used partitions
target_min_capacity=

# 1: turn ON backup checksums validation before deploy
# or restore action (by default, it is safer but longer)
validate=1

# 1: enable deploy or restore to removable devices
removable=

# empty: generate new partition UUID's (by default for deploy)
# 1: keep original partition UUID's (by default for restore)
keep_uuids=

# 1: enable write to NVRAM on the target host (only whith UEFI
# boot or if PReP exists, by default auto-detected in run-time),
# empty: disable write to NVRAM on the target host
have_nvram=

# 1: clear NVRAM before store new record (only if uefiboot=1
# or if PReP exists on IBM Power)
clear_nvram=

# non-empty: setup also /EFI/BOOT/BOOTX64.EFI by specified names
# of the directory in /EFI and EFI-boot image (only if uefiboot=1),
# for example: "altlinux/shimx64.efi"
safe_uefi_boot=

# Auto-detected in run-time EFI Distributor ID if value not set
efi_distributor=

# empty (by default): auto-detect in run-time wich target system
# has rpm executable and valid RPM database, non-empty: turn OFF
# this auto-detcion, 1: target system has RPM, 2: target system
# has no rpm executable and valid RPM database
have_rpmdb=

# empty: TBH device not required (by default)
# 1: TBH device is recommended, warning if not found
# 2: TBH device is required, fatal message if not found
check_tbh=

# 1: use "-O ^64bit,^metadata_csum" options with mke2fs >= 1.43
# while formatting bootable device (root or /boot partition)
# for better compatibility with the some TBH models
old_ext4_boot=

# Additional options for grub-install (optional)
grub_install_opts=

# Users list to re-create /home directory contents, existing
# home archive will be ignored with this option, used only
# in deploy and full-restore modes
create_users=

# Pattern to remove old Linux kernel in the chroot,
# for example: '5.4.68-std-def-*', not used if empty
remove_kernel_pattern=

# Space separated list of the Linux kernel flavours
# for hardware specilization on the target system,
# this list required and cannot be empty
kernel_flavours="std-def un-def"

# Defaults for chroot environment
chroot_PATH="/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin:/usr/local/bin"
chroot_LC_ALL="C.utf8"
chroot_TERM=linux

############################
### restore only options ###
############################

# 1: enable to expand last partition before formatting,
# this option used only in the full-restore mode
expand_last_part=

# 1: make unique clone of the system and use deploy hooks
# after restore partitions (always set to 1 in deploy mode)
unique_clone=

###########################
### deploy only options ###
###########################

# Computer name inside source rootfs backup
template=computername

# Target computer base name
computer=host

# 1: cleanup rootfs from the trash files after restore
cleanup_after=

# 1: turn ON optimizations for SSD/NVME, such as "discard"
use_ssd=

# Single wired interface name on the target system (optional)
wired_iface=

# 1: add BIOS/CSM boot mode support (only on x86_64 if uefiboot=1)
biosboot_too=

# 1: force using GUID/GPT partitioning schema
force_gpt_label=

# 1: force using DOS/MBR partitioning schema
force_mbr_label=

# EFI System partition size (optional)
esp_size=

# Power PReP partition size (optional)
prepsize=

# BIOS Boot partition size (optional)
bbp_size=

# /boot partition size (required only on Elbrus, optional on all other)
bootsize=

# SWAP partition size (optional, auto-detected by default)
swapsize=AUTO

# / (root) partition size (optional)
rootsize=

# ESP (EFI System Partition) mount options
esp_opts="umask=0,quiet,showexec,iocharset=utf8,codepage=866"

