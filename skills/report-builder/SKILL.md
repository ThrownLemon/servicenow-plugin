---
name: report-builder
description: This skill should be used when the user asks to "create a report", "build a report", "make a chart", "report-builder", "show me a dashboard chart", "visualize data", or mentions creating ServiceNow reports, charts, or data visualizations. Converts natural language descriptions into ServiceNow reports with render verification.
---

# Report Builder

Convert natural language descriptions into ServiceNow reports with pre-flight data validation, correct `sys_report` field mapping, and Playwright-based render verification.

## Workflow: Research → Plan → Execute → Verify → Hand off

### 1. Research

```bash
snow-docs ask "report types and configuration" --raw --max-tokens 2000
snow-docs api "sys_report" --raw
```

Read `references/report-types.md` and `references/pitfalls.md` — these encode field-name gotchas that ServiceNow's docs don't call out.

### 2. Parse user intent

Extract:
- **table**: Which ServiceNow table to report on
- **filter**: Encoded query to narrow records (pre-flight this)
- **type**: One of the exact enum strings — `Vertical bar`, `Pie`, `Line`, `Pivot Table`, `List`, etc. (see `references/report-types.md`)
- **For bar/pie/donut**: `field` (group-by) + `aggregate`
- **For AVG/SUM bar**: `field` + `aggregate: "Average"|"Sum"` + `sumfield` (numeric field to aggregate)
- **For line/area trend**: `trend_field` (the date column) + `interval` (`Date`/`Week`/`Month`/`Quarter`/`Year`) + `aggregate`; leave `field` empty
- **For pivot**: `row` + `column` + `aggregate` (and `sumfield` for AVG/SUM pivots)
- **For list**: `filter` only

**Present the full parsed payload (including correct field names) to the user for confirmation before creating.**

### 3. Pre-flight data check

```bash
servicenow-cli aggregate count <table> --query "<filter>"
```

If zero rows: warn the user and suggest adjusting the filter. Do not create empty reports.

### 4. Wrap in an update set

```bash
servicenow-cli updateset create "Report: <short-name> - $(date +%s)" --description "built via /report-builder"
# extract sys_id from stdout JSON
servicenow-cli updateset set-current <update_set_sys_id>
```

Every write must land in an update set so the work is rollback-able.

### 5. Execute

Write the payload to a temp file for shell safety, then create:

```bash
cat > /tmp/sn-report-payload-XXXXX.json << 'EOF'
{
  "title": "<human-readable title>",
  "table": "<table>",
  "type": "<exact enum string, e.g. Pivot Table>",
  "filter": "<encoded_query>",
  "aggregate": "<Count|Sum|Average|Min|Max>",
  "field": "<group-by field, empty for trends>",
  "row": "<pivot row field or omit>",
  "column": "<pivot column field or omit>",
  "sumfield": "<numeric field for SUM/AVG, or omit>",
  "trend_field": "<date field for trends, or omit>",
  "interval": "<Date|Week|Month|Quarter|Year, or omit>"
}
EOF
chmod 600 /tmp/sn-report-payload-XXXXX.json

servicenow-cli report create --data "$(cat /tmp/sn-report-payload-XXXXX.json)" --json

rm -f /tmp/sn-report-payload-XXXXX.json
```

Capture the returned `sys_id`. Log the audit event:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sn-audit.sh "report_create" "sys_report" "<sys_id>"
```

### 6. Verify by rendering

**Do not trust create-success as "the report works".** The sys_report endpoint accepts unknown fields silently, so a broken payload still returns 201.

```bash
INSTANCE=$(servicenow-cli info --json | jq -r .instance)
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sn-verify.sh \
  --url "https://${INSTANCE}.service-now.com/nav_to.do?uri=sys_report_template.do%3Fjvar_report_id%3D<report_sys_id>" \
  --output "/tmp/sn-verify-report-<sys_id>.png" \
  --check-console
```

Then scan the screenshot (or `get_page_text` if available) for the failure signatures in `references/pitfalls.md`:

- "Cannot generate the report. To configure the report, select Row and Column values" → pivot missing `row`/`column`
- "Aggregation field is not specified for aggregate type AVG" → AVG/SUM missing `sumfield`
- "Published reports are disabled" → URL wrong (use the one above)
- "The page you are looking for could not be found" → URL encoding wrong
- Chart showing "per Year" when user asked for daily → `interval` missing or wrong value

**Fix loop:** on any failure signature, update the `sys_report` record via `servicenow-cli table update sys_report <sys_id> --data '{...}'` with the corrected fields, then re-run the verify step. Max 3 iterations; after that stop and report to user.

**Only claim success once the verify screenshot shows a rendered chart with no error banner.**

### 7. Hand off

Report to the user:

- Report title + `sys_id`
- Admin render URL (the one above — always works regardless of publish state)
- Update set name + `sys_id` (for rollback)
- Verify screenshot path

If the user asked for a *dashboard* (multiple reports composed):
1. Create each report individually via steps 1–6
2. Create the dashboard container: `servicenow-cli dashboard create --data '{"name":"<name>","description":"…"}'` → returns `pa_dashboards` sys_id
3. **Tell the user they need to pin the reports manually:** open `/$pa_dashboard.do?sysparm_dashboard=<sys_id>` in their browser, click the `+` icon, choose category "Reports", filter by name, click each report and hit Add. ~30 seconds per report. Do not attempt REST-based widget composition — see `references/pitfalls.md` #7 for why.

## Additional Resources

- **`references/report-types.md`** — correct field names, required fields per report type, exact enum strings
- **`references/pitfalls.md`** — known failure modes, their error signatures, and fixes

## Failure modes to never repeat

1. **Never** use field names `group_after`, `value_field`, or `trend_interval` — ServiceNow silently ignores them. Use `column`, `sumfield`, `interval`.
2. **Never** use enum values in the wrong case — `"day"` doesn't work, `"Date"` does; `"bar"` doesn't, `"Vertical bar"` does.
3. **Never** claim success without a verify render check — silent-ignore of fields means create-success is not sufficient proof.
4. **Never** try to pin widgets to `pa_dashboards` via REST — direct the user to the UI.
