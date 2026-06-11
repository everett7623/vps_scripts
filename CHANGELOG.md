# Changelog

All notable changes to this repository are documented here.

## Unreleased

## 1.0.0 - 2026-06-12

### Added
- Modular `vps.sh` launcher with system, network, performance, service, community, proxy, utility, and uninstall menus.
- First-party module loading with local-repository support, isolated temporary runtime directories, syntax validation, and download fallbacks.
- Responsive terminal UI with centered headings, CJK-aware alignment, compact narrow-screen rows, and UTF-8 locale fallback.
- Shared UI, logging, configuration, input, download, service, and cleanup helpers.
- System health and security audit tools.
- Persistent `vps` command installation and removal.
- Legacy-only `vps_scripts.sh` compatibility handoff.
- 30 repository validation scripts covering launchers, assets, UI, syntax, runtime layout, input contracts, and installer safety.

### Changed
- Standardized project, launcher UI, and project-owned module versions at `1.0.0`.
- Standardized system-tool output and hardened core service installers.
- Updated README, development guidance, release checklist, task tracking, progress, and review documentation for the initial stable baseline.

### Fixed
- Corrected launcher paths that referenced missing modules.
- Added confirmation and syntax checks before third-party script execution.
- Fixed non-interactive menu EOF handling and terminal clearing behavior.
- Fixed mixed Chinese/ASCII alignment, narrow-terminal overflow, malformed terminal width handling, and `LC_ALL=C` display-width behavior.
- Hardened temporary-file cleanup, quoting, input validation, package-manager handling, and strict-mode edge cases across maintained scripts.
