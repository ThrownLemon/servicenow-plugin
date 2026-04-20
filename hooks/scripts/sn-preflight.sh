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

# Tokenize the command with awk — BSD sed on macOS doesn't grok `\s` or
# `\+`. awk splits on whitespace and is portable across Linux/macOS.
read -r _domain _subcommand _arg3 <<EOF
$(echo "$command" | awk '{
  for (i = 1; i <= NF; i++) if ($i == "servicenow-cli") { print $(i+1), $(i+2), $(i+3); exit }
}')
EOF

# Check for write verbs (create, update, add-*, delete, order, post, put,
# patch, deploy). Skip read-only verbs.
WRITE_VERBS="^(create|update|add-|delete|order|post|put|patch|deploy)"
if ! echo "${_subcommand:-}" | grep -qE "$WRITE_VERBS"; then
  exit 0
fi

# Map CLI domain+subcommand to ServiceNow table
table=""
case "${_domain}:${_subcommand}" in
  catalog:create)                 table="sc_cat_item" ;;
  catalog:add-variable)           table="item_option_new" ;;
  catalog:add-choice)             table="question_choice" ;;
  catalog:add-ui-policy)          table="catalog_ui_policy" ;;
  catalog:add-ui-policy-action)   table="catalog_ui_policy_action" ;;
  catalog:add-client-script)      table="catalog_script_client" ;;
  catalog:create-category)        table="sc_category" ;;
  report:create)                  table="sys_report" ;;
  incident:create)                table="incident" ;;
  change:create)                  table="change_request" ;;
  table:create)                   table="${_arg3:-}" ;;
esac

# Fallback: treat the domain token as the table name
if [ -z "$table" ] && [ -n "${_domain:-}" ]; then
  table="${_domain}"
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

# Portable timeout wrapper — macOS doesn't ship with `timeout`.
# Prefer GNU `timeout`, fall back to `gtimeout` (homebrew coreutils),
# fall back to perl's alarm, fall back to no timeout (local FTS5 query
# is fast; hooks.json already imposes a 10s ceiling).
run_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout &>/dev/null; then
    timeout "$secs" "$@"
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$secs" "$@"
  elif command -v perl &>/dev/null; then
    perl -e 'alarm shift @ARGV; exec @ARGV' "$secs" "$@"
  else
    "$@"
  fi
}

# Query snow-docs — local FTS5 lookup, should complete in ms
docs=$(run_with_timeout 5 snow-docs api "$table" --raw 2>/dev/null | head -40) || true

# Map tables to the plugin skill reference that covers their gotchas
# (admin tables like sys_report aren't in the developer portal index,
# so we point Claude at local references instead).
skill_ref=""
case "$table" in
  sys_report)
    skill_ref="servicenow-plugin/skills/report-builder/references/report-types.md + pitfalls.md"
    ;;
  sc_cat_item|item_option_new|question_choice|catalog_ui_policy|catalog_ui_policy_action|catalog_script_client|sc_category|sc_catalog)
    skill_ref="servicenow-plugin/skills/catalog-builder/references/dependency-chain.md + variable-type-mapping.md"
    ;;
esac

# Record in cache so we only print this once per table per session
echo "$table" >> "$CACHE_FILE"
chmod 600 "$CACHE_FILE" 2>/dev/null || true

# Output the preflight hint. Always emit something actionable, even when
# snow-docs has no usable content — point Claude at the local skill refs.
if [ -n "$docs" ]; then
  cat <<HINT
[snow-docs preflight] About to write to ${table}. Dev-portal docs excerpt:
---
${docs}
---
Run \`snow-docs api ${table}\` or \`snow-docs ask "<question>"\` for more.
HINT
else
  cat <<HINT
[snow-docs preflight] About to write to ${table}. Dev-portal docs have no
direct entry for this admin table. Consult local skill references instead.
HINT
fi

if [ -n "$skill_ref" ]; then
  cat <<HINT
Also check: \$CLAUDE_PLUGIN_ROOT/${skill_ref}
— these encode field-name gotchas and failure signatures discovered in
production that the developer portal does not document.
HINT
fi

exit 0
