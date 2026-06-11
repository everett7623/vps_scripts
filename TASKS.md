# Tasks

## P0

- Refactor `scripts/system_tools/update_system.sh` to reduce or remove avoidable `eval` (done: array execution plus execution-safety regression test)
- Review `lib/common_functions.sh` for helper safety, quoting, and temp-file handling (done: exact config keys, same-directory atomic writes, permission preservation, and symlink cleanup guard)
- Decide whether `vps_scripts.sh` remains supported or becomes explicitly legacy-only (done: supported legacy-only compatibility handoff)

## P1

- Review `scripts/service_install/nodejs.sh` (done: version validation and temp-file remote installer execution)
- Review `scripts/service_install/docker.sh` (done: temp-file downloads and guarded removal paths)
- Review `scripts/service_install/go.sh` (done: strict inputs, isolated archive download, guarded replacement, and temp-file remote tool installer)
- Review `scripts/service_install/java.sh` (done: strict inputs, isolated archive downloads, quoted Java paths, and fixed-archive removal)
- Review `scripts/service_install/nginx.sh` (done: temp-file key import, isolated source build, quoted make parallelism, and safe cleanup)
- Review `scripts/service_install/python.sh` (done: strict inputs, temp-file pyenv installer, eval removal, isolated source build cleanup)
- Review `scripts/service_install/kubernetes.sh` (done: validated options and eval-free kubeadm join execution)
- Add a validation script for service-install launcher coverage (done: `tests/validate_service_install_launcher.sh`)
- Add a validation script for launcher/update execution safety (done: `tests/validate_execution_safety.sh`)
- Add launcher coverage for active non-system categories (done: `tests/validate_active_category_coverage.sh`)
- Migrate useful history from `update_log.sh` into `CHANGELOG.md` (done: `CHANGELOG.md` is canonical; `update_log.sh` is a compatibility viewer)

## P2

- Normalize logging conventions across modules (in progress: shared UI/runtime helpers added)
- Optimize module loading speed and slow-network behavior (in progress: local fast path and parallel module bundle loading added)
- Standardize script headers and encoding (done: repository LF policy and shell header/CRLF/BOM validation added)
- Add more non-interactive safety flags where appropriate
- Review `update_scripts/` and determine whether those scripts still belong in the active architecture (done: retained as inactive legacy/reference only)

## Documentation

- Keep `README.md` aligned with the modular launcher path
- Update `CHANGELOG.md` on every notable fix set
- Refresh `PROGRESS.md` after each optimization round
