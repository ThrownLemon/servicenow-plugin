# Deploying servicenow-plugin changes

This plugin is consumed by Claude Code via a marketplace clone plus a
per-version cache. **Source commits do not automatically flow to users.**
Follow the steps below every time you ship a fix, or installed copies
will remain stuck on the previous version indefinitely.

## How Claude Code resolves the plugin at runtime

Two distinct locations exist on every developer machine:

1. `~/.claude/plugins/marketplaces/servicenow-plugin/` — a git clone of this
   repo. Updated via `git pull`. Holds the source of truth.
2. `~/.claude/plugins/cache/servicenow-plugin/servicenow-plugin/<version>/`
   — an extracted per-version cache. **This is what `$CLAUDE_PLUGIN_ROOT`
   resolves to at runtime.** It is not re-extracted on `git pull` — only
   when Claude Code detects a version change.

If you edit a file in the marketplace clone and don't bump the version,
the cache keeps serving the old copy. Silently.

## Ship checklist

Run through this list for every fix that touches `skills/`, `hooks/`,
`scripts/`, or `agents/`:

- [ ] **Bump `.claude-plugin/plugin.json` `version`** (semver — patch for
      bugfixes, minor for additions, major for breaking changes). This
      is the single most-skipped step and the one that causes silent
      staleness for users.
- [ ] Update `CHANGELOG.md` with the bullet list of changes.
- [ ] Commit to source (`/Users/travis/Projects/cli/servicenow-plugin`)
      on `main`.
- [ ] `git push origin main`.
- [ ] Verify the GitHub ref advanced: `git log --oneline origin/main -3`.

## Deploying to your local Claude Code

After a ship:

```bash
# Pull the marketplace clone
cd ~/.claude/plugins/marketplaces/servicenow-plugin && git pull origin main

# Invalidate the stale cache so Claude re-extracts the new version
rm -rf ~/.claude/plugins/cache/servicenow-plugin

# Confirm the fresh cache carries your changes — pick a file you just
# edited and `head` it to verify.
head ~/.claude/plugins/marketplaces/servicenow-plugin/skills/report-builder/SKILL.md
```

On the next `Skill` or hook invocation, Claude Code rebuilds the cache
from the marketplace checkout. `$CLAUDE_PLUGIN_ROOT` then points at
your new code.

## Validating a ship end-to-end

A spawned subagent reading a self-contained prompt is the cleanest
confidence check. Example:

```
/task servicenow-plugin:servicenow-assistant \
  "Build a bar report of open incidents by priority. Follow the /report-builder
   pre-flight checklist literally. Report back the last-verified dates you
   see on the references, whether the preflight hook output was visible,
   and whether the references alone were enough (no instance introspection)."
```

If the agent reports missing references, undated references, or
complains about BSD-sed, the cache didn't refresh — start over from the
deploy steps above.

## Why bumping the version matters even for docs-only changes

Skill references are loaded at runtime from the cache. An undated or
stale `references/*.md` will mis-steer Claude on the next task (this
plugin has shipped exactly that failure mode before — see commit
`459208c`). A patch bump is cheap insurance.
