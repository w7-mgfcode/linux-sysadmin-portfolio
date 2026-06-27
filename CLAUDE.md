@AGENTS.md

## Claude-specific notes

- Canonical agent rules live in **AGENTS.md** (imported above). This file adds only
  Claude Code runtime notes — it must not restate policy.
- Local-only, gitignored assistant tooling (restore from git history if missing):
  - `.claude/` — Claude Code settings, custom slash commands, agents, templates.
  - `.agents/skills/` — portable skills (`maintaining-agent-docs`, `plan-execute-review`).
- `main` is protected: land changes via PR with **ShellCheck** + **Compose Validate**
  green (see AGENTS.md → "Validation Before Completion").
