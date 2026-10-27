# Session Summary

## Date

2026-10-10, continued 2026-10-17

## Scope

Issue #2 fix, then a phased upgrade (framework, dry-run coverage, catalog refresh) released up to 1.1.6.

## Releases

| Version | PR | Content |
|---|---|---|
| 1.1.3 | #5 | `--dry-run`/`--target`/`--yes` for uninstall helpers; Nezha agent v1+ with SHA-256; Docker `--status`/`--dry-run`; executed dry-run behavior test |
| 1.1.4 | #6 | `--dry-run` for optimize/hostname/timezone/update; timezone path traversal, SSH baseline validation, yum/dnf reboot detection fixes |
| — | #7 | AGENTS.md "Catalog Freshness" rule; LDNMP split marked not planned |
| 1.1.5 | #8 | Service install / other tools / community refresh; first-party `scripts/other_tools/frp.sh` replacing a 404 installer |
| 1.1.6 | #9 | Proxy tools refresh: S-UI, v2ray-agent, official Hysteria2/Xray; x-ui-yg and X-Panel URL updates |
| 1.1.7 | #10 | First-party hardening: install_deps dry-run; performance soft-fail installs; --skip-install; CLI validation |
| 1.1.8 | #11 | Mocked pkg/systemd real paths for bbr/fail2ban; Go/Node SHA-256 verification |
| 1.1.9 | #12 | Non-interactive apt (ported from local working copy); Java toolchain checksums; TLS/HTTP guard; swap `--size/--yes/--remove`; scoped install_deps repos; swap/install_deps mocks |
| 1.1.10 | #14 | Redis redis-hashes SHA-256; AMH / BT beta HTTPS; optimize/clean mocked real paths; VPS_APT_* overrides |
| 1.1.11 | #15 | aaPanel TLS fix; Jenkins/PostgreSQL/K8s HTTPS; tighter upgrade-hardening |
| 1.1.12 | #17 | Ruby releases.yml SHA-256; hostname/timezone mocked real paths |
| 1.1.13 | #20 | update_system mocks; Oracle 17 archive; GraalVM live tags |
| 1.1.14 | #22 | rustup-init SHA-256; seedloc→docs; catalog URL re-check |
| 1.1.15 | #24 | Nezha/FRP path mocks; Jenkins WAR SHA-256 |
| 1.1.16 | #26 | uninstall rollback/clear/clean mocks; swap fstab fix |
| 1.1.17 | #28 | catalog pins; Oracle 8/11 refuse; CRI-O/ELF guards |
| 1.1.18 | #30 | jenkins/k8s apt signed-by; pkgs.k8s.io migration |
| 1.1.19 | #32 | nginx/mariadb/postgresql signed-by; last apt-key gone |
| 1.1.20 | #34 | BT cleanup VPS_BT_* + local vendor uninstall; catalog re-check |
| 1.1.21 | #36 | Python digest; bash -n remote installers; nginx/apache/mysql/php clean mocks |
| 1.1.22 | #38 | Beszel agent; CyberPanel demoted; panel installer bash -n |
| 1.1.23 | #40 | RVM/Helm/wasm-pack bash -n; LDNMP Compose ELF; Beszel hub pin |
| 1.1.24 | #42 | Nginx source PGP; WP-CLI SHA-256 |
| 1.1.25 | #44 | K8s manifests local fetch + kind check; catalog re-check |

## Decisions

- LDNMP stays one combined installer (not split).
- Catalog reviews add popular maintained projects and move archived/stale entries to the end with a label instead of deleting them.
- Every version bump syncs version.json, config, `vps.sh`, README badge and release line, VERSIONING, CHANGELOG, CLAUDE, PROGRESS, TASKS, then PR → merge → GitHub Release.
- Docker-based `run_remote_command` entries must start with `DOCKER_REQUIRED_CHECK`.

## Validation

- All `tests/*.sh` pass locally; ShellCheck CI green on every PR.
- `tests/validate_upgrade_hardening.sh` blocks reintroducing dead or superseded third-party URLs (funnyzak FRP, Uptime Kuma 1, GitLab x-ui-yg, `xeefei/3x-ui`).

## Recommended Next Step

Keep catalog URL liveness on each release; kernel rollback stays interactive-only.
