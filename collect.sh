#!/bin/bash
# rpi-status collector — appends one CSV row of system metrics every invocation
# Intended to run via cron every 5 minutes.

set -euo pipefail

DATA_DIR="${RPI_STATUS_DATA_DIR:-/var/www/local/data}"
CSV_FILE="$DATA_DIR/current.csv"
HEADER="timestamp,cpu_percent,temp_c,mem_total_mb,mem_used_mb,disk_total_gb,disk_used_gb,load_1m,load_5m,load_15m"

mkdir -p "$DATA_DIR"

# Write header if file doesn't exist yet
if [ ! -f "$CSV_FILE" ]; then
    echo "$HEADER" > "$CSV_FILE"
fi

# --- Collect metrics ---

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# CPU usage: average idle from /proc/stat snapshot (1-second sample)
read -r _ u1 n1 s1 i1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 _ < /proc/stat
idle=$(( i2 - i1 ))
total=$(( (u2+n2+s2+i2) - (u1+n1+s1+i1) ))
if [ "$total" -gt 0 ]; then
    cpu_percent=$(( 100 * (total - idle) / total ))
else
    cpu_percent=0
fi

# Temperature (millidegrees on RPi)
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    raw_temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    temp_c=$(awk "BEGIN {printf \"%.1f\", $raw_temp/1000}")
else
    temp_c="0.0"
fi

# Memory (MB)
read -r mem_total mem_available <<< $(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{printf "%d %d", t/1024, (t-a)/1024}' /proc/meminfo)
mem_used=$mem_available  # variable is actually "used" from the awk

# Disk usage for root partition
read -r disk_total disk_used <<< $(df -BG / | awk 'NR==2{gsub("G",""); printf "%s %s", $2, $3}')

# Load averages
read -r load_1m load_5m load_15m _ < /proc/loadavg

# --- Append ---
echo "$timestamp,$cpu_percent,$temp_c,$mem_total,$mem_used,$disk_total,$disk_used,$load_1m,$load_5m,$load_15m" >> "$CSV_FILE"
