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

## Current Safety Direction

- Keep first-party module execution separate from third-party commands
- Prefer confirmation before running third-party one-liners
- Document network-touching behavior in script headers and repo docs
- Reduce opaque remote execution over time

## Operator Guidance

- Review scripts before running them on production systems
- Prefer running in a disposable test VPS before broad rollout
- Use minimal-privilege environments where possible
- Audit third-party endpoints before enabling them in automation
