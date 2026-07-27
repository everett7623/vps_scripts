# Fix full uninstall backup and safety

Status: completed
Date: 2026-07-27
Author: everettlabs

## Root cause

The isolated module lived below `scripts/uninstall_scripts`, while its backup
directory was created below `scripts/backup`. Copying `scripts` into that child
directory failed because the destination was inside the source. The original
file was also truncated before any actual uninstall operation.

## Resolution

- Store durable backups below `/var/backups/vps_scripts`.
- Back up and remove only verified first-party command and launcher artifacts.
- Back up and remove the project-owned `/var/log/vps_scripts` directory.
- Skip same-name command or launcher paths that are not managed by this project.
- Do not stop services, remove packages, or delete application data.
- Add a regression test for backup placement and destructive-operation scope.

## Validation

- `bash -n scripts/uninstall_scripts/full_uninstall.sh`
- `bash tests/validate_full_uninstall_safety.sh`
- `LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh`
