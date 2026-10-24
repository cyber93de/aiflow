---
name: api-design
description: Designing and reviewing service interfaces — REST (versioning, resource modelling, status codes, pagination, idempotency, errors, OpenAPI, .http files), SOAP/WSDL when it is genuinely required and how to migrate off it, GraphQL and gRPC trade-offs, and API authentication/authorisation. Invoke when creating or changing any endpoint, contract, WSDL, OpenAPI/Swagger spec or client, when deciding between REST/SOAP/GraphQL/gRPC, or on explicit request — "API", "REST", "endpoint", "SOAP", "WSDL", "OpenAPI", "GraphQL", "gRPC", "versioning".
---

# API design — REST · SOAP · GraphQL · gRPC

Implements `AGENTS.md` §3b (REST interfaces, MANDATORY) and the §2a rule that DTOs — never domain
objects — cross a process boundary.

## Choosing the style

| Style | Fits | Cost you accept |
|-------|------|-----------------|
| **REST/JSON** | default for anything public or cross-team | chattiness, over/under-fetching |
| **gRPC** | internal service-to-service, high volume, streaming | binary on the wire, browser needs a proxy, tighter coupling |
| **GraphQL** | many heterogeneous clients over one rich graph | query-cost control, caching, N+1 resolvers — all now *your* problem |
| **SOAP/WSDL** | an existing partner/enterprise contract demands it | verbosity, tooling weight, scarce expertise |

§3a says state of the art is the default: a **new** SOAP interface, or XML payloads on a new REST
API, is not built silently. Ask why (PO-level question, options + consequences) and record the
answer. Legitimate reasons exist — a bank or authority mandates it, WS-Security/WS-AtomicTransaction
is contractually required, the partner's toolchain is SOAP-only. "That's how we've always done it"
is not one.

**Consuming or maintaining SOAP:** generate the client from the WSDL, never hand-roll XML; keep the
generated code out of the domain behind a port (§2a); pin the WSDL/XSD version in the repo and diff
it on change; disable external entity resolution (XXE — see the **security** skill). To migrate off
it, put a REST facade in front, move consumers one at a time, and retire the SOAP endpoint on a
published deprecation date — never a big-bang cutover.

## REST rules (§3b)

**Versioning from day one.** `/api/v1/…` by default (or header/media-type versioning if the project
already uses it — consistently, not both). Breaking change ⇒ new version + a documented deprecation
window and a `Deprecation`/`Sunset` header on the old one. An unversioned new API is a review
finding. Additive changes (new optional field, new endpoint) are not breaking — removing or
renaming a field, tightening validation, or changing a status code is.

**Resources, not verbs.** `POST /api/v1/orders/42/cancellations` beats `POST /cancelOrder?id=42`.
Plural nouns, nesting only where the child cannot exist alone.

**Status codes mean things.** 200/201(+`Location`)/204 · 400 malformed · 401 unauthenticated ·
403 authenticated-but-not-allowed · 404 · 409 conflict · 412 precondition · 422 semantically
invalid · 429 rate-limited (+`Retry-After`) · 5xx *your* fault. Never 200-with-`{"error":…}`.

**Errors are a contract.** Use RFC 9457 `application/problem+json` (`type`, `title`, `status`,
`detail`, `instance`) plus a stable machine-readable code and, for validation, per-field entries.
Never leak stack traces, SQL, or internal hostnames.

**Collections** are always paginated — cursor-based for large or live data, offset only for small
bounded sets — with documented `sort` and `filter` and a **maximum** page size the server enforces.
An endpoint that can return everything will eventually be asked to.

**Idempotency:** GET/PUT/DELETE are idempotent by definition; make `POST` idempotent with an
`Idempotency-Key` header wherever a retry could double-charge or double-create. Concurrency via
`ETag` + `If-Match` (return 412 on mismatch), not last-write-wins.

**Security** (§3b, details in the **security** skill): HTTPS only; OAuth 2.x / OIDC, short-lived
validated JWTs (signature **and** `exp`, `aud`, `iss`), or managed API keys with rotation —
**Basic Auth is insufficient** beyond a throwaway local demo. Authorise **per endpoint and per
object**, not just "is logged in". Rate-limit. Validate and bound every input. CORS allow-lists a
known origin set, never `*` with credentials.

**Documentation is generated, not written twice.** OpenAPI from the code (or code from the spec —
pick one direction and keep it), published with the service, and diffed in CI so a breaking change
is visible in review.

**`.http` files are mandatory** (§3b): `http/<resource>.http`, one request block per operation,
happy path plus one auth and one error case, host/port/credentials from `.env`
(`{{$dotenv APP_HOST}}`, or `http-client.env.json` + a gitignored
`http-client.private.env.json` for IntelliJ). A changed endpoint with a stale `.http` file is a
review finding.

## GraphQL specifics

Depth and complexity limits (an unbounded nested query is a DoS), persisted queries in production,
DataLoader-style batching against N+1 resolvers, field-level authorisation (a nested field is a
separate authz decision), and errors in the `errors` array with codes — not as `null` with no
explanation. Version by additive evolution + `@deprecated`, not by `/v2`.

## gRPC specifics

Proto files are the contract: additive changes only, never reuse a field number, reserve removed
ones. Deadlines on every call, TLS/mTLS between services, and a schema-compatibility check in CI.

## Review checklist

- [ ] Versioned (§3b), and the change is additive — or the version was bumped with a deprecation plan
- [ ] Real authN + per-endpoint/per-object authZ; no Basic Auth; HTTPS only
- [ ] Correct status codes; `problem+json` errors with a stable code; no internals leaked
- [ ] Collections paginated with an enforced max page size; sort/filter documented
- [ ] Idempotency where a retry could duplicate an effect; `ETag`/`If-Match` on updates
- [ ] Every input validated and bounded; payload size limited; rate limit in place
- [ ] DTOs at the boundary — no domain entity serialised directly (§2a)
- [ ] OpenAPI/WSDL/proto updated and diffed; `.http` file current (§3b)
