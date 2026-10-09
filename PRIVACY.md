# Privacy

## Overview

This repository is a VPS operations toolkit. Many scripts require network access and may call third-party endpoints in order to:

- Download installer content
- Fetch remote helper scripts
- Check version metadata
- Measure network quality
- Query public IP information
- Install packages from OS or vendor repositories

## Data Exposure Considerations

Running these scripts may expose:

- The server public IP address
- Operating system and package-manager fingerprints
- Network route and latency characteristics
- Installed software state during package operations

## Notable Remote Sources

- GitHub raw content for first-party modules and metadata
- Linux distribution package repositories
- Third-party benchmarking, testing, and installer endpoints referenced by specific scripts

### Third-Party Tools Referenced in Menus

Community scripts menu:
- YABS (github.com/masonr/yet-another-bench-script)
- Bench.sh (bench.sh)
- XY IP/Network Check (Check.Place)
- NextTrace (github.com/nxtrace/NTrace-core)
- NodeLoc benchmark (abc.sd)
- Nodequality (run.NodeQuality.com)
- spiritLHLS ecs (gitlab.com/spiritysdx/za)
- Media unlock test (media.ispvps.com)
- Response time test (nodebench.mereith.com)
- SSH tool (github.com/eooce/ssh_tool)
- KejiLion toolbox (kejilion.sh)
- AutoTrace (github.com/Chennhaoo/Shell_Bash)
- Oversell check (github.com/uselibrary/memoryCheck)
- NodeScriptKit (sh.nodeseek.com)
- Legacy, listed last: JCNF toolbox (github.com/Netflixxp/jcnf-box), BlueSkyXN toolbox (github.com/BlueSkyXN/SKY-BOX), Speedtest multi-line (github.com/i-abc/Speedtest, archived)

Proxy tools menu:
- Proxy panels: 3x-ui (github.com/mhsanaei), S-UI (github.com/alireza0), X-Panel (github.com/xeefei), x-ui-yg (github.com/yonggekkk)
- sing-box scripts (github.com/yonggekkk, github.com/fscarmen)
- v2ray-agent (github.com/mack-a)
- Hysteria2 (github.com/everett7623/hy2; official installer get.hy2.sh from apernet/hysteria)
- Xray-core official installer (github.com/XTLS/Xray-install)

Other tools menu:
- Komari Monitor (github.com/komari-monitor/komari)
- Beszel hub (get.beszel.dev, github.com/henrygd/beszel)
- Uptime Kuma (hub.docker.com louislam/uptime-kuma:2)
- Tailscale (tailscale.com/install.sh)
- Cloudflare Tunnel / cloudflared (github.com/cloudflare/cloudflared)
- Cloudflare WARP (gitlab.com/fscarmen/warp)
- acme.sh (get.acme.sh)
- oh-my-zsh (github.com/ohmyzsh/ohmyzsh)
- DD System Reinstall (github.com/leitbogioro/Tools)
- Nezha cleaner (github.com/everett7623/Nezha-cleaner)
- FileBrowser (github.com/filebrowser/get; upstream archived, listed last)

The first-party FRP module (`scripts/other_tools/frp.sh`) downloads official releases from github.com/fatedier/frp and verifies them against the published `frp_sha256_checksums.txt`. The first-party Nezha module downloads from github.com/nezhahq/agent and verifies `checksums.txt`.

The first-party modern CLI toolkit uses only the Linux distribution repositories already configured on the host. It does not add a third-party repository or execute a downloaded installer.

Service install menu (third-party items):
- Caddy (caddyserver.com)
- Coolify (cdn.coollabs.io/coolify/install.sh)
- Dokploy (dokploy.com/install.sh)
- Portainer CE (hub.docker.com portainer/portainer-ce)
- Dockge (github.com/louislam/dockge compose.yaml)
- Nginx Proxy Manager (hub.docker.com jc21/nginx-proxy-manager)

## Current Safety Direction

- Keep first-party module execution separate from third-party commands
- Prefer confirmation before running third-party one-liners
- Document network-touching behavior in script headers and repo docs
- Reduce opaque remote execution over time

## Usage Statistics

The launcher does not send usage-counter or analytics requests. Network access occurs only for launcher/module downloads, update metadata, user-selected tools, and diagnostics described above.

## Operator Guidance

- Review scripts before running them on production systems
- Prefer running in a disposable test VPS before broad rollout
- Use minimal-privilege environments where possible
- Audit third-party endpoints before enabling them in automation
