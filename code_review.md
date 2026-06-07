# Code Review

This file captures the current high-priority review findings and follow-up direction.

## Findings

### High

- `vps_scripts.sh` still contains many direct third-party `curl | bash` and `wget ... | bash` flows without a first-party safety wrapper.
- Several installer and update scripts still rely on `eval` for command execution, especially in system update and large service installation flows.
- Some legacy scripts use predictable `/tmp` filenames and cleanup paths that would benefit from stricter temp-file handling.

### Medium

- Logging behavior is inconsistent across modules; some scripts log richly while others only print to stdout.
- Input validation is uneven, especially around versions, hostnames, ports, service names, and package selections.
- Documentation and headers are inconsistent in encoding and style across older files.

### Low

- Release and changelog metadata is split across `version.json`, `update_log.sh`, and future docs.
- Test coverage is still lightweight and mostly syntax/path based.

## Completed In This Optimization Round

- Fixed launcher-to-script mismatches in `vps.sh`
- Added safer first-party module execution flow
- Reworked dependency installer structure and reporting
- Added launcher path validation test
- Added baseline project documentation

## Next Recommended Review Targets

1. `scripts/system_tools/update_system.sh`
2. `lib/common_functions.sh`
3. `scripts/service_install/nodejs.sh`
4. `scripts/service_install/python.sh`
5. `scripts/service_install/kubernetes.sh`
6. `vps_scripts.sh`

## Review Heuristics

Use this checklist when touching a script:

- Can it be run twice safely
- Does it validate external input
- Does it log failures clearly
- Does it avoid fragile temp-file behavior
- Does it avoid avoidable `eval`
- Does it separate first-party and third-party execution clearly
