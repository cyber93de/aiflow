# Memory & context policy
- **Learning intensity:** aggressive
- **Graph memory (graphify):** enabled
- **RAG code search (cocoindex-code):** enabled
- **External docs (context7):** enabled

Learn **aggressively**: after every non-trivial task, save durable facts (decisions, gotchas, env quirks, API shapes) to memory and refresh the graphify graph. Prefer the graph over re-reading files.

## Context stack — which source to hit, in order (fewest tokens first)
| Need | Use | Why |
|------|-----|-----|
| Current task, deps, decisions, session state | **Beads** (`bd`) | structured work memory, survives compaction |
| Durable project facts / gotchas / env quirks | **memory files** (this dir) | prose facts not in code/git |
| Where a symbol is defined, who calls it, dependency direction | **graphify** MCP | exact structural graph, no re-scan |
| "Find code about concept X" / semantic / fuzzy | **cocoindex-code** (`ccc search` / MCP) | AST-aware RAG, ~70% fewer tokens than reading files |
| External library / framework API docs | **context7** MCP | live upstream docs, avoids hallucination |
| Anything still unresolved | read the file(s) | only after graph + RAG have narrowed the target |

**Rule:** never scan whole files first. Route the question through graphify (structure) and
cocoindex-code (semantics) to locate the few relevant chunks, then open only those.
Refresh both indexes with `aiflow index` after significant code changes.
