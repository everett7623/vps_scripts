# Tasks

## P0

- Refactor `scripts/system_tools/update_system.sh` to reduce or remove avoidable `eval` (done: array execution plus execution-safety regression test)
- Review `lib/common_functions.sh` for helper safety, quoting, and temp-file handling
- Decide whether `vps_scripts.sh` remains supported or becomes explicitly legacy-only

## P1

- Review `scripts/service_install/nodejs.sh` (done: version validation and temp-file remote installer execution)
- Review `scripts/service_install/python.sh`
- Review `scripts/service_install/kubernetes.sh`
- Add a validation script for service-install launcher coverage (done: `tests/validate_service_install_launcher.sh`)
- Add a validation script for launcher/update execution safety (done: `tests/validate_execution_safety.sh`)
- Migrate useful history from `update_log.sh` into `CHANGELOG.md`

## P2

- Normalize logging conventions across modules (in progress: shared UI/runtime helpers added)
- Standardize script headers and encoding
- Add more non-interactive safety flags where appropriate
- Review `update_scripts/` and determine whether those scripts still belong in the active architecture

## Documentation

- Keep `README.md` aligned with the modular launcher path
- Update `CHANGELOG.md` on every notable fix set
- Refresh `PROGRESS.md` after each optimization round
