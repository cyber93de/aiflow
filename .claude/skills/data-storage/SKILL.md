---
name: data-storage
description: Choosing and using the right store — relational SQL (PostgreSQL and friends), NoSQL (document, key-value, wide-column, graph), embedded/in-app databases (SQLite, Room, Drift, Realm), Redis as cache and in-memory store, and Elasticsearch/OpenSearch as a search and read-load layer in front of the database. Covers when each is justified, cache invalidation, indexing, migrations and the polyglot-persistence trade-off. Invoke when a change adds or touches a datastore, a cache, a search index, or a migration, when a read path is slow, or on explicit request — "database", "SQL", "NoSQL", "MongoDB", "Redis", "cache", "Elasticsearch", "SQLite", "index", "migration".
---

# Data & storage — SQL · NoSQL · in-app DB · Redis · Elasticsearch

Extends `AGENTS.md` §3c (database modelling rules, MANDATORY) with the *choice* of store and the
performance layers §3a asks you to consider deliberately.

## Default: a relational database

PostgreSQL unless there is a stated reason otherwise. It does JSON, full-text search, geospatial,
arrays, LISTEN/NOTIFY, partitioning and window functions — a surprising number of "we need a
document store / a search engine / a queue" requirements are one Postgres feature away. The §3c
design rules (≥3NF, real foreign keys, `NOT NULL` by default, `CHECK` constraints, `UNIQUE` on
natural keys, precise types, junction tables, no needless surrogate keys) apply in full to anything
you create new. Brownfield schemas fall under §3c's B-rules: **note improvement potential as beads,
don't restructure as a side effect** — other systems may share that schema and old app versions may
need to roll back onto it.

**Migrations** are versioned, forward-only, and reviewed like code (Flyway, Liquibase, EF
Migrations, `sqlx migrate`, Alembic). Expand–contract for anything a running deployment reads:
add the new column → backfill → dual-write → switch reads → drop the old one, in separate releases.
A migration that locks a large table in a single statement is an outage.

## When NoSQL is actually justified

| Kind | Justified when | Not justified because |
|------|----------------|------------------------|
| **Document** (MongoDB, DynamoDB) | genuinely schema-variable aggregates, single-key access dominates, horizontal write scale | "schemas are annoying" — you still have a schema, it's just enforced nowhere |
| **Key-value** (Redis, DynamoDB) | cache, session, rate limiter, ephemeral state | it is your system of record |
| **Wide-column** (Cassandra, Scylla) | huge write volume, known query patterns, multi-region | you'd like it to be fast |
| **Graph** (Neo4j) | traversal depth is the query (recommendations, permissions, fraud rings) | your data merely has foreign keys |
| **Time-series** (Timescale, Influx) | metrics/telemetry at scale with retention and downsampling | you have a `created_at` column |

Choosing NoSQL means giving up joins, cross-document transactions, and schema enforcement — you now
own consistency in application code. Say so out loud, record the decision, and don't spread data
across five stores because each one is individually defensible: **polyglot persistence multiplies
your operational and consistency burden.**

## Embedded / in-app databases

SQLite (Room, Drift, GRDB, SwiftData, `sqflite`) or Realm on client devices. Treat it as a real
database, not a cache file: migrations are versioned and tested against an *old* database file,
schema changes ship with an upgrade path, and the file is encrypted (SQLCipher / Realm encryption)
where it holds anything personal. It is also the offline layer — see the **stack-mobile** skill for
sync and conflict resolution. Never ship an app that wipes user data on a schema mismatch.

## Redis — cache and in-memory store

Worth it when a measurable read path is slow, or when you need something a relational store models
badly: sessions, rate limiting, distributed locks (Redlock, with its caveats), leaderboards,
short-lived queues, pub/sub fan-out.

Rules that keep it from becoming the outage:
- **Every key has a TTL** unless you can name who deletes it. Unbounded key growth is the classic
  Redis incident.
- **Cache invalidation is designed, not hoped for.** Pick one: TTL-only (accept staleness, state
  the window), write-through, or explicit invalidation on write. Write it down.
- **The cache is never the source of truth** — a cold Redis must be survivable, just slower.
  Guard against stampedes (jittered TTLs, single-flight) and cache the negative result too.
- Namespaced key schema (`app:v1:user:{id}:profile`), documented, versioned so a format change
  doesn't read stale garbage.
- Measure the hit rate. A cache below ~80 % hit rate on a hot path is usually the wrong key.

## Elasticsearch / OpenSearch

The right tool for relevance-ranked full-text search, faceting, and aggregations over large
volumes — and, as §3a notes, a way to **decouple the database from the application** by absorbing
read load that would otherwise hammer the primary.

- **It is a derived index, never the source of truth.** You must be able to rebuild it from the
  database — and that rebuild path is tested, not theoretical.
- Feed it from the outbox/CDC stream (see **messaging-events**), not by dual-writing from the
  service — dual writes diverge the first time one of them fails.
- Design the mapping deliberately (analysers, `keyword` vs `text`, no dynamic mapping explosion);
  index only fields you actually query.
- Reindex behind an **alias** so a mapping change is a zero-downtime alias swap.
- Before adopting it: check whether Postgres full-text search or a materialised view already
  answers the requirement (`ponytail`, §2a reuse). Elasticsearch is a second datastore to operate,
  secure and keep in sync.

## Performance basics

Index what you filter, join and sort on — and **only** that (§3c R11); every index costs write
throughput. Read the query plan before adding one. Fix N+1 at the source (batch/join/`DataLoader`),
not with a cache. Paginate every unbounded query, cursor-based for large sets. Use connection
pooling with a bounded pool, and never hold a transaction across a network call.

## Testing (§3a)

Integration tests run against the **real** engine in Testcontainers — H2 standing in for
PostgreSQL, or fakeredis for Redis, hides dialect and eviction behaviour, which is exactly where
the bugs are. Test migrations both ways: apply to an empty DB **and** to a snapshot of the current
production schema. Test cache-miss and cache-stale paths explicitly, and test the search index
rebuild.

## Typical findings to raise

Soft foreign key without a real constraint (§3c R4) · nullable column that is never actually
unknown (R6) · missing index on a filtered column, or an index-everything strategy (R11) · a cache
key with no TTL · cache used as the source of truth · dual-write to DB and search index ·
`SELECT *` with no pagination · N+1 hidden behind a cache · migration that rewrites a large table
in one statement · a second datastore introduced without a recorded decision.
