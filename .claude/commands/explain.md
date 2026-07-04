---
description: Explain a module/flow for a newcomer, using the code graph; optionally save the insight to memory.
argument-hint: <path, module, or question>
---

Explain **$ARGUMENTS** clearly for someone new to the codebase.

Use the graphify graph + reading. Cover: what it does, how it fits the overall architecture, its key
types/functions, what depends on it and what it depends on (call graph / blast radius), the main
flow, and any gotchas. Use a small diagram if it helps.

If the explanation uncovers a durable, non-obvious fact (a design decision, a gotcha, an env quirk),
append it to `.claude/memory/` and index it in `.claude/MEMORY.md` so the next session keeps it.
Do not change application code.
