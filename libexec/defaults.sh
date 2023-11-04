###
### This file is covered by the GNU General Public License
### version 3 or later.
###
### Copyright (C) 2021-2023, ALT Linux Team

#####################################################
### Common options for deploy and restore actions ###
#####################################################

# Source images and deploy system version in the numeric
# format MAJOR[.MINOR] or empty value (by default), if
# versioning is not used
release=

# Default path to RELEASE file in the target system
release_file=/etc/rootfs-release

# Non-empty when deploy or restore on the bare metal,
# by default set as profile name, but can be changed
# in the restore.ini supplied with the profile, not
# used with the 'virtual' profile
baremetal=

# Computer name inside source rootfs backup (will be
# extracted from backup metadata: ORGHOST, by default)
template=

# The target computer base name (required)
computer=host

# How to create unique hostname? Available algorithms are:
# copy: do not change source template, just copy it "as is".
# ip1: add last (4'th) part of the IP-address to the base name.
# ip2: add two last (3'rd and 4'th) parts of the IP-address.
# ip3: add three last (2'nd...4'th) parts of the IP-address.
# hw6: add six hexadecimal digits from Ethernet MAC-address.
# rnd: generate random part and add it to the base name.
# <hook>: use user-defined hostnaming function.
# Default value is "hw6" for deploy or "copy" for restore.
hostnaming=copy

# How to disk(s) partitioning? Available options are:
# plain: one-drive DOS/MBR or GUID/GPT default layout.
# timeshift: one-drive timeshift-compatible layout.
# lvm: one-drive LVM default layout.
# raid: multi-drives default layout.
# <hook>: use user-defined partitioner.
# Default value for deploy mode is "plain".
partitioner=plain

# Source disk drives for build only one target device
multi_targets=

# The number of the source disk drives for build target
num_targets=

# Device name of the target whole disk drive (optional)
target=

# Model name pattern of the target whole disk drive
# (optional), for example: "*SAMSUNG_MZVL21T0HCLR*"
target_model_pattern=

# Minimum size of each target device for auto-detection,
# empty value (by default) to calculate this value as
# the sum of the sizes of all used partitions
target_min_capacity=

# Maximum size of each target device for auto-detection,
# empty value (by default) when upper limit is not used
target_max_capacity=

# By default this field is empty. Otherwise it contains a
# device name with the IMSM container, for example "/dev/md0".
# If the field is non empty, looks for target devices connected
# only to mdadm FakeRAID (IMSM), such as Intel VROC/iRST/RSTe.
imsm_container=

# By default this field is empty. Otherwise we won't wait for
# the RAID(s) to sync before finalizing the primary action.
no_md_sync=

# 1: enable deploy or restore to removable devices
removable=

# 1: turn ON backup checksums validation before deploy
# or restore action (by default, it is safer but longer)
validate=1

# Empty: generate new partition UUID's (by default for deploy)
# 1: keep original partition UUID's (by default for restore)
# it can be changed anyway
keep_uuids=

# 1: clear NVRAM before store new record (only if uefiboot=1)
clear_nvram=

# 1: disable write to NVRAM before finish restore (this is useful
# when UEFI bootloader alredy made the record or if NVRAM is not
# supported by efibootmgr on this hardware), empty: enable write
# to NVRAM in UEFI-boot mode when it needed (by default)
no_nvram=

# Non-empty: setup also standard EFI-boot image to the /EFI
# directory by specified file name (only if uefiboot=1), for
# example: "altlinux/shimx64.efi" => "/EFI/BOOT/BOOTX64.EFI"
safe_uefi_boot=

# Auto-detected in run-time EFI Distributor ID if value not set
efi_distributor=

# Empty (by default): auto-detect in run-time which target system
# has rpm executable and valid RPM database, non-empty: turn OFF
# this auto-detcion, 1: target system has RPM, 2: target system
# has no rpm executable and valid RPM database
have_rpmdb=

# Empty: TBH device not required (by default)
# 1: TBH device is recommended, warning if not found
# 2: TBH device is required, fatal message if not found
check_tbh=

# 1: use "-O ^64bit,^metadata_csum" options with mke2fs >= 1.43
# while formatting bootable device (root or /boot partition)
# for better compatibility with the some TBH models
old_ext4_boot=

# Additional options for grub-install (optional)
grub_install_opts=

# Users list to remove with the /home directory contents,
# it used only in deploy and full-restore modes, used only
# in deploy and full-restore modes
remove_users_list=

# Users list to re-create /home directory contents, existing
# home archive will be ignored with this option, used only
# in deploy and full-restore modes
create_users_list=

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
### Restore only options ###
############################

# 1: enable to expand last partition before formatting,
# this option used only in the full-restore mode
expand_last_part=

# 1: make unique clone of the system and use deploy hooks
# after restore partitions (always set to 1 in deploy mode)
unique_clone=

###########################
### Deploy only options ###
###########################

# 1: cleanup rootfs from the trash files after restore
cleanup_after=

# 1: turn ON optimizations for SSD/NVME, such as "discard"
use_ssd=

# Single wired interface name in the target system (optional)
wired_iface=

# 1: add BIOS/CSM-boot mode support (only on x86_64 if uefiboot=1)
biosboot_too=

# 1: force using GUID/GPT partitioning scheme
force_gpt_label=

# 1: force using DOS/MBR partitioning scheme
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

# Default GUID/GPT partition names
prepname=PReP
esp_name=ESP
bbp_name=GRUB
bootname=BOOT
swapname=SWAP
rootname=ROOT
var_name=DATA
homename=HOME

# ESP (EFI System Partition) mount options
esp_opts="umask=0,quiet,showexec,iocharset=utf8,codepage=866"

