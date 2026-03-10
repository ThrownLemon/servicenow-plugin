---
name: report-builder
description: This skill should be used when the user asks to "create a report", "build a report", "make a chart", "report-builder", "show me a dashboard chart", "visualize data", or mentions creating ServiceNow reports, charts, or data visualizations. Converts natural language descriptions into ServiceNow reports with browser verification.
---

# Report Builder

Convert natural language descriptions into ServiceNow reports with pre-flight data validation and Playwright verification.

## Workflow: Research → Plan → Execute → Verify

### 1. Research

```bash
snow-docs ask "report types and configuration" --raw --max-tokens 2000
snow-docs api "sys_report" --raw
```

### 2. Parse User Intent

Map natural language to report configuration. See `references/report-types.md` for common patterns.

Extract:
- **table**: Which ServiceNow table to report on
- **filter**: Encoded query to filter records
- **type**: bar, pie, line, list, etc.
- **field**: Field to group/aggregate by
- **aggregate**: COUNT, SUM, AVG, MIN, MAX
- **trend_field** + **trend_interval**: For time-series charts

Present the parsed configuration to the user for confirmation before creating.

### 3. Pre-flight Data Check

Verify the filter returns data before creating the report:

```bash
servicenow-cli aggregate count <table> --query "<filter>"
```

If zero rows: warn the user and suggest adjusting the filter. Do not create an empty report.

### 4. Validate Required Fields

Check `references/report-types.md` for the required fields per report type. If any are missing, ask the user.

### 5. Execute

Write the report payload to a temp file for shell safety:

```bash
# Write payload
cat > /tmp/sn-report-payload-XXXXX.json << 'EOF'
{
  "title": "<report_title>",
  "table": "<table>",
  "type": "<type>",
  "field": "<field>",
  "aggregate": "<aggregate>",
  "filter": "<encoded_query>"
}
EOF
chmod 600 /tmp/sn-report-payload-XXXXX.json

# Create report
servicenow-cli report create --data "$(cat /tmp/sn-report-payload-XXXXX.json)"

# Cleanup
rm -f /tmp/sn-report-payload-XXXXX.json
```

After each successful create/update operation, log it:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sn-audit.sh "report_create" "sys_report" "<sys_id>"
```

### 6. Verify with Playwright

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sn-verify.sh \
  --url "https://<instance>.service-now.com/nav_to.do?uri=sys_report_template.do?sys_id=<report_sys_id>&jvar_report_page=true" \
  --output "/tmp/sn-verify-report-<sys_id>-1.png" \
  --check-console
```

Check:
- [ ] Chart renders (not blank/empty)
- [ ] Correct chart type displayed
- [ ] Data appears consistent with aggregate pre-check
- [ ] Title and labels match

Fix loop: max 3 iterations.

## Additional Resources

### Reference Files

- **`references/report-types.md`** — Required fields per report type, aggregate values, intent mapping
