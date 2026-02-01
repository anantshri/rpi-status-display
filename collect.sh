#!/bin/bash
# rpi-status collector — appends one CSV row of system metrics every invocation
# Intended to run via cron every 5 minutes.

set -euo pipefail

DATA_DIR="${RPI_STATUS_DATA_DIR:-/var/www/local/data}"
CSV_FILE="$DATA_DIR/current.csv"
HEADER="timestamp,cpu_percent,temp_c,fan_state,mem_total_mb,mem_used_mb,swap_total_mb,swap_used_mb,disk_total_gb,disk_used_gb,docker_disk_gb,load_1m,load_5m,load_15m,net_rx_bytes,net_tx_bytes,ts_rx_bytes,ts_tx_bytes,uptime_sec,docker_running,docker_total,tailscale_up,cloudflared_up"

mkdir -p "$DATA_DIR"

# Write header if file doesn't exist yet
if [ ! -f "$CSV_FILE" ]; then
    echo "$HEADER" > "$CSV_FILE"
fi

# --- Collect metrics ---

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# CPU usage: snapshot /proc/stat, sleep 2s, snapshot again, compute with awk for precision
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
sleep 2
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
cpu_percent=$(awk "BEGIN {
    idle = ($i2+$w2) - ($i1+$w1);
    total = ($u2+$n2+$s2+$i2+$w2+$q2+$sq2+$st2) - ($u1+$n1+$s1+$i1+$w1+$q1+$sq1+$st1);
    if (total > 0) printf \"%.1f\", 100 * (total - idle) / total;
    else print \"0.0\";
}")

# Temperature (millidegrees on RPi)
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$(awk "BEGIN {printf \"%.1f\", $raw_temp/1000}")
else
    temp_c="0.0"
fi

# Fan state
if [ -f /sys/class/thermal/cooling_device0/cur_state ]; then
    fan_state=$(cat /sys/class/thermal/cooling_device0/cur_state)
else
    fan_state=0
fi

# Memory (MB)
read -r mem_total mem_used <<< $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%d %d", t/1024, (t-a)/1024}' /proc/meminfo)

# Swap (MB)
read -r swap_total swap_used <<< $(awk '/^SwapTotal:/{t=$2} /^SwapFree:/{f=$2} END{printf "%d %d", t/1024, (t-f)/1024}' /proc/meminfo)

# Disk usage for root partition
read -r disk_total disk_used <<< $(df -BG / | awk 'NR==2{gsub("G",""); printf "%s %s", $2, $3}')

# Docker disk usage (images + containers + volumes, in GB)
if command -v docker &>/dev/null; then
    docker_disk_gb=$(docker system df --format '{{.Size}}' 2>/dev/null | while read -r line; do
        num=$(echo "$line" | sed 's/[^0-9.]//g')
        unit=$(echo "$line" | sed 's/[0-9. ]//g' | tr '[:lower:]' '[:upper:]')
        case "$unit" in
            GB|G) echo "$num" ;;
            MB|M) echo "$num 1024" | awk '{printf "%.4f", $1/$2}' ;;
            KB|K|KIB) echo "$num 1048576" | awk '{printf "%.4f", $1/$2}' ;;
            TB|T) echo "$num 1024" | awk '{printf "%.4f", $1*$2}' ;;
            *) echo "0" ;;
        esac
    done | awk '{t+=$1} END{printf "%.1f", t}')
    [ -z "$docker_disk_gb" ] && docker_disk_gb="0.0"
else
    docker_disk_gb="0.0"
fi

# Load averages
read -r load_1m load_5m load_15m _ < /proc/loadavg

# Network I/O (bytes) — primary interface (first non-lo default route interface)
net_iface=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
if [ -n "$net_iface" ] && [ -d "/sys/class/net/$net_iface" ]; then
    net_rx_bytes=$(cat "/sys/class/net/$net_iface/statistics/rx_bytes")
    net_tx_bytes=$(cat "/sys/class/net/$net_iface/statistics/tx_bytes")
else
    net_rx_bytes=0
    net_tx_bytes=0
fi

# Tailscale network I/O
if [ -d /sys/class/net/tailscale0 ]; then
    ts_rx_bytes=$(cat /sys/class/net/tailscale0/statistics/rx_bytes)
    ts_tx_bytes=$(cat /sys/class/net/tailscale0/statistics/tx_bytes)
else
    ts_rx_bytes=0
    ts_tx_bytes=0
fi

# Uptime (seconds)
uptime_sec=$(awk '{printf "%d", $1}' /proc/uptime)

# Docker containers (running / total)
if command -v docker &>/dev/null; then
    docker_running=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    docker_total=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
else
    docker_running=0
    docker_total=0
fi

# Tailscale status (1=connected, 0=not)
if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    tailscale_up=1
else
    tailscale_up=0
fi

# Cloudflared status (1=running, 0=not)
if pgrep -x cloudflared &>/dev/null; then
    cloudflared_up=1
else
    cloudflared_up=0
fi

# --- Append ---
echo "$timestamp,$cpu_percent,$temp_c,$fan_state,$mem_total,$mem_used,$swap_total,$swap_used,$disk_total,$disk_used,$docker_disk_gb,$load_1m,$load_5m,$load_15m,$net_rx_bytes,$net_tx_bytes,$ts_rx_bytes,$ts_tx_bytes,$uptime_sec,$docker_running,$docker_total,$tailscale_up,$cloudflared_up" >> "$CSV_FILE"
