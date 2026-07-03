---
layout: default
title: Concepts
nav_order: 3
has_children: true
description: "Core aiflow concepts for Claude Code: two-layer code memory (graph + RAG), context engineering, token optimization (caveman, rtk), and team collaboration."
---

# Concepts

The ideas that make aiflow effective with **Claude Code**:

- **[Memory: graph + RAG](memory)** — why aiflow pairs a structural **code knowledge graph**
  (graphify) with **semantic RAG** (cocoindex) plus durable Beads memory, and how it routes questions.
- **[Token optimization](token-optimization)** — caveman terse output, rtk CLI-output filtering,
  graph/RAG retrieval, and cheap/local model routing — measured with `aiflow cost`.
- **[Team collaboration](team)** — a shared Dolt issue graph over your git remote, atomic claiming,
  and pull-before-push for many members.
- **[Features & advantages](features)** — the capability map and the case for the framework.
