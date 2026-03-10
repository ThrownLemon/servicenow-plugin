# Report Type Reference

## Required Fields by Report Type

| Report Type | Required Fields |
|-------------|----------------|
| bar, pie, donut, funnel | `field`, `aggregate` |
| line, area (trend) | `field`, `aggregate`, `trend_field`, `trend_interval` |
| pivot_table | `field` (row), `group_after` (column), `aggregate`, value field |
| list | `filter` only |
| heatmap | `field`, compatible field types |

## Aggregate Values

- `COUNT` — Count of records
- `SUM` — Sum of a numeric field
- `AVG` — Average of a numeric field
- `MIN` — Minimum value
- `MAX` — Maximum value

## Trend Intervals

- `day` — Daily intervals
- `week` — Weekly intervals
- `month` — Monthly intervals
- `quarter` — Quarterly intervals
- `year` — Yearly intervals

## Common Intent → Config Mapping

| User Says | Config |
|-----------|--------|
| "Show me P1 incidents by month" | table: incident, filter: priority=1, field: opened_at, type: line, trend_field: opened_at, trend_interval: month, aggregate: COUNT |
| "Pie chart of incidents by category" | table: incident, field: category, type: pie, aggregate: COUNT |
| "How many open changes per team" | table: change_request, filter: state!=closed, field: assignment_group, type: bar, aggregate: COUNT |
| "List of critical incidents" | table: incident, filter: priority=1, type: list |
| "Average resolution time by priority" | table: incident, field: priority, type: bar, aggregate: AVG, value_field: calendar_duration |
