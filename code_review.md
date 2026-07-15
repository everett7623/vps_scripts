# Code Review

This file captures current high-priority findings and the next review direction.

## Current State (2026-07-15)

Version 1.1.0 prepares the accumulated post-1.0.0 work for release. All repository validation tests pass locally through Git Bash, the launcher and core metadata agree, and the new modern CLI toolkit stays within configured distribution repositories.

## Findings

### High (open)

- `scripts/other_tools/bbr.sh` replaces the complete `/etc/sysctl.conf`; it must use a dedicated drop-in and restore only project-owned settings.
- `scripts/other_tools/swap.sh` runs `swapoff -a`, recreates `/swapfile`, and appends to `/etc/fstab` without deduplication; repeated execution can disrupt unrelated swap devices.
- `scripts/other_tools/fail2ban.sh` replaces `jail.local` and assumes one SSH log path/filter layout across distributions.
- `scripts/other_tools/nezha.sh` writes user-supplied server, port, and secret values directly into a systemd unit without sufficient validation or escaping.

### Medium (open)

- Several third-party launcher entries still use `curl | sh`, process substitution, fixed `amd64` downloads, or files in the current directory.
- `install_deps.sh` has a very broad “all tools” scope and may configure extra repositories; narrower groups and clearer previews would reduce blast radius.
- Tests are strong on syntax and static policy but still light on container-based behavior and idempotency.

### Completed in 1.1.0

- Hardened all 21 service installers with strict-mode coverage
- Hardened network and performance scripts with strict mode and safe temporary directories
- Added launcher syntax checks and temporary execution for first-party modules
- Added a first-party modern CLI toolkit with non-interactive status/install flags
- Made ShellCheck error findings gating in CI
- Removed implicit launcher analytics/counter requests
- Repaired the stale removed-directory validation
- Synchronized project metadata and documentation at version 1.1.0

## Next Recommended Review Targets

1. BBR and Swap configuration ownership/idempotency
2. Fail2ban and Nezha input/configuration safety
3. Architecture-aware wrappers for cloudflared, Caddy, and other third-party installers
4. Container-based behavioral tests on Debian, Ubuntu, Rocky/Alma, and Alpine
