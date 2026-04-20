---
name: ui-component
description: Use when the user asks to "create a Now Experience component", "scaffold a UI component", "build a custom component", "deploy a component", "snc ui-component", or when working on Next Experience / UI Framework custom web components. Covers the full snc ui-component lifecycle from scaffold to deploy.
---

# UI Component Builder

Guides the full lifecycle for building and deploying Now Experience custom components
using the official `snc` CLI (`/Applications/ServiceNow CLI/bin/snc`).

> **snc vs servicenow-cli**
> `snc` handles component packaging (scaffold → build → deploy to `sys_ux_lib_component`).
> `servicenow-cli uib` handles UI Builder page composition (event wiring, fix scripts).
> They are complementary — use both when building + wiring a component into a page.

---

## Pre-flight checklist

Run before any `snc` work:

```bash
# 1. Verify snc is available
"/Applications/ServiceNow CLI/bin/snc" version

# 2. Verify profile is configured against your instance
"/Applications/ServiceNow CLI/bin/snc" configure profile list
```

If no default profile exists, configure one:
```bash
"/Applications/ServiceNow CLI/bin/snc" configure profile set \
  --host https://<instance>.service-now.com \
  --user admin
# Prompts for password interactively — never pass it as a flag
```

Auth lives in `~/.snc/` — separate from `servicenow-cli`'s `~/.servicenow-cli/config.json`.
Both must point at the same instance.

---

## Step 1 — Create an update set

Always wrap component work in an update set for rollback:

```bash
servicenow-cli updateset create "UIB component: <name>" --description "Now Experience component"
servicenow-cli updateset set-current <sys_id>
```

---

## Step 2 — Scaffold the project

Run from the directory where you want the project created:

```bash
"/Applications/ServiceNow CLI/bin/snc" ui-component project \
  --name <component-name> \
  --description "<short description>"
```

- `--name` must be a valid npm package name (kebab-case, e.g. `my-field-hints`)
- **Do not use `--offline`** unless you already have a scope name — it errors without one
- The instance auto-generates a scope (`x_<tenant>_<name>_<suffix>`) and creates a `sys_ux_lib_scope` record
- Record the generated scope — it prefixes every component tag name

**Project structure created:**
```
<name>/
├── now-ui.json          # Component manifest (scope, UI Builder config)
├── now-cli.json         # Dev server config (proxy settings)
├── package.json         # npm deps (@servicenow/ui-core, ui-renderer-snabbdom)
├── src/
│   └── <scope>-<name>/
│       ├── index.js     # Component source (JSX + snabbdom)
│       ├── styles.scss  # Component styles
│       └── __tests__/
│           └── index.js
├── example/
│   └── element.js       # Local dev harness
└── tile-icon/
    └── generic-tile-icon.svg
```

---

## Step 3 — Develop locally

```bash
cd <component-name>
"/Applications/ServiceNow CLI/bin/snc" ui-component develop
```

- Starts a webpack dev server, hot-reloads on file changes
- Proxies `/api` calls to the configured instance (requires live instance)
- Open the URL printed in the terminal to see the component rendered

**Key source patterns:**

```js
import { createCustomElement } from '@servicenow/ui-core';
import snabbdom from '@servicenow/ui-renderer-snabbdom';
import styles from './styles.scss';

const view = (state, { updateState }) => (
  <div>...</div>
);

createCustomElement('<scope>-<name>', {
  renderer: { type: snabbdom },
  view,
  styles,
  properties: {
    // Declare props that can be set from UI Builder
    label: { default: '' },
  },
});
```

**UI Builder visibility** is controlled by `now-ui.json`:
```json
{
  "components": {
    "<scope>-<name>": {
      "uiBuilder": {
        "associatedTypes": ["global.core", "global.landing-page"],
        "label": "My Component",
        "category": "primitives"
      }
    }
  }
}
```
`associatedTypes` controls which UIB page types the component appears in.

---

## Step 4 — Deploy to instance

```bash
cd <component-name>
"/Applications/ServiceNow CLI/bin/snc" ui-component deploy
```

- Builds the component and pushes it to `sys_ux_lib_component` on the configured instance
- If component already exists, add `--force` to overwrite: `deploy --force`
- Deployment is captured in the active update set automatically

After a successful deploy, verify the component appeared:
```bash
servicenow-cli table list sys_ux_lib_component \
  --query "name=<scope>-<name>" \
  --fields name,scope,version --json
```

---

## Step 5 — Generate update-set XML (for migration)

If you need to migrate the component to another instance instead of deploying directly:

```bash
cd <component-name>
"/Applications/ServiceNow CLI/bin/snc" ui-component generate-update-set
```

Produces an XML file you can import via **System Update Sets → Retrieved Update Sets → Import XML**.

---

## Wiring the component into a UI Builder page

Once deployed, use `servicenow-cli uib` to wire the component into a UIB page:

```bash
# Wire a client script to an event on a macroponent
servicenow-cli uib wire-event <macroponent_sys_id> <event_name> <script_sys_id>

# Verify the macroponent has the event wired
servicenow-cli table get sys_ux_macroponent <macroponent_sys_id> \
  --fields name,internal_event_mappings --json
```

See the `uib` command group (`servicenow-cli uib --help`) for the full set of page-composition commands.

---

## Failure signatures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `snc ui-component project` fails with "Scope Name must be defined" | `--offline` flag used without a scope | Remove `--offline` or pass `--scope x_yourscope` |
| `deploy` succeeds but component not in UIB component picker | `now-ui.json` missing or `associatedTypes` wrong | Check `uiBuilder.associatedTypes` in `now-ui.json` |
| `deploy` fails with auth error | `snc` profile not configured or stale | Run `snc configure profile set` |
| `develop` proxy errors on every API call | Instance URL in profile wrong | `snc configure profile list` to verify host |
| Component appears in UIB but renders blank | Missing `createCustomElement` call or wrong element name | Tag name must match `<scope>-<name>` exactly |

See `references/gotchas.md` for deeper failure analysis.
