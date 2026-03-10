# Catalog Item 8-Step Dependency Chain

Steps MUST execute in this order. Each step depends on sys_ids from previous steps.

## Step 1: Create/lookup catalog (sc_catalog)

Only if user wants a non-default catalog. Most items go in "Service Catalog".

```bash
servicenow-cli catalog discover
# If creating new:
servicenow-cli table create sc_catalog --data '{"title":"<name>"}'
```

## Step 2: Create/lookup category (sc_category)

Needs catalog sys_id from step 1.

```bash
# Search existing:
servicenow-cli table list sc_category --query "title=<name>" --limit 1
# Create new:
servicenow-cli catalog create-category --data '{"title":"<name>","sc_catalog":"<catalog_sys_id>"}'
```

## Step 3: Create catalog item (sc_cat_item)

Needs category sys_id. Set assignment_group for fulfillment routing.

```bash
servicenow-cli catalog create --data '{"name":"<name>","short_description":"<desc>","category":"<cat_sys_id>","assignment_group":"<group_sys_id>"}'
```

## Step 4: Create variables (item_option_new)

Needs cat_item sys_id. Map type names to integer codes (see variable-type-mapping.md). Set order explicitly (100, 200, 300...).

```bash
servicenow-cli catalog add-variable <item_sys_id> --data '{"name":"<var_name>","question_text":"<label>","type":"<integer_code>","mandatory":"true","order":"100"}'
```

For Reference types, add:
```json
{"reference":"<target_table>","reference_qual":"<encoded_query>"}
```

## Step 5: Create choices (question_choice)

Only for Select Box (type 5) variables. Needs variable sys_id from step 4.

```bash
servicenow-cli catalog add-choice <variable_sys_id> --data '{"text":"<display>","value":"<value>","order":"100"}'
```

## Step 6: Create UI policies (catalog_ui_policy)

Needs catalog_item sys_id. Conditions referencing variables use `IO:` prefix.

```bash
servicenow-cli catalog add-ui-policy <item_sys_id> --data '{"short_description":"<name>","conditions":"IO:<var_name>=<value>","on_load":"true","reverse_if_false":"true"}'
```

Condition syntax: `IO:var_name=value^IO:other_var=value` (standard SN encoded query with IO: prefix for variables).

## Step 7: Create UI policy actions (catalog_ui_policy_action)

Needs policy sys_id from step 6 AND variable sys_id from step 4.

```bash
servicenow-cli catalog add-ui-policy-action <policy_sys_id> --data '{"variable":"<target_var_sys_id>","mandatory":"true","visible":"true","read_only":"false"}'
```

## Step 8: Create client scripts (catalog_script_client)

Needs cat_item sys_id. MUST set `ui_type=10` for Service Portal.

```bash
servicenow-cli catalog add-client-script <item_sys_id> --data '{"name":"<name>","type":"onChange","ui_type":"10","variable_name":"<var_name>","cat_item":"<item_sys_id>","script":"function onChange(control, oldValue, newValue, isLoading) { ... }"}'
```

- `ui_type`: MUST be `10` for Service Portal (default = desktop only)
- `type`: `onChange`, `onLoad`, or `onSubmit`
- `variable_name`: required for onChange, must match variable `name` from step 4

## On Partial Failure

Track all created sys_ids. If a step fails:
1. Log which steps completed and which failed
2. Do NOT auto-delete records
3. Report to user with list of created records
4. The update set provides the audit trail
