# Versioning

## Current State

The repository currently exposes version metadata through `version.json`, with the active project version listed as `1.1.13`.

The public tag history starts at `v1.0.0`. Version `1.1.13` is a backward-compatible patch release that adds mocked real-path coverage for `update_system.sh` (`VPS_UPDATE_BACKUP_DIR`, `VPS_REBOOT_REQUIRED_FILE`, `VPS_APT_CACHE_FILE`, `VPS_SKIP_NETWORK_CHECK`), moves Oracle JDK 17 downloads to the current archive URL with `.sha256`, and pins GraalVM community builds to live `jdk-17.0.9` / `jdk-21.0.2` release tags. Release tags and GitHub Releases are published as explicit release operations.

## Recommended Policy

Use semantic versioning for code releases:

- `MAJOR`: incompatible behavior or architecture changes
- `MINOR`: new backward-compatible features
- `PATCH`: backward-compatible fixes, documentation corrections, and safety improvements

## Documentation Policy

- `version.json` is the machine-readable source for launcher metadata
- `CHANGELOG.md` is the human-readable change log
- `update_log.sh` is a legacy compatibility viewer; `CHANGELOG.md` is the canonical historical record
- Every published release must bump and synchronize version metadata, README badge, CHANGELOG section, VERSIONING current state, and release checklist expectations in the same commit

## Release Rule Of Thumb

- Menu mapping fixes, validation additions, and safer command execution usually qualify for a patch release
- New script groups or substantial new capabilities qualify for a minor release
- Breaking launcher behavior or removing legacy paths qualifies for a major release
