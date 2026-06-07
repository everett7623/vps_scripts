# Release Checklist

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
- Run `shellcheck` on changed scripts if available

## Release Content

- Update `CHANGELOG.md`
- Update `VERSIONING.md` if policy changed
- Update `README.md` if install or usage guidance changed
- Review `TASKS.md` and `PROGRESS.md` for any completed milestones

## Packaging And Metadata

- Update `version.json`
- Verify release date and changelog URL
- Regenerate any checksums if release workflow uses them

## Final Sanity Check

- Test the remote launcher command from a clean environment
- Confirm dependency installation help output still works
- Confirm no launcher menu entry points to a missing script
