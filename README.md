# ServiceNow Plugin for Claude Code

Give Claude ServiceNow domain expertise with guided builders and browser verification.

## Prerequisites

- [servicenow-cli](https://github.com/ThrownLemon/servicenow-cli) — configured with instance credentials
- [snow-docs](https://github.com/ThrownLemon/snow-docs) — ServiceNow documentation CLI
- Playwright chromium — `bunx playwright install chromium`

## Installation

Add the marketplace, then install:

```bash
claude plugin marketplace add https://github.com/ThrownLemon/servicenow-plugin
claude plugin install servicenow-plugin
```

## Skills

| Skill | Invocation | Description |
|-------|-----------|-------------|
| Setup Wizard | `/sn-setup` | Check prerequisites, test connectivity, configure update set binding |
| Catalog Builder | `/catalog-builder` | Guided catalog item creation with variables, UI policies, client scripts |
| Report Builder | `/report-builder` | Natural language to ServiceNow report |

## Agent

**servicenow-assistant** — General-purpose ServiceNow agent for ad-hoc tasks. Docs-first pattern: always queries `snow-docs` before write operations.

## Hooks

- **SessionStart**: Checks for required CLIs, purges stale sessions
- **PreToolUse (Bash)**: Auto-queries `snow-docs` before ServiceNow write commands
