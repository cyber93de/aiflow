---
name: stack-backend
description: Architecture, quality and test checklist for server-side services in any stack — Spring/Spring Boot, Quarkus, Jakarta EE on Tomcat, .NET, Rust (Axum/Actix), Node/NestJS, Go, Python (FastAPI/Django). Covers hexagonal layering with DAO/DTO, transactions and consistency, configuration and secrets, resilience (timeouts, retries, circuit breakers), observability, the FOSS-preferred stack, and the backend test pyramid. Invoke when the project contains a server-side application or service, or on explicit request — "backend", "service", "Spring", "Quarkus", "Jakarta", ".NET", "Rust", "NestJS", "FastAPI", "Tomcat".
---

# Backend services — JVM · .NET · Rust · Node · Go · Python

Applies `AGENTS.md` §2 (architecture rules), §3a (quality gates), §3b (REST) and §3c (database) to
a process that other systems depend on being correct and available.

## Layering (§2a, backend dialect)

```
inbound adapters   controllers / resources / handlers / consumers  — protocol only
        ↓
application        use cases, transaction boundary, orchestration    — no protocol types
        ↓
domain             entities, value objects, business rules, PORTS    — depends on nothing
        ↑
outbound adapters  repositories/DAOs, HTTP clients, producers        — implement the ports
```

- **The domain declares the port, infrastructure implements it** (§2a). `OrderRepository` is an
  interface in the domain; `JpaOrderRepository` / `SqlxOrderRepository` / `EfOrderRepository` lives
  in infrastructure and is injected. Never `new`-ed in a use case.
- **No framework or protocol types in the domain.** No `@Entity` + `@JsonProperty` on the same
  class, no `HttpRequest`, no `DbContext`. An entity annotated for both persistence and the wire
  couples the schema to the API — neither can then change alone. That is a review BLOCKER.
- **DAO/repository is the only place with SQL, a query builder, or an ORM session** (§2a). A
  `SELECT` in a controller or a service is a finding regardless of how small it is.
- **DTOs at both edges**: request/response DTOs inbound, persistence models outbound, mapped
  explicitly (MapStruct, AutoMapper, `From`/`Into`, plain functions). Generated mappers are fine;
  reflective magic that hides the mapping is not.
- **One aggregate = one repository.** Repositories return domain objects, not rows or `Optional<Row>`.

## Transactions & consistency

- The **transaction boundary is the use case**, not the repository and not the controller. One
  business operation, one transaction.
- Never hold a transaction open across a remote call — that is how a slow third party takes out
  your connection pool.
- Cross-service consistency is **not** a distributed transaction: use the outbox pattern, idempotent
  consumers, and compensations (see the **messaging-events** skill). Make every externally
  triggered operation **idempotent** — retries are a fact, not an exception.
- Concurrency control is an explicit decision: optimistic (version column) by default, pessimistic
  only where contention justifies the lock. Silent last-write-wins is a data-loss bug.

## Configuration, secrets, startup

- **12-factor config**: environment variables (or a config server / K8s ConfigMap), never a
  committed `application-prod.yml` with real values. Secrets come from a secret manager or the
  platform's secret mount — never the image, never the repo (`.env` is gitignored for a reason).
- **Fail fast at startup** on missing/invalid config with a message naming the key. A service that
  boots healthy and 500s on first request is worse than one that refuses to start.
- **Health endpoints** are separate: liveness (am I alive) ≠ readiness (can I serve — dependencies
  reachable, migrations applied). A liveness probe that checks the database restarts your service
  every time the DB hiccups.

## Resilience

Every outbound call has a **timeout** — an unbounded call is an outage waiting for a slow
dependency. Add retries **only** for idempotent operations, with exponential backoff and jitter,
bounded attempts. Circuit breakers and bulkheads (Resilience4j, Polly, tower, `opossum`) at the
integration edge. Backpressure over unbounded queues. Graceful shutdown: stop accepting, drain
in-flight, close pools.

## Observability (§3a logging, extended)

Structured logs (JSON) with levels per §3a, a **correlation/trace id** propagated through every
layer and outbound call, and never a secret or personal datum in a log line. Metrics on the four
signals that matter (rate, errors, duration, saturation) via Micrometer/OpenTelemetry/`metrics`.
Traces across service boundaries. If you can't answer "why was this request slow" from telemetry,
the change isn't done.

## Technology choices

- **FOSS-first when the project prefers it:** PostgreSQL over a proprietary RDBMS, Tomcat/Jetty
  over a commercial app server, Keycloak over a hosted IdP, Kafka/RabbitMQ/NATS over a vendor bus,
  Prometheus/Grafana/Loki over an APM licence. Record the decision either way — "we chose the FOSS
  option" is as much an ADR as choosing the vendor one.
- **Production-ready only** (§3a): no pre-1.0 framework in the critical path without a recorded
  decision; no EOL runtime (an unsupported JDK/.NET/Node line is a *security* finding).
- Prefer the framework's mechanism over a hand-rolled one: validation, DI, migrations
  (Flyway/Liquibase/EF Migrations/`sqlx migrate`), scheduling, serialisation.

## Testing (§3a)

- **Unit** — domain and use cases with ports faked. No Spring context, no database, milliseconds.
  > 80 % of changed logic, every non-static method.
- **Integration** — repositories and adapters against a **real** engine in Testcontainers, not H2
  or an in-memory double: dialect differences are exactly where the bugs live. Same for the broker.
- **Contract** — for every consumer/provider pair (Pact or schema-registry compatibility checks),
  so a breaking change fails in CI instead of in production.
- **BDD E2E** (§3a mandatory) — Given/When/Then against the running service (Cucumber/SpecFlow/
  behave/`cucumber-rs`), covering auth, the happy path, and at least one failure path.
- **`.http` files** for every new/changed REST endpoint (§3b) — happy path plus one auth and one
  error case, values from `.env`.
- Test the boring failures: duplicate request, expired token, dependency timeout, DB constraint
  violation, malformed payload, empty result, pagination past the end.

## Typical findings to raise

SQL outside a repository · entity doubling as request DTO · transaction spanning an HTTP call ·
missing timeout on an outbound client · retry on a non-idempotent operation · secrets in config
files · liveness probe checking dependencies · unversioned or Basic-Auth-protected API (§3b) ·
`catch` that swallows · logging a token or an email address · H2 standing in for PostgreSQL in
tests · no correlation id.
