---
description: Decompose a goal/PRD into a task tree using claude-task-master, then mirror it into Beads.
argument-hint: <goal text, or path to a PRD file>
---

Decompose **$ARGUMENTS** into an implementable task tree.

1. If $ARGUMENTS is a file, treat it as a PRD; otherwise write a short PRD to
   `.taskmaster/docs/prd.txt` capturing the goal + the acceptance criteria.
2. Use **claude-task-master** (MCP tools, or `task-master parse-prd` / `task-master expand`)
   to generate tasks with subtasks + dependencies. It uses the `claude-code` provider — no
   extra API key.
3. Mirror the resulting tasks into **Beads** (`bd create` + `bd dep`) so `/beads:ready` and
   the Ralph loop can drive them. Keep acceptance criteria on each bead.
4. Show the dependency overview and `/beads:ready`.

No feature code — decomposition only.
