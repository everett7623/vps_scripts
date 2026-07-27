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

## Follow-up

A real Debian 13 installation then failed because the dependency list included
`software-properties-common`, which the script does not use and the host could
not locate. The same list also included the obsolete `apt-transport-https`
transitional package. Both were removed, leaving only packages used by the
installer, and the safety test now prevents these dependencies from returning.

### Compose download

The next real installation reached the Docker Compose download but received a
GitHub `404`. The installer reused Debian's `amd64` package architecture in the
release asset name, while Docker Compose publishes `x86_64`. Compose-specific
mappings now cover `x86_64`, `aarch64`, and `armv7`, with regression assertions
for all supported installer architectures.

## Validation

- `bash -n scripts/service_install/docker.sh`
- `bash tests/validate_docker_installer_safety.sh`
- `LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh`
- `shellcheck scripts/service_install/docker.sh tests/validate_docker_installer_safety.sh` when available
