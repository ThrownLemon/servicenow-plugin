<!--
last-verified: 2026-04-21
verified-against: ac3ptyltddemo11 (Zurich family)
snc version: 1.1.3
ui-component extension: 29.0.2
-->

# UI Component — Known Gotchas & Workarounds

## 1. Scope auto-generation requires a live instance

`snc ui-component project` contacts the instance to register a scope in `sys_ux_lib_scope`
and generate a unique scope name (e.g. `x_a3_x_test_comp_0`).

**If you pass `--offline` without a scope**, it errors:
> "Scope Name must be defined when using offline mode"

**If you pass `--offline --scope x_my_scope` with a hyphenated scope**, it errors:
> "Scope Name must contain only alphanumeric characters separated by a single `_`"

**Fix:** Don't use `--offline` unless you have a pre-registered scope in `alphanumeric_underscore` format (no hyphens). For first-time scaffolding, always scaffold against the live instance.

## 2. Auth lives in `~/.snc/` — not `~/.servicenow-cli/`

`snc` stores profiles at `~/.snc/` (likely `~/.snc/config.json` or similar).
`servicenow-cli` stores config at `~/.servicenow-cli/config.json`.

They are independent. When you reconfigure one (new instance, rotated password),
you must reconfigure the other. `sn-setup` covers both.

## 3. `deploy` is silent on partial failure

`snc ui-component deploy` exits 0 even when some component assets fail to register.
Always verify after deploy:

```bash
servicenow-cli table list sys_ux_lib_component \
  --query "name=<scope>-<name>" \
  --fields name,scope,version,sys_updated_on --json
```

If the `sys_updated_on` timestamp is not recent, the deploy didn't land.

## 4. Component not appearing in UI Builder picker

After a successful deploy, the component must have correct `associatedTypes` in `now-ui.json`
to appear in the UI Builder component palette.

Default types from scaffold: `["global.core", "global.landing-page"]`

If the target page is a different type (e.g. `global.record-page`), add it to the array
and redeploy with `--force`.

## 5. Node version requirement

`package.json` engine: `"node": ">=22"`. Running `snc ui-component develop` or `deploy`
with Node < 22 may fail silently or produce garbled output. Check: `node --version`.

## 6. `deploy --force` is required for updates

Once a component is registered on the instance, a plain `deploy` rejects the push
if the component record already exists. Always use `--force` for subsequent deploys:

```bash
"/Applications/ServiceNow CLI/bin/snc" ui-component deploy --force
```

## 7. Update set capture for components

`snc deploy` pushes to `sys_ux_lib_component` and related tables. These records ARE
captured in the active update set — but only if an update set is active at deploy time.
Set the update set via `servicenow-cli updateset set-current <sys_id>` before deploying.

## 8. Tag name mismatch = blank render

The custom element registered in `createCustomElement(...)` must exactly match the key
in `now-ui.json`'s `components` object, and that key must be `<scope>-<name>` in kebab-case.

A scope like `x_a3_x_test_comp_0` plus name `x-test-component` produces the tag
`a-3-x-test-component` (the scaffold transforms the scope prefix). Verify in the
generated `src/<tag-name>/index.js` — the string passed to `createCustomElement`
is the authoritative element name.
