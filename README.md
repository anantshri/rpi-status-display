# rpi-status

A lightweight Raspberry Pi system monitor that collects metrics every 5 minutes and serves a static dashboard via nginx. All visualization is client-side — no databases, no background services, just a shell script and a single HTML file.

![Dashboard](https://img.shields.io/badge/stack-shell%20%2B%20chart.js-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

## What it monitors

| Category | Metrics |
|---|---|
| **System** | CPU usage, temperature, fan state, load average, uptime |
| **Memory** | RAM (used/total), swap (used/total) |
| **Storage** | Root disk (used/total), Docker disk usage |
| **Network** | Primary interface I/O, Tailscale I/O |
| **Services** | Docker containers (running/total), Tailscale status, Cloudflared tunnel status |

## How it works

1. A cron job runs `collect.sh` every 5 minutes, appending one CSV row to `data/current.csv`
2. `index.html` fetches the CSV and renders charts using Chart.js (loaded from CDN)
3. A nightly cron job runs `rotate.sh` to keep the main file to 24 hours and archive older data into daily, weekly, and monthly compressed files
4. nginx (or any static file server) serves the webroot

No server-side processing. No JavaScript build step. The Pi just writes a CSV line and nginx serves files.

## Installation

```bash
git clone https://github.com/anantshri/rpi-status.git
cd rpi-status
sudo bash install.sh
```

This will:
- Copy scripts to `/opt/rpi-status/`
- Copy the dashboard to `/var/www/local/`
- Set up cron jobs for collection (every 5 min) and rotation (midnight)

Make sure the data directory is writable:
```bash
sudo mkdir -p /var/www/local/data
sudo chown $(whoami):$(whoami) /var/www/local/data
```

### Nginx (optional)

If you want the included nginx config:
```bash
sudo bash install.sh --nginx
```

Otherwise, point your existing nginx/web server at `/var/www/local/`.

### Testing locally

Create a sample CSV and serve:
```bash
mkdir -p webroot/data
# copy or create a current.csv in webroot/data/
python3 -m http.server 8000 --directory webroot
```

## Data format

CSV with 23 columns:
```
timestamp,cpu_percent,temp_c,fan_state,mem_total_mb,mem_used_mb,swap_total_mb,swap_used_mb,
disk_total_gb,disk_used_gb,docker_disk_gb,load_1m,load_5m,load_15m,net_rx_bytes,net_tx_bytes,
ts_rx_bytes,ts_tx_bytes,uptime_sec,docker_running,docker_total,tailscale_up,cloudflared_up
```

Network I/O columns are cumulative byte counters; the frontend converts them to per-interval deltas.

## Data retention

| Period | Format | Location |
|---|---|---|
| Last 24 hours | `current.csv` | `data/` |
| Daily archives | `YYYY-MM-DD.csv` | `data/archive/` |
| Weekly (>7 days old) | `week-YYYY-Www.tar.gz` | `data/archive/` |
| Monthly (>30 days old) | `month-YYYY-MM.tar.gz` | `data/archive/` |

## Requirements

- Raspberry Pi (tested on Pi 5, should work on Pi 3/4)
- Bash, awk, cron
- nginx or any static file server
- Docker (optional — metrics degrade gracefully if not installed)
- Tailscale (optional)
- Cloudflared (optional)

## License

[GPL-3.0](LICENSE)

## Support

If you find this useful, consider supporting the project:

- [GitHub Sponsors](https://github.com/sponsors/anantshri)
- [Buy Me a Coffee](https://buymeacoffee.com/anantshri)
