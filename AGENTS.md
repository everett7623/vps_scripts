# AGENTS.md

This file describes how human contributors and coding agents should work in this repository.

## Goals

- Keep first-party scripts reliable under repeated execution
- Favor modular scripts over the legacy monolithic launcher
- Improve safety without breaking common VPS workflows
- Leave the repository easier to review after every change

## Working Rules

- Prefer editing the modular path (`vps.sh`, `lib/`, `scripts/`, `tests/`) over expanding `vps_scripts.sh`
- Do not replace user changes blindly; inspect before overwriting
- Avoid destructive commands unless the task explicitly requires them
- Treat root-level filesystem and package-manager operations as high risk
- Keep new files ASCII unless there is a strong reason to introduce other characters

## Shell Standards

- Quote variables unless unquoted expansion is required
- Avoid `eval` unless there is no safer alternative
- Prefer arrays over command strings for package-manager commands
- Prefer `mktemp` over predictable `/tmp` filenames
- Validate user input before using it in commands, paths, or service names
- When downloading first-party modules, download to a temp file and execute that file instead of process substitution

## Remote Execution Policy

- First-party launcher actions should point only to files that exist in this repository
- Third-party remote commands should be clearly separated from first-party modules
- Interactive confirmation is preferred before executing third-party one-liners
- Document third-party dependencies in `PRIVACY.md` or the relevant script header

## Validation Baseline

Run at least:

```bash
bash -n vps.sh
bash -n path/to/changed_script.sh
LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh
```

If available, also run:

```bash
shellcheck vps.sh path/to/changed_script.sh
```

## Documentation Expectations

Update the relevant docs when behavior changes:

- `README.md` for user-visible workflow changes
- `CHANGELOG.md` for notable changes
- `PROGRESS.md` and `TASKS.md` for roadmap changes
- `RELEASE_CHECKLIST.md` when release process changes

## Review Priorities

When reviewing changes, focus on:

- Reliability
- Safety
- Idempotency
- Error handling
- Input validation
- Logging clarity
- Menu-to-script consistency
- Testability
