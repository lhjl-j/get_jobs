#!/usr/bin/env bash
set -euo pipefail

# daily-run.sh
# Purpose: trigger platform delivery start endpoints on the backend at 10:00 daily.
# Usage:
#   - Configure environment variable API_BASE_URL (defaults to http://localhost:8888)
#   - Optionally set PLATFORMS (comma-separated, defaults to boss,liepin,51job,zhilian)
#   - Run manually or from cron/systemd

LOG_DIR=${LOG_DIR:-/var/log/get_jobs}
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/daily-run-$(date +%F).log"

API_BASE="${API_BASE_URL:-http://localhost:8888}"
PLATFORMS="${PLATFORMS:-boss,liepin,51job,zhilian}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting get_jobs daily-run (API_BASE=$API_BASE)" >> "$LOG_FILE"

# Health check (try /api/health then /actuator/health)
if curl -sSf "$API_BASE/api/health" >/dev/null 2>&1; then
  echo "[$(date)] Health check OK (/api/health)" >> "$LOG_FILE"
elif curl -sSf "$API_BASE/actuator/health" >/dev/null 2>&1; then
  echo "[$(date)] Health check OK (/actuator/health)" >> "$LOG_FILE"
else
  echo "[$(date)] Health check failed, aborting" >> "$LOG_FILE"
  exit 1
fi

IFS=',' read -ra PARR <<< "$PLATFORMS"
for p in "${PARR[@]}"; do
  platform=$(echo "$p" | xargs)
  if [ -z "$platform" ]; then
    continue
  fi
  endpoint="$API_BASE/api/$platform/start"
  echo "[$(date)] Triggering $platform -> $endpoint" >> "$LOG_FILE"
  # POST to start endpoint; capture response and HTTP code
  http_resp=$(curl -sS -w "HTTPSTATUS:%{http_code}" -X POST "$endpoint" -H "Content-Type: application/json" || true)
  http_body=$(echo "$http_resp" | sed -e 's/HTTPSTATUS:.*$//')
  http_status=$(echo "$http_resp" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  echo "[$(date)] $platform status=$http_status body=$http_body" >> "$LOG_FILE"
  # small pause between triggers to reduce burst
  sleep 2
done

# Optionally: notify via webhook if configured in DB and Bot enabled (use project's Bot.sendMessageByTime via API if available)
# You can extend this script to call a webhook here.

echo "[$(date '+%Y-%m-%d %H:%M:%S')] get_jobs daily-run finished" >> "$LOG_FILE"
