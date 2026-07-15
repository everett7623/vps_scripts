# Release Checklist

## Release Contract

Every published release must use a new semantic version and update the release date, public documentation, and release notes in the same commit. Do not publish a tag or GitHub Release while any of these files still describe the previous version.

Required synchronized files:

- `version.json`: project version, release date, and update message
- `config/vps_scripts.conf` and `vps.sh`: runtime project version
- `README.md`: public version badge and user-visible inventory
- `CHANGELOG.md`: dated release section below an empty `Unreleased` heading
- `VERSIONING.md`: active version and policy
- `PROGRESS.md` and `TASKS.md`: completed milestone and next backlog

The release commit must pass `REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_release_metadata.sh`. After pushing the release commit, create the matching annotated `vX.Y.Z` tag and GitHub Release from the corresponding `CHANGELOG.md` section.

## Before Version Bump

- Confirm the modular launcher still points only to existing repo files
- Review any new third-party remote commands
- Check docs for user-visible workflow changes
- Verify `version.json` metadata matches intended release state

## Validation

- Run `bash -n vps.sh`
- Run `bash -n` for changed scripts
- Run `LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh`
- Run `REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_core_assets.sh`
- Run `REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_ui_layout.sh`
- Run `REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_release_metadata.sh`
- Run the complete suite and require zero failures: `for f in tests/*.sh; do bash "$f" || exit 1; done`
- Run `shellcheck` on changed scripts if available

## Release Content

- Update `CHANGELOG.md`
- Update `VERSIONING.md` if policy changed
- Update `README.md` if install or usage guidance changed
- Review `TASKS.md` and `PROGRESS.md` for any completed milestones
- Prepare the GitHub Release notes from the matching `CHANGELOG.md` section

## Packaging And Metadata

Bump the version number in ALL of these files (grep `[0-9]\+\.[0-9]\+\.[0-9]\+` to find every occurrence):

- `version.json` — `version` + `release_date`
- `config/vps_scripts.conf` — `SCRIPT_VERSION`
- `vps.sh` — `PROJECT_VERSION`
- `README.md` — version badge URL
- `CLAUDE.md` — version reference in "Version metadata" section
- `VERSIONING.md` — active version listed in "Current State"
- `version.json`, `config/vps_scripts.conf`, and `vps.sh` — launcher style version when the terminal UI changes
- Project-owned module `SCRIPT_VERSION` constants when intentionally publishing a synchronized baseline

Then verify: `REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_core_assets.sh` (enforces project and launcher style versions across metadata, config, and launcher)
- Regenerate any checksums if release workflow uses them

## Final Sanity Check

- Test the remote launcher command from a clean environment
- Confirm dependency installation help output still works
- Confirm no launcher menu entry points to a missing script
- Push the release commit before creating the annotated version tag
- Confirm the GitHub Release title and tag match `version.json`
