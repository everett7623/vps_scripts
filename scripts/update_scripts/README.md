# Legacy Update Scripts

This directory is retained for historical reference only.

These scripts are not part of the active modular launcher architecture. They predate the current `vps.sh` remote-module flow and include broad update behavior such as whole-directory replacement, package-manager updates, and placeholder repository sources.

Current maintenance policy:

- Do not add these scripts to `vps.sh` menus.
- Do not use these scripts for first-party module updates.
- Prefer Git pull/checkout workflows for repository updates.
- Prefer the modular scripts under `scripts/system_tools/`, `scripts/service_install/`, and repo-local validation tests for active maintenance.

If any behavior from this directory is needed again, migrate it into a narrowly scoped modern module with tests instead of re-enabling these scripts directly.
