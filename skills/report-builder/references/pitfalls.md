# Report Builder — Known Pitfalls & Workarounds

<!--
last-verified: 2026-04-20
verified-against: ac3ptyltddemo11 (Zurich family, Yokohama-equivalent API)

Each numbered pitfall below reflects a failure observed in production on
this instance. When adding new entries, include a reproduction command or
an error-text signature so future operators can match symptoms to fixes.
If any listed system property or error text is no longer returned by the
instance, mark the entry as superseded rather than deleting it — the fix
may still be needed on older instances.
-->


Failure modes observed in production and their fixes. Check against this list when a newly-created report doesn't render.

## 1. Silently ignored field names

**Symptom:** `servicenow-cli report create` returns 201 with a `sys_id`, but opening the report shows an error banner or an empty chart.

**Cause:** ServiceNow's `sys_report` REST endpoint accepts unknown JSON keys and ignores them without warning. A payload with `group_after`, `value_field`, or `trend_interval` creates a report missing those settings.

**Fix:** Use the canonical field names from `report-types.md`:
- `group_after` → `column`
- `value_field` → `sumfield`
- `trend_interval` → `interval`

## 2. Pivot "Cannot generate the report. To configure the report, select Row and Column values."

**Cause:** Pivot reports need both `row` and `column` set. Setting only `field` does not work for `type: "Pivot Table"`.

**Fix:**
```json
{"type":"Pivot Table","row":"<row_field>","column":"<col_field>","aggregate":"Count"}
```

## 3. AVG/SUM "Aggregation field is not specified for aggregate type AVG"

**Cause:** `aggregate: "Average"` requires `sumfield` (the numeric field to average). Just setting `field` groups but doesn't tell ServiceNow what to average.

**Fix:**
```json
{"type":"Vertical bar","field":"priority","aggregate":"Average","sumfield":"calendar_duration"}
```

## 4. Trend report shows "per Year" and renders empty

**Cause:** `interval` was not set, or was set to an invalid value like `"day"` instead of `"Date"`.

**Fix:**
- Leave `field` empty (a trend's x-axis is driven by `trend_field`)
- Set `trend_field` to the date column
- Set `interval` to one of: `Date`, `Week`, `Month`, `Quarter`, `Year`

## 5. "Published reports are disabled in the system" banner

**Cause:** The system property `glide.report.published_reports.enabled` is `false`. This blocks the public-friendly URL `/sys_report_display.do?sysparm_report_id=<id>` even for admins.

**Diagnose:**
```bash
servicenow-cli table list sys_properties --query "name=glide.report.published_reports.enabled" --fields name,value --json
```

**Fix (pick one):**
- **Preferred** — use the admin URL instead: `/nav_to.do?uri=sys_report_template.do%3Fjvar_report_id%3D<report_sys_id>` — this works for admins regardless of the publish setting and is what `sn-verify.sh` should target
- Flip the property if client-facing publish is desired (requires admin approval)

## 6. `is_published` REST update silently stays `false`

**Cause:** A business rule on `sys_report` protects `is_published` from direct REST updates. Only the UI's "Publish" button can flip it.

**Fix:** Do not try to publish via REST. If publish is required, direct the user to click Publish in the report UI, or toggle `glide.report.published_reports.enabled` (see #5).

## 7. Dashboard pinning can't be done via REST reliably

**Cause:** Pinning a report widget to a `pa_dashboards` requires creating `pa_tabs` → `sys_grid_canvas` → `sys_grid_canvas_pane` → `sys_portal`/`pa_widgets` records with fragile schema that varies across releases. Attempts to build these via REST produce half-wired widgets that don't render.

**Fix:**
- Create the dashboard container via `servicenow-cli dashboard create`
- Output the dashboard URL: `/$pa_dashboard.do?sysparm_dashboard=<dashboard_sys_id>`
- **Direct the user to the dashboard in the browser, click the `+` (Add Widgets) button, change category to "Reports", filter by name, and Add each report.** 30–60 seconds per report.
- Do not pretend the skill will compose the dashboard automatically.

## 8. Verify URL in sn-verify.sh

**Correct URL template for single-report render:**
```
https://<instance>.service-now.com/nav_to.do?uri=sys_report_template.do%3Fjvar_report_id%3D<report_sys_id>
```

Note: the nested `?` and `=` of the inner URL **must be percent-encoded** (`%3F`, `%3D`) or the nav_to wrapper will 404.

## 9. Render-check patterns

When `sn-verify.sh` screenshots the report, also scan the page text for these **failure signatures** (use `get_page_text` or inspect the DOM):

| Failure text | Meaning | Fix reference |
|--------------|---------|---------------|
| "Published reports are disabled" | Wrong URL or publish gate hit | #5 |
| "Cannot generate the report. To configure the report, select Row and Column values" | Pivot missing `row`/`column` | #2 |
| "Aggregation field is not specified for aggregate type AVG" | AVG/SUM missing `sumfield` | #3 |
| "Loading report…" after 10 s with no chart | Trend config conflict (often both `field` and `trend_field` set) | #4 |
| "The page you are looking for could not be found" | URL encoding wrong | #8 |

If none of these appear **and** a chart/table is present in the DOM, the report is verified.

## 10. Instance data safety

- **Always** wrap report creation in an update set (`servicenow-cli updateset create "<name>" --description "…"` then `updateset set-current <sys_id>`). Easy rollback.
- Pre-flight check data availability before creating: `servicenow-cli aggregate count <table> --query "<filter>"`. Don't create empty reports.
