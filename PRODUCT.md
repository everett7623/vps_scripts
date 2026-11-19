# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primary users are Chinese-speaking Linux VPS operators and site owners who manage one or more remote servers. Typical situation: SSH into a VPS and run the toolkit via `curl | bash` or a locally installed `vps` command to diagnose, install, optimize, or clean up the machine without assembling a custom ops playbook.

## Product Purpose

VPS Scripts is a modular Bash toolkit for everyday VPS operations: system maintenance, network and performance diagnostics, service deployment, and related utilities. Success means operators can complete those jobs safely and repeatedly through a clear Chinese terminal menu, with scripts that keep improving in correctness, reliability, and menu UX/logic rather than through a separate graphical product.

## Positioning

First-party modular launcher (`vps.sh`) that downloads and runs repository modules with path validation, temp execution, and a growing validation/safety suite — not a single monolithic unmaintained script dump. Legacy `vps_scripts.sh` stays compatibility-only. Chinese responsive terminal UI (`neon-shell`) is part of the product, not an afterthought.

## Operating Context

- Entry: remote one-liner to `vps.sh`, or persistent `/usr/local/bin/vps` after `--install`
- Environment: Linux VPS shells (Ubuntu, Debian, RHEL-family, Alpine; x86_64 / aarch64); Bash 4+
- Rituals: interactive numbered menus; optional `--dry-run` / `--status` style flags on many modules; root required for many system changes
- Ongoing product work focuses on completing scripts, fixing bugs, and refining terminal menu UI and interaction logic
- Contributors use repo validation scripts (`tests/`, `run_all_tests.sh`) and docs (`README.md`, `CHANGELOG.md`, `AGENTS.md`)

## Capabilities and Constraints

- Categories: system tools, network tests, performance tests, service install, community/proxy third-party entries, other tools, command setup, cleanup/uninstall
- First-party modules run via `run_repo_script()`; third-party remote actions require interactive confirmation
- Shared library: `lib/common_functions.sh`; config: `config/vps_scripts.conf`; version metadata: `version.json`
- License: AGPL-3.0
- Formal OS matrix and arches are defined in `version.json` (Fedora/Arch not canonical)
- Shipped interface today is ANSI terminal menus only (no browser or native app UI). Platform is recorded as `web` because Impeccable's enum has no `cli` value; design craft for this product targets the terminal UI unless a separate web surface is later requested
- Undecided: whether a marketing/docs website will ever be a first-class product surface

## Brand Commitments

- Product name: VPS Scripts
- Author / org signals: everettlabs, GitHub `everett7623/vps_scripts`
- Primary voice and UI language: Chinese
- Terminal theme identifier in code: `neon-shell`
- Do not present legacy `vps_scripts.sh` as the modern feature path

## Evidence on Hand

- Public repo docs and metadata: `README.md`, `CHANGELOG.md`, `version.json`, `PRIVACY.md`, `LICENSE`
- Runnable product: `vps.sh`, `vps_scripts.sh`, `scripts/**`, `lib/common_functions.sh`
- No customer testimonials, case studies, or marketing site copy on hand — do not fabricate them

## Product Principles

1. Prefer modular first-party scripts and the modern launcher over expanding the legacy entry.
2. Safety and idempotency beat cleverness: validate input, avoid reckless `eval`, prefer temp downloads and clear confirmations for third-party code.
3. Terminal UX is product UX: Chinese copy, responsive width, and menu logic should stay clear under real SSH sessions.
4. Ship only what the compatibility matrix and tests can stand behind; mark or demote weak/outdated tools rather than silently over-claiming.
5. Keep operator trust: document remote/third-party exposure and do not invent proof the repo does not have.
