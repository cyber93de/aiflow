---
name: ponytail
description: YAGNI decision ladder for any code-writing task — before adding new code, checks whether it needs to exist at all, already exists in the codebase, is available in the language's stdlib, is a native platform feature, is already an installed dependency, or can be a one-liner, and only then writes the minimum viable new code. Complements AGENTS.md §3a design principles (YAGNI, KISS, no premature abstraction) with an explicit, ordered checklist applied to every new function/class/dependency/abstraction. Triggers automatically whenever the agent is about to write new code, add a dependency, or introduce an abstraction — offer to apply the ladder first. Also invoke on explicit request — "ponytail", "check for over-engineering", "can this be simpler", "do we need this".
---

# ponytail — reuse and simplify before writing new code

Inspired by [ponytail](https://github.com/dietrichgebert/ponytail): "the best code is the code you
never wrote." This skill only applies when `.aiflow/config.json → ponytail.enabled` is `true` — if
the key is missing or `false`, do not apply this skill; stop reading and proceed normally. Read
`.aiflow/config.json → ponytail.mode` (`full` default, `lite`, `ultra`) for intensity — see §3.

## 1. The decision ladder

Before writing new code (a function, class, module, dependency, or abstraction), work down this
list in order and stop at the first "yes":

1. **Does it need to exist at all?** (YAGNI — see AGENTS.md §3a) If the requirement doesn't need
   it yet, don't build it.
2. **Is it already in the codebase?** Search before writing — a near-duplicate helper is a sign
   to extend/reuse, not to add a sibling.
3. **Is it in the language's standard library?** Prefer stdlib over a hand-rolled equivalent.
4. **Is it a native platform/framework feature?** (e.g. CSS instead of a JS library, a database
   constraint instead of app-level validation.)
5. **Is it already an installed dependency?** Check `package.json`/`requirements.txt`/`go.mod`/etc.
   before adding a new one for something an existing dependency already offers.
6. **Can it be one line?** A one-line inline expression beats a named helper for genuinely trivial
   logic used once.
7. **Only then:** write the minimum-viable new code that satisfies the actual requirement — no
   speculative parameters, no configuration for hypothetical future cases, no interface with a
   single implementation "for testability" unless a test actually needs it.

This does not override explicit user instructions or AGENTS.md §3a mandatory quality gates (error
handling, logging, tests, SOLID). It governs *how much new surface area* to add while meeting them.

## 2. Reviewing a diff (over-engineering audit)

When asked to review a diff for over-engineering (or via `/ponytail-review`), check each added
file/function/class against the ladder in §1 and flag:
- New code that duplicates something already in the codebase or an installed dependency.
- Abstractions (interfaces, factories, config flags) with exactly one call site / one
  implementation and no near-term second one.
- Parameters, branches, or config options added for a case nobody asked for.
- A multi-line solution where a one-liner or stdlib call does the same job.

Report findings as `file:line — what's over-built — the simpler alternative`. Do not silently
rewrite the user's diff; propose the simplification and apply it only on confirmation, unless the
mode is `ultra` (see §3), which may fix small, unambiguous cases (e.g. a redundant wrapper
function) directly and report what changed.

## 3. Mode (from `.aiflow/config.json → ponytail.mode`)

- **full** (default, recommended) — apply the ladder to every new code addition; on review, flag
  findings and propose fixes, confirm non-trivial ones before applying.
- **lite** — apply the ladder only to clearly new abstractions/dependencies (skip nitpicking
  trivial one-off code); on review, report only high-confidence findings.
- **ultra** — apply the ladder aggressively, including small unambiguous simplifications inline
  without asking first; on review, fix small findings directly and report the diff.
