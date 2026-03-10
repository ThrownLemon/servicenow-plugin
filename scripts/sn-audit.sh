#!/bin/bash
# Audit logging helper
# Usage: bash sn-audit.sh <operation> <table> <sys_id> [extra_context]
#
# Logs to ~/.servicenow-cli/audit.log (0600 permissions, 10MB max with rotation)

set -euo pipefail

OPERATION="${1:-unknown}"
TABLE="${2:-unknown}"
SYS_ID="${3:-none}"
EXTRA="${4:-}"

LOG_DIR="$HOME/.servicenow-cli"
LOG_FILE="$LOG_DIR/audit.log"
MAX_SIZE=$((10 * 1024 * 1024))  # 10MB

mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR" 2>/dev/null || true

# Rotate if over max size
if [ -f "$LOG_FILE" ]; then
  FILE_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
    mv "$LOG_FILE" "${LOG_FILE}.1"
  fi
fi

# Get instance name
INSTANCE=$(servicenow-cli info --json 2>/dev/null | jq -r '.instance // "unknown"' 2>/dev/null) || INSTANCE="unknown"

# Append log line
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "${TIMESTAMP} instance=${INSTANCE} op=${OPERATION} table=${TABLE} sys_id=${SYS_ID} ${EXTRA}" >> "$LOG_FILE"
chmod 600 "$LOG_FILE" 2>/dev/null || true
