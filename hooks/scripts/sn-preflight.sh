#!/bin/bash
# PreToolUse hook: auto-query snow-docs before ServiceNow write commands
# Reads JSON from stdin. Exits 0 with no output for non-matching commands.

set -euo pipefail

# Fail open if jq not available
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Read stdin JSON
input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

# Exit early if no command or not servicenow-cli
if [ -z "$command" ]; then
  exit 0
fi
if ! echo "$command" | grep -q 'servicenow-cli'; then
  exit 0
fi
# Prevent recursion — skip if snow-docs is in the command
if echo "$command" | grep -q 'snow-docs'; then
  exit 0
fi

# Extract the subcommand (second token after servicenow-cli) and check for write verbs
subcommand=$(echo "$command" | sed -n 's/.*servicenow-cli\s\+[a-z_-]*\s\+\([a-z_-]*\).*/\1/p')
WRITE_VERBS="^(create|update|add-|delete|order|post|put|patch|deploy)"
if ! echo "$subcommand" | grep -qE "$WRITE_VERBS"; then
  exit 0
fi

# Map CLI domain+subcommand to ServiceNow table
table=""
if echo "$command" | grep -qE 'catalog\s+create\b'; then
  table="sc_cat_item"
elif echo "$command" | grep -qE 'catalog\s+add-variable\b'; then
  table="item_option_new"
elif echo "$command" | grep -qE 'catalog\s+add-choice\b'; then
  table="question_choice"
elif echo "$command" | grep -qE 'catalog\s+add-ui-policy\b'; then
  table="catalog_ui_policy"
elif echo "$command" | grep -qE 'catalog\s+add-ui-policy-action\b'; then
  table="catalog_ui_policy_action"
elif echo "$command" | grep -qE 'catalog\s+add-client-script\b'; then
  table="catalog_script_client"
elif echo "$command" | grep -qE 'catalog\s+create-category\b'; then
  table="sc_category"
elif echo "$command" | grep -qE 'report\s+create\b'; then
  table="sys_report"
elif echo "$command" | grep -qE 'table\s+create\s+'; then
  # Extract table name from: servicenow-cli table create <table>
  table=$(echo "$command" | sed -n 's/.*table\s\+create\s\+\([a-z_][a-z0-9_]*\).*/\1/p')
elif echo "$command" | grep -qE 'incident\s+create\b'; then
  table="incident"
elif echo "$command" | grep -qE 'change\s+create\b'; then
  table="change_request"
fi

# If no table identified, try domain name as table
if [ -z "$table" ]; then
  domain=$(echo "$command" | sed -n 's/.*servicenow-cli\s\+\([a-z_-]*\).*/\1/p')
  if [ -n "$domain" ]; then
    table="$domain"
  fi
fi

# Exit if we still can't determine the table
if [ -z "$table" ]; then
  exit 0
fi

# Check cache — skip if already looked up this session
session_id=$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null)
CACHE_DIR="$HOME/.servicenow-cli"
CACHE_FILE="$CACHE_DIR/preflight-cache-${session_id}"

# Ensure cache dir exists with proper permissions
mkdir -p "$CACHE_DIR"
chmod 700 "$CACHE_DIR" 2>/dev/null || true

if [ -f "$CACHE_FILE" ] && grep -q "^${table}$" "$CACHE_FILE" 2>/dev/null; then
  exit 0
fi

# Query snow-docs with 5-second timeout
docs=$(timeout 5 snow-docs api "$table" --raw --limit 3 2>/dev/null) || true

if [ -z "$docs" ]; then
  exit 0
fi

# Record in cache
echo "$table" >> "$CACHE_FILE"
chmod 600 "$CACHE_FILE" 2>/dev/null || true

# Output concise field summary for Claude
echo "📚 snow-docs: Key fields for ${table}:"
echo "$docs" | head -30

exit 0
