# Changelog

## 0.3.0 — 2026-04-21

- **New skill: `ui-component`** — full `snc ui-component` lifecycle: scaffold, develop, deploy, generate-update-set. Covers auth setup, `now-ui.json` config, UIB integration, and failure signatures.
- **New reference: `ui-component/references/gotchas.md`** — 8 failure modes observed during first scaffold+deploy (scope offline restrictions, deploy --force requirement, tag name mismatch, Node >= 22, etc.)
- **Updated skill: `sn-setup`** — added `snc` as step 2 (profile check + configure guidance). Renumbered remaining steps.
- **Updated CLAUDE.md** in servicenow-cli — one-paragraph note distinguishing `snc` from `servicenow-cli`.

## 0.2.0 — 2026-04-20

- **New skill: `report-builder`** — rewritten with correct `sys_report` field names (`column`, `sumfield`, `interval`), mandatory pre-flight checklist, render-verify step.
- **New reference: `report-builder/references/pitfalls.md`** — 10 failure modes including silent-ignore fields, pivot config, AVG/SUM, trend interval, published_reports gate, is_published REST restriction, dashboard widget pinning UI-only.
- **Updated reference: `report-builder/references/report-types.md`** — correct field names throughout, gotcha table, exact enum strings.
- **Fixed: `hooks/scripts/sn-preflight.sh`** — BSD-sed replaced with portable awk, banner routed to stderr, skill references for admin tables, portable timeout chain.
- **Fixed: `scripts/sn-verify.sh`** — BSD-sed URL parse fixed (`sed -E`), cleanup subshell wrapped in nohup+disown.
- **New: `DEPLOY.md`** — documents marketplace-vs-cache architecture, ship checklist, invalidation command.

## 0.1.0 — initial release

- catalog-builder skill
- report-builder skill (initial)
- sn-setup skill
- sn-preflight hook
- sn-verify.sh script
