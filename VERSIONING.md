# Versioning

## Current State

The repository currently exposes version metadata through `version.json`, with the active project version listed as `2.6.0`.

## Recommended Policy

Use semantic versioning for code releases:

- `MAJOR`: incompatible behavior or architecture changes
- `MINOR`: new backward-compatible features
- `PATCH`: backward-compatible fixes, documentation corrections, and safety improvements

## Documentation Policy

- `version.json` is the machine-readable source for launcher metadata
- `CHANGELOG.md` is the human-readable change log
- `update_log.sh` should be treated as legacy historical output until migrated or retired

## Release Rule Of Thumb

- Menu mapping fixes, validation additions, and safer command execution usually qualify for a patch release
- New script groups or substantial new capabilities qualify for a minor release
- Breaking launcher behavior or removing legacy paths qualifies for a major release
