#!/bin/bash
# SessionStart hook: check prerequisites and purge stale sessions
# Non-blocking — always exits 0, outputs warnings only

set -euo pipefail

warnings=""

# Check servicenow-cli
if ! command -v servicenow-cli &>/dev/null; then
  warnings="${warnings}⚠ servicenow-cli not found. Install it and run: servicenow-cli config\n"
elif ! servicenow-cli info --json 2>/dev/null | grep -qE '"configured"[[:space:]]*:[[:space:]]*true'; then
  warnings="${warnings}⚠ servicenow-cli not configured. Run: servicenow-cli config\n"
fi

# Check snow-docs
if ! command -v snow-docs &>/dev/null; then
  warnings="${warnings}⚠ snow-docs not found. Install it for documentation lookups.\n"
fi

# Check Playwright
if ! bunx playwright --version &>/dev/null 2>&1; then
  warnings="${warnings}⚠ Playwright not installed. Run: bunx playwright install chromium\n"
fi

# Purge stale Playwright sessions (older than 15 minutes)
SESSION_DIR="$HOME/.servicenow-cli/sessions"
if [ -d "$SESSION_DIR" ]; then
  find "$SESSION_DIR" -name "*.session.json" -mmin +15 -delete 2>/dev/null || true
fi

# Output warnings if any
if [ -n "$warnings" ]; then
  printf "%b" "$warnings"
  echo "Run /sn-setup to fix missing prerequisites."
fi

exit 0
