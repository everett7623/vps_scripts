# Fix Docker installer on Debian 13

Status: completed
Date: 2026-07-27
Author: everettlabs

## Scope

- Compare the local Docker installer with `origin/main`.
- Confirm upstream Docker Engine support for Debian 13 (Trixie).
- Add Debian 13 to the installer compatibility allowlist.
- Add a regression assertion to the existing Docker installer safety test.
- Record the user-visible fix in `CHANGELOG.md`.

## Root cause

The Debian compatibility allowlist stopped at version 12, so Debian 13 exited
before repository setup even though Docker officially supports Trixie.

## Validation

- `bash -n scripts/service_install/docker.sh`
- `bash tests/validate_docker_installer_safety.sh`
- `LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh`
- `shellcheck scripts/service_install/docker.sh tests/validate_docker_installer_safety.sh` when available
