# ServiceNow `sys_report` Field Reference

**Use these exact field names and values in the JSON payload** to `servicenow-cli report create`. ServiceNow silently accepts unknown fields and ignores them — misnamed fields **do not produce errors**, they produce broken reports. Always verify via a render check after creating.

## Field names per report type

| Report Type | Required fields on `sys_report` |
|-------------|---------------------------------|
| Vertical bar / Horizontal Bar / Pie / Donut / Funnel / Gauge | `field`, `aggregate` |
| Vertical bar / Horizontal Bar — with AVG or SUM | `field`, `aggregate`, **`sumfield`** (the numeric field to aggregate) |
| Line / Area — time series trend | **`trend_field`** (the date/time field) + **`interval`** (bucket size); `field` should be empty |
| Pivot Table | **`row`** (y-axis grouping) + **`column`** (x-axis grouping) + `aggregate`; optional `sumfield` for AVG/SUM pivots |
| List | `filter` only; no chart config needed |
| Heatmap | `row`, `column`, `aggregate` (same as pivot) |

### Critical "gotcha" fields

| Intent | WRONG field name | CORRECT field name |
|--------|------------------|--------------------|
| Value to average/sum | `value_field` | **`sumfield`** |
| Second pivot axis | `group_after` | **`column`** |
| Trend bucket size | `trend_interval` | **`interval`** |
| Pivot rows | `field` (alone) | **`row`** (plus `column`) |

All the WRONG names look plausible but are **silently ignored** by ServiceNow.

## Enum value strings

These must be passed as **exact strings** in the payload — ServiceNow expects display values on write.

### `type`

| Pass this string | Renders as |
|------------------|------------|
| `Vertical bar` | Vertical bar chart |
| `Horizontal Bar` | Horizontal bar chart |
| `Pie` | Pie chart |
| `Donut` | Donut chart |
| `Line` | Line / trend chart |
| `Area` | Area / stacked trend |
| `Pivot Table` | Row × column cross-tab |
| `List` | Table of records |
| `Single Score` | Single large number |

### `aggregate`

| Pass this string | Behaviour |
|------------------|-----------|
| `Count` | Count of records (requires no `sumfield`) |
| `Sum` | Sum a numeric field (requires `sumfield`) |
| `Average` | Average a numeric field (requires `sumfield`) |
| `Min` / `Max` | Min/max of a numeric field (requires `sumfield`) |

### `interval` (for trend/line/area reports)

| Pass this string | Bucket granularity |
|------------------|--------------------|
| `Date` | Daily buckets ← **note: NOT `Day`** |
| `Week` | Weekly |
| `Month` | Monthly |
| `Quarter` | Quarterly |
| `Year` | Yearly |

## Intent → Correct payload

| User says | `servicenow-cli report create --data` payload |
|-----------|----------------------------------------------|
| "P1 incidents by day" | `{"title":"…","table":"incident","type":"Line","filter":"priority=1^opened_at>javascript:gs.daysAgoStart(30)","trend_field":"opened_at","interval":"Date","aggregate":"Count"}` |
| "Pie of incidents by category" | `{"title":"…","table":"incident","type":"Pie","field":"category","aggregate":"Count","filter":"active=true"}` |
| "Open changes per team" | `{"title":"…","table":"change_request","type":"Vertical bar","field":"assignment_group","aggregate":"Count","filter":"state!=-5"}` |
| "List of critical incidents" | `{"title":"…","table":"incident","type":"List","filter":"priority=1"}` |
| "Avg resolution time by priority" | `{"title":"…","table":"incident","type":"Vertical bar","field":"priority","aggregate":"Average","sumfield":"calendar_duration","filter":"state=6^ORstate=7"}` |
| "SLA breach by priority pivot" | `{"title":"…","table":"task_sla","type":"Pivot Table","row":"task.priority","column":"has_breached","aggregate":"Count"}` |

## Verification model

After `servicenow-cli report create`, **do not trust success-exit as "the report works"**. The create endpoint returns `201` for silently-ignored-field payloads. You must:

1. Navigate to the admin render URL (see `pitfalls.md`) in Playwright
2. Check for specific failure banners (see `pitfalls.md`)
3. Only then claim the report is ready

## Dashboard composition

`servicenow-cli dashboard create` creates the `pa_dashboards` container. **Pinning reports to it is a manual UI step** in the dashboard editor — this cannot currently be done reliably via REST (the widget grid requires `sys_grid_canvas_pane` + `portal_widget` records whose schema is fragile and version-dependent). Direct the user to the dashboard URL after creating the reports.
