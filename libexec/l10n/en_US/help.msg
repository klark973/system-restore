Usage: @PROG@ <action> [<options>...] [--] [<target>...]

Actions:
  -c, --check-only  Check only backup images and metadata.
  -C, --check-conf  Also check the custom scripts and configuration
                    that came with the backup.
  -v, --validate    Check the backup and validate the checksums
                    of all backup images.
  -t, --scan-only   Scan disk drives and look for potential targets.
  -m, --make-id     Create a sub-directory 'id' with the host DMI-info.
  -d, --deploy      Deployment mode: full recovery and creation of
                    a unique clone.
  -f, --full        Recover all partitions with disk repartitioning.
  -s, --system      Recover only system partitions, leave the user data
                    partition alone, and disable disk repartitioning.
  -V, --version     Show the version of this program.
  -h, --help        Show this help message.

Options:
  -R, --reboot      Reboot the machine after a successful recovery.
  -P, --poweroff    Turn power off after successful recovery.
  -b, --backup=     Specify an alternative path to the backup.
  -p, --profile=    Specify the profile name (subdirectory) to be used.
  -r, --removable   Enable the use of removable devices as targets.
  -x, --exclude=    Add the specified block special device or mount point
                    to the list of write-protected devices so that they
                    are excluded when searching for the target disk drive.
                    This option can be repeated several times.
      --no-log      Turn off logging to a file.
      --no-hooks    Disable the use of custom scripts provided with
                    backup and/or profiles. This can be useful for
                    debug failures and for security reasons.
      --no-dialogs  Disable dialogs, output only to the console.
      --show-diag   Show diagnostics before starting the recovery process.
  -n, --dry-run     Don't write anything to any disks, check only.
  -l, --logfile=    Use specified path to the log file or device.
  -a, --append      Don't overwrite the log file, only append.
  -u, --syslog      Use syslog and the logger command.
  -D, --debug       Enable advanced program debugging.

Examples:
  @PROG@ --validate

  The backup metadata and image cheksums will be validated. The backup
  located in the current working directory.

  @PROG@ -d -P -b /mnt/backup -p grav-2021 -- /dev/nvme0n1

  The backup in the /mnt/backup directory will be checked first, will
  also be checked and configured to directly use the "grav-2021" profile,
  the /dev/nvme0n1 device will be wiped, repartitioned, restored from the
  backup in "deployment mode", the unique host data will be reinitialized
  to personalize the installation, and after successful restoration, the
  computer will be powered off.

User manual:
  https://www.altlinux.org/Rescue/Recovery (ru)

Please, report bugs to https://bugzilla.altlinux.org/
