---
description: Release gate — one agent, two hats: architect review (architecture, design, risks) plus the objective quality-gate checklist (CLAUDE.md §3a/§3b). Verdict PASS (release) or CHANGES REQUIRED.
argument-hint: <bead-id, optional>
---

Run the review gate for bead **$ARGUMENTS** (or the in-progress task).

Use the **reviewer** agent on `git diff` — it wears both hats in one pass:

**Architect hat:** acceptance criteria met → architecture (target architecture, layers, module
boundaries, interfaces; necessary changes done sensibly + recorded as ADR) → design (SOLID, clean
architecture, domain model, right abstraction level) → maintainability (technical debt, over-/
under-engineering, extensibility) → risks (vulnerabilities, performance, concurrency, API breaking
changes, backward compatibility).

**Quality-gate hat (checklist, §3a/§3b/§3c):** previous findings addressed → tests green (unit + BDD
E2E, >80 % coverage of changed logic, non-static methods) → no new smells/duplicates/architecture
violations → 0 linter/compiler warnings → static analysis done → no high/critical security
findings → leveled logging + doc comments in the project's doc style → `.http` files current for
REST changes → database changes per §3c (new models follow the design rules; existing schemas are
rollback-sensitive and possibly shared — **uncommissioned structural changes are a BLOCKER**,
commissioned ones need consumer check + rollback plan + versioned migration) → docs/changelog
updated → requirement fully implemented.

Output findings as `file:line — problem — fix`, tagged BLOCKER/SHOULD/NIT. Out-of-scope
improvement ideas are **persisted as `[suggestion]` beads** (never lost in chat). Verdict: PASS
(bead may close) or CHANGES REQUIRED (concrete change requests back to the implementer). Do not
merge or close the bead if any BLOCKER or unchecked gate item remains.
