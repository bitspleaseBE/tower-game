# Agent guide — Bubble Pop

Godot 4 candy tower defense. Product intent: [`blueprint.md`](blueprint.md). Creative docs: [`docs/`](docs/README.md).

## Plans (read these first)

| Location | What it is | When to use |
|----------|------------|-------------|
| [`plans/`](plans/README.md) | Stage roadmap (v1.0 build order) | Scope, stage status, handoffs, verification |
| [`.cursor/plans/`](.cursor/plans/) | Active Cursor feature plans | In-progress work, locked decisions, task checklists |

### `plans/` — implementation roadmap

Eight-stage sequence from portrait shell → release. Index and status live in [`plans/README.md`](plans/README.md). Cross-cutting checks: [`plans/VERIFICATION.md`](plans/VERIFICATION.md).

Respect stage cut lines, Out of scope, and Stage 8 follow-ups. Do not reopen finished stages unless the task clearly belongs there.

### `.cursor/plans/` — feature plans

Markdown plans authored in Cursor (frontmatter: `name`, `overview`, `todos`, `status`). These are the source of truth for **current** feature work beyond the stage roadmap.

Before implementing a feature that has a plan here:

1. Open the matching `.plan.md` and follow its decisions and task order.
2. Prefer updating that plan’s todos over inventing a parallel checklist.
3. If the user asks to continue a named feature, start from its plan file.

## Related

- Version bump + build word on push: [`.cursor/rules/version-bump-on-push.mdc`](.cursor/rules/version-bump-on-push.mdc)
- Asset hunt / promote: `.claude/skills/find-assets`, `.claude/skills/select-asset`
