---
name: sn-setup
description: This skill should be used when the user asks to "set up ServiceNow", "configure ServiceNow plugin", "check ServiceNow prerequisites", "sn-setup", "verify ServiceNow connection", or when the SessionStart hook reports missing dependencies. Guides through prerequisite installation and connectivity testing.
---

# ServiceNow Setup Wizard

Interactive prerequisite checker and configuration wizard for the ServiceNow plugin.

## Prerequisite Checks

Run each check in order. Stop at the first failure and guide the user through the fix.

### 1. servicenow-cli

```bash
servicenow-cli --version
```

If not found: "Install servicenow-cli from https://github.com/ThrownLemon/servicenow-cli"

If found, check configuration:

```bash
servicenow-cli info --json
```

If not configured: guide user to run `servicenow-cli config`

### 2. snow-docs

```bash
snow-docs --version
```

If not found: "Install snow-docs from https://github.com/ThrownLemon/snow-docs"

If found, check index:

```bash
snow-docs info
```

If index empty: guide user to run `snow-docs sync`

Validate key subcommands:

```bash
snow-docs ask "test query" --raw --max-tokens 100
snow-docs api "incident" --raw --limit 1
```

### 3. Playwright

```bash
bunx playwright --version
```

If not installed:

```bash
bunx playwright install chromium
```

### 4. Connectivity Test

Test ServiceNow API access:

```bash
servicenow-cli table list sys_properties --limit 1
```

If this fails, the instance URL or credentials are wrong. Guide user through `servicenow-cli config`.

### 5. Update Set Binding Test

This test determines whether `updateset set-current` works on the user's instance.

```bash
# Create a test update set
servicenow-cli updateset create "SN Plugin Setup Test - $(date +%s)" --description "Auto-created by /sn-setup to test update set binding"
```

Capture the sys_id from the output. Then:

```bash
# Set it as current
servicenow-cli updateset set-current <test_update_set_sys_id>

# Create a test record
servicenow-cli table create sys_properties --data '{"name":"sn.plugin.test.binding","value":"test","type":"string"}'
```

Capture the test record sys_id. Then verify it landed in the update set:

```bash
servicenow-cli table list sys_update_xml --query "update_set=<test_update_set_sys_id>^target_name=<test_record_sys_id>" --limit 1
```

If the query returns a result: **binding works**. Record this:
- Tell the user: "Update set binding via set-current works on your instance."
- The builder skills will use `updateset set-current` for update set wrapping.

If zero results: **binding doesn't work**. Record this:
- Tell the user: "Update set binding via REST is not supported on your instance. Builder skills will use `updateset add-artifact` as fallback."
- The builder skills will use `updateset add-artifact` after each create.

### 6. Cleanup

Delete the test record and complete/delete the test update set:

```bash
servicenow-cli table delete sys_properties <test_record_sys_id>
servicenow-cli updateset complete <test_update_set_sys_id>
```

### Completion

Report all results:
- servicenow-cli: ✓/✗
- snow-docs: ✓/✗
- Playwright: ✓/✗
- API connectivity: ✓/✗
- Update set binding: works / fallback needed

"Setup complete. You can now use /catalog-builder and /report-builder."
