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
- NextTrace (github.com/sjlleo/nexttrace)
- NodeLoc benchmark (abc.sd)
- Nodequality (run.NodeQuality.com)
- spiritLHLS ecs (gitlab.com/spiritysdx/za)
- Media unlock test (media.ispvps.com)
- Response time test (nodebench.mereith.com)
- SSH tool (github.com/eooce/ssh_tool)
- JCNF toolbox (github.com/Netflixxp/jcnf-box)
- KejiLion toolbox (kejilion.sh)
- BlueSkyXN toolbox (github.com/BlueSkyXN/SKY-BOX)
- Speedtest multi-line (github.com/i-abc/Speedtest)
- AutoTrace (github.com/Chennhaoo/Shell_Bash)
- Oversell check (github.com/uselibrary/memoryCheck)
- NodeScriptKit (sh.nodeseek.com)

Proxy tools menu:
- sing-box scripts (github.com/yonggekkk, github.com/fscarmen)
- x-ui / 3x-ui panels (gitlab.com/rwkgyg, github.com/mhsanaei, github.com/xeefei)
- Hysteria2 (github.com/everett7623/hy2)

Other tools menu:
- Komari Monitor (github.com/komari-monitor/komari)
- Cloudflare WARP (gitlab.com/fscarmen/warp)
- DD System Reinstall (github.com/leitbogioro/Tools)
- acme.sh (get.acme.sh)
- oh-my-zsh (github.com/ohmyzsh/ohmyzsh)
- Uptime Kuma (hub.docker.com louislam/uptime-kuma)
- Tailscale (tailscale.com/install.sh)
- FRP client (github.com/funnyzak/frpc)
- Cloudflare Tunnel / cloudflared (github.com/cloudflare/cloudflared)
- FileBrowser (github.com/filebrowser/get)
- Nezha cleaner (github.com/everett7623/Nezha-cleaner)

Service install menu (third-party items):
- Caddy (caddyserver.com)
- Portainer CE (hub.docker.com portainer/portainer-ce)

## Current Safety Direction

- Keep first-party module execution separate from third-party commands
- Prefer confirmation before running third-party one-liners
- Document network-touching behavior in script headers and repo docs
- Reduce opaque remote execution over time

## Usage Statistics

The launcher (`vps.sh`) sends a single lightweight request to `hits.seeyoufarm.com` on each run to count total script executions. This request:
- Only increments a public counter badge
- Does NOT collect IP addresses, system info, or any user data
- Runs asynchronously in the background and does not affect script execution
- Can be verified at: https://hits.seeyoufarm.com (open-source service)

## Operator Guidance

- Review scripts before running them on production systems
- Prefer running in a disposable test VPS before broad rollout
- Use minimal-privilege environments where possible
- Audit third-party endpoints before enabling them in automation
