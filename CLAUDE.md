# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A lightweight Raspberry Pi system monitor that collects metrics (CPU usage, temperature, memory, disk, load average) on a 5-minute cron interval and writes CSV data to static files served by nginx. All visualization is client-side using Chart.js.

## Architecture

- **Collector** (`collect.sh`): Shell script reading from `/proc/stat`, `/proc/meminfo`, `/sys/class/thermal/`, `df`, `/proc/loadavg`. Appends one CSV row per run to `data/current.csv`.
- **Frontend** (`webroot/index.html`): Single HTML file using Chart.js (CDN) + chartjs-adapter-date-fns. Fetches `data/current.csv`, parses it, renders 5 charts. Auto-refreshes every 5 minutes.
- **Rotation** (`rotate.sh`): Run daily at midnight. Trims `current.csv` to last 24h, archives older data into daily CSVs, then weekly `.tar.gz`, then monthly `.tar.gz`.
- **Deployment**: `install.sh` copies scripts to `/opt/rpi-status`, webroot to `/var/www/local`, sets up cron entries, configures nginx.

## Key Paths

- `RPI_STATUS_DATA_DIR` env var overrides default data dir (`/var/www/local/data`)
- CSV format: `timestamp,cpu_percent,temp_c,fan_state,mem_total_mb,mem_used_mb,disk_total_gb,disk_used_gb,load_1m,load_5m,load_15m`
- Archives go to `$DATA_DIR/archive/` (daily CSVs, `week-YYYY-Www.tar.gz`, `month-YYYY-MM.tar.gz`)

## Testing Locally

To test the frontend without a Pi, create a sample `webroot/data/current.csv` with fake data and serve with `python3 -m http.server 8000 --directory webroot`.

## Self-Maintenance

This file serves as persistent memory across Claude Code sessions. **Always update this file** when:
- New build commands, tools, or dependencies are added
- Architectural decisions are made or changed
- Project structure changes significantly
- New conventions or patterns are established
- Bugs or gotchas are discovered that future sessions should know about
