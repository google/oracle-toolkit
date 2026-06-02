# Local Agents — Override AgentSpec

Agents in this directory **take precedence over AgentSpec plugin agents**
of the same name. Use this to customize phase agents to your project's
conventions without forking the plugin.

## Layout

| Folder | Purpose |
|---|---|
| `workflow/` | Override SDD phase agents (`brainstorm-agent`, `define-agent`, `design-agent`, `build-agent`, `ship-agent`, `iterate-agent`) |
| `custom/` | New project-specific agents that don't replace anything |

## Override an AgentSpec agent

1. Find the plugin agent at `${CLAUDE_PLUGIN_ROOT}/agents/<category>/<name>.md`
2. Copy it to `.claude/agents/<category>/<name>.md` — keep the `name:` field identical
3. Edit freely; your version is now what runs

Example: override `build-agent` so `/build` runs your team's review checklist:

```bash
cp $CLAUDE_PLUGIN_ROOT/agents/workflow/build-agent.md \
   .claude/agents/workflow/build-agent.md
# edit .claude/agents/workflow/build-agent.md
```

## Add a custom agent

Drop a new `.md` file in `custom/` with valid frontmatter (`name`, `description`,
`tools`). It becomes available to `/build` and other phase commands automatically.

## Resolution Order

```text
.claude/agents/<name>.md   (your local override — wins)
        ↓ if absent
${CLAUDE_PLUGIN_ROOT}/agents/<name>.md   (AgentSpec plugin)
```

This is enforced by Claude Code's native plugin loader. No config required.
