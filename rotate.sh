#!/bin/bash
# rpi-status rotation — keeps last 24h in current.csv, archives the rest.
# Run daily via cron (e.g. at midnight).

set -euo pipefail

DATA_DIR="${RPI_STATUS_DATA_DIR:-/var/www/local/data}"
CSV_FILE="$DATA_DIR/current.csv"
ARCHIVE_DIR="$DATA_DIR/archive"

mkdir -p "$ARCHIVE_DIR"

[ -f "$CSV_FILE" ] || exit 0

HEADER=$(head -1 "$CSV_FILE")
CUTOFF=$(date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ")

# Split: lines newer than cutoff stay, older ones go to a daily archive
YESTERDAY=$(date -u -d 'yesterday' +"%Y-%m-%d" 2>/dev/null || date -u -v-1d +"%Y-%m-%d")
DAILY_FILE="$ARCHIVE_DIR/$YESTERDAY.csv"

{
  echo "$HEADER"
  # Old lines go to daily file
  awk -F, -v cutoff="$CUTOFF" 'NR>1 && $1 < cutoff' "$CSV_FILE"
} > "$DAILY_FILE.tmp"

# Only keep daily file if it has data rows
if [ "$(wc -l < "$DAILY_FILE.tmp")" -gt 1 ]; then
    mv "$DAILY_FILE.tmp" "$DAILY_FILE"
else
    rm -f "$DAILY_FILE.tmp"
fi

# Rewrite current.csv with only recent entries
{
  echo "$HEADER"
  awk -F, -v cutoff="$CUTOFF" 'NR>1 && $1 >= cutoff' "$CSV_FILE"
} > "$CSV_FILE.tmp"
mv "$CSV_FILE.tmp" "$CSV_FILE"

# --- Weekly aggregation: compress daily files older than 7 days into weekly tarballs ---
find "$ARCHIVE_DIR" -maxdepth 1 -name '*.csv' -mtime +7 | sort | while read -r f; do
    fname=$(basename "$f" .csv)
    # Determine ISO week: YYYY-Www
    week=$(date -d "$fname" +"%G-W%V" 2>/dev/null || date -jf "%Y-%m-%d" "$fname" +"%G-W%V" 2>/dev/null || echo "")
    [ -z "$week" ] && continue
    weektar="$ARCHIVE_DIR/week-$week.tar.gz"
    if [ -f "$weektar" ]; then
        # Append to existing tarball by extracting, adding, recompressing
        tmpdir=$(mktemp -d)
        tar -xzf "$weektar" -C "$tmpdir"
        cp "$f" "$tmpdir/"
        tar -czf "$weektar" -C "$tmpdir" .
        rm -rf "$tmpdir"
    else
        tar -czf "$weektar" -C "$ARCHIVE_DIR" "$(basename "$f")"
    fi
    rm -f "$f"
done

# --- Monthly aggregation: compress weekly tarballs older than 30 days ---
find "$ARCHIVE_DIR" -maxdepth 1 -name 'week-*.tar.gz' -mtime +30 | sort | while read -r f; do
    fname=$(basename "$f")
    # Extract year-month from week filename (week-2025-W03.tar.gz -> 2025-01 approx)
    year=$(echo "$fname" | grep -oP '\d{4}' | head -1)
    monthtar="$ARCHIVE_DIR/month-$year-$(date -d "$(stat -c %Y "$f" 2>/dev/null | xargs -I{} date -d @{} +%m 2>/dev/null || stat -f %m "$f")" +%m 2>/dev/null || echo "00").tar.gz"
    # Simpler approach: group by file modification month
    mod_month=$(date -r "$f" +"%Y-%m" 2>/dev/null || stat -c %Y "$f" | xargs -I{} date -d @{} +"%Y-%m" 2>/dev/null || echo "")
    [ -z "$mod_month" ] && continue
    monthtar="$ARCHIVE_DIR/month-$mod_month.tar.gz"
    if [ -f "$monthtar" ]; then
        tmpdir=$(mktemp -d)
        tar -xzf "$monthtar" -C "$tmpdir"
        cp "$f" "$tmpdir/"
        tar -czf "$monthtar" -C "$tmpdir" .
        rm -rf "$tmpdir"
    else
        tar -czf "$monthtar" -C "$ARCHIVE_DIR" "$fname"
    fi
    rm -f "$f"
done
