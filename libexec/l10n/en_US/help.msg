Usage: @PROG@ <action> [<options>...] [--] [<target>...]

Actions:
  -c, --check-only  Only check images and backup metadata.
  -C, --check-conf  Also check user-defined scripts and config,
                    supplied with the backup.
  -v, --validate    Check backup and validate all images checksums.
  -t, --scan-only   Scan disk drives and lock for potential targets.
  -m, --make-id     Create sub-directory 'id' with the host DMI-info.
  -d, --deploy      Deploy mode: full restore and make unique clone.
  -f, --full        Restore all partitions with disk repartitioning.
  -s, --system      Restore only system partitions, don't touch user
                    data partition and disable disk repartitioning.
  -V, --version     Show this program version.
  -h, --help        Show this help message.

Options:
  -R, --reboot      Reboot machine after success restore.
  -P, --poweroff    Turn power OFF after success restore.
  -b, --backup=     Specify alternate path to the backup.
  -p, --profile=    Specify profile name (sub-directory) to use.
  -r, --removable   Enable to use removable devices as targets.
  -x, --exclude=    Add specified block special device or mount point
                    to the write-protected devices list, it excluded
                    when search target disk drive. This option can be
                    repeated several times.
      --no-log      Turn OFF logging to file.
      --no-hooks    Disable to use user-defined scripts supplied with
                    the backup and/or profiles. This may be useful
                    for debug failures and by security reasons.
      --no-dialogs  Disable dialogs, output to console only.
      --show-diag   Show diagnostics before start the recovery process.
  -n, --dry-run     Don't write anything to any disks, check only.
  -l, --logfile=    Use specified path to the log file or device.
  -a, --append      Don't overwrite the log file, append only.
  -u, --syslog      Use system log and the logger command.
  -D, --debug       Turn ON extended program debugging.

Examples:
  @PROG@ --validate

  The backup metadata and image cheksums will be validated. The backup
  located in the current working directory.

  @PROG@ -d -P -b /mnt/backup -p grav-2021 -- /dev/nvme0n1

  The backup in /mnt/backup directory will be checked first, also
  will be checked and set to directly use profile "grav-2021", device
  /dev/nvme0n1 will be cleaned, repartitioned, restored from the backup
  in "deploy mode", host private data will be regenerated for installation
  personification, and after success recovery the computer power will be
  turned OFF.

User manual:
  https://www.altlinux.org/Rescue/Recovery (ru)

Please, report bugs to https://bugzilla.altlinux.org/
