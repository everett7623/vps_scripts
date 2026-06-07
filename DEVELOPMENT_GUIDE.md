# Development Guide

## Recommended Workflow

1. Inspect the target script and any shared helpers it sources.
2. Check whether the change belongs in the modular path or only in the legacy launcher.
3. Make the smallest change that improves reliability or safety without hiding errors.
4. Run syntax validation and any relevant lightweight repo tests.
5. Update docs if behavior or workflow changed.

## Local Validation

Baseline:

```bash
bash -n vps.sh
bash -n scripts/system_tools/install_deps.sh
LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_core_assets.sh
```

Recommended when available:

```bash
shellcheck vps.sh scripts/system_tools/install_deps.sh
```

## Change Priorities

- First-party launcher safety
- Idempotent installers
- Reduced hidden side effects
- Clear rollback and cleanup behavior
- Consistent logging and status messages

## Script Design Notes

- Prefer one responsibility per script
- Keep shared helpers in `lib/common_functions.sh`
- Avoid new menu entries unless the referenced script already exists
- Prefer repo-local validation scripts over manual spot checks where practical

## Documentation Rules

- Keep docs aligned with real repository behavior
- If a launcher menu changes, update `README.md`, `TASKS.md`, and `CHANGELOG.md` as needed
- If a release process changes, update `RELEASE_CHECKLIST.md` and `VERSIONING.md`
