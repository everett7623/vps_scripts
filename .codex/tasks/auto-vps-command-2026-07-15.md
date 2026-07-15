# Automatic vps command installation

## Goal

Create the managed `vps` shortcut automatically on the first interactive root launch while preserving explicit install, opt-out, and collision safety.

## TODO

- [x] Confirm Issue #1 and the existing manual install lifecycle
- [x] Add idempotent automatic installation for interactive root launches
- [x] Protect unrelated `/usr/local/bin/vps` commands from overwrite
- [x] Cover automatic, disabled, non-interactive, and collision behavior
- [x] Update README and CHANGELOG
- [x] Run focused and full validation
