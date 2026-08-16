---
name: security
description: Operational security checklist for building and reviewing code — OWASP Top 10 and ASVS as the review raster, IAM done properly (least privilege, roles over per-user grants, short-lived credentials, rotation), API authentication and authorisation, input validation and injection defence, secrets handling, cryptography choices, and supply-chain safety (pinned dependencies, no curl-pipe-sh, image scanning). Invoke when a change touches authentication, authorisation, sessions, tokens, credentials, permissions, crypto, file upload, deserialisation, user input reaching a query or a shell, IAM policy or a dependency, or on explicit request — "security", "OWASP", "IAM", "auth", "permissions", "secrets", "vulnerability", "supply chain".
---

# Security — IAM · OWASP · API protection · supply chain

Operationalises §3a's "security findings: 0 high/critical" and §3b's authentication requirements.
The **security-advisor** agent runs the whole-project scan; this skill is what every implementer
and reviewer applies to the change in front of them.

## OWASP Top 10 as a review raster

| | Check on this change |
|---|---|
| **A01 Broken access control** | Every endpoint and every **object** is authorised, server-side. Can user A pass user B's id and get their data (IDOR)? Is a hidden UI element the only thing stopping an action? Deny by default. |
| **A02 Cryptographic failures** | TLS everywhere incl. internal hops. Passwords: **argon2id**/bcrypt/scrypt, never SHA-*. AES-GCM or ChaCha20-Poly1305 for data; never ECB, never a hand-rolled scheme, never a reused nonce/IV. Randomness from a CSPRNG. |
| **A03 Injection** | Parameterised queries only — no string-built SQL, ever. No shell with user input (`exec` an argv array, not a command string). LDAP/XPath/NoSQL/template injection too. Output-encode for the sink (HTML/attr/JS/URL). |
| **A04 Insecure design** | Is there a rate limit, a lockout, a spend cap, an audit trail? Threat-model the abuse case, not just the happy path. |
| **A05 Misconfiguration** | No debug mode, no stack traces, no directory listing, no default credentials in production. Security headers set (HSTS, CSP, `X-Content-Type-Options`, `Referrer-Policy`). CORS allow-lists specific origins — never `*` with credentials. |
| **A06 Vulnerable components** | Dependencies pinned and scanned (below). |
| **A07 Auth failures** | Short-lived tokens, real session invalidation on logout and password change, MFA where the data warrants it, no user enumeration in error messages or timing. |
| **A08 Integrity failures** | No deserialisation of untrusted data into arbitrary types (Java native, `pickle`, `unserialize`, unrestricted YAML). Verify signatures on anything you fetch and execute. |
| **A09 Logging failures** | Security events (login, privilege change, failed authz) are logged with who/what/when — and **no** secrets, tokens, or personal data in the log line. |
| **A10 SSRF** | Any URL that came from a user is validated against an **allow-list**, with redirects disabled and link-local/metadata ranges (169.254.169.254, 127.0.0.0/8, RFC1918) blocked. |

For a formal bar, use **OWASP ASVS** — level 1 for low-risk, level 2 for anything handling personal
or financial data. Pick the level once, per project, and record it.

## IAM done properly

- **Least privilege, always.** Grant the narrowest action on the narrowest resource. A wildcard
  (`*:*`, `Action: "s3:*"`, `GRANT ALL`, `cluster-admin`) is a finding unless it is justified in
  writing.
- **Roles, not per-user grants.** Permissions attach to a role; users and workloads assume the
  role. Per-user grants drift within weeks and nobody can answer "who can do X".
- **Short-lived credentials over long-lived keys.** Workload identity (IRSA, workload identity
  federation, managed identity, K8s ServiceAccount tokens) beats a static access key in an env var
  every time. Where a long-lived key is unavoidable: rotate it on a schedule, and make rotation
  *tested*, not documented.
- **Separate identities per workload and per environment.** One shared service account across all
  services means one compromise is total.
- **Human access is time-bound and audited** — just-in-time elevation, MFA, and an audit trail you
  actually retain. Break-glass credentials exist, are sealed, and alert when used.
- **Deny by default**, and review the effective permissions, not the intended ones — most cloud
  IAM engines have a policy simulator; use it.
- Application-level authorisation follows the same shape: RBAC (or ABAC where rules are
  attribute-driven), checked in the application/service layer (§2a) — not scattered across
  controllers, and not only in the UI.

## API protection (§3b)

HTTPS only. **OAuth 2.x / OIDC**, short-lived JWTs, or managed API keys with rotation — Basic Auth
is insufficient beyond a throwaway local demo. Validate the JWT **signature, `exp`, `aud`, `iss`**
and the algorithm (reject `alg: none` and algorithm confusion); never trust claims you didn't
verify. Authorise per endpoint *and* per object. Rate-limit and bound payload size. Version the API
so you can deprecate an insecure shape (see the **api-design** skill).

## Secrets

Never in code, never in a repo, never in an image layer or a `docker build --build-arg`, never in a
log or an error message, never in a URL. Source them from the platform's secret store or a secret
manager; `.env` is for local development and is gitignored. **Rotate** — and make sure the app
picks up a rotated secret without a manual redeploy. If a secret was ever committed, rotate it:
scrubbing git history does not un-leak it.

## Supply chain

- **Pin dependencies** (lockfile committed, exact versions, base images by digest). A floating
  range means your build result depends on when you ran it.
- **Scan** in CI: `npm audit`/`osv-scanner`/`pip-audit`/`cargo audit`/Dependabot for packages,
  Trivy or Grype for images. Fail on high/critical. The **dependency-auditor** does the periodic
  sweep; CI catches the regression.
- **Vet new dependencies** before adding one (`ponytail` asks whether you need it at all): is it
  maintained, how many transitive deps does it drag in, is the package name a typosquat of the one
  you meant, does it run install scripts?
- **Never `curl … | sh` from an unverified source** — and where an installer must be piped, pin the
  URL to a tag or a digest and check the checksum. The same applies to anything a CI job downloads.
- **Least privilege in CI too:** scoped tokens, no `pull_request_target` running untrusted code
  with secrets, third-party actions pinned to a commit SHA rather than a moving tag.

## Testing (§3a)

Write the negative test: expired token, tampered token, wrong-`aud` token, another user's object
id, missing role, injection payload in every user-controlled field, oversized payload, path
traversal in an upload filename. Authorisation deserves the same coverage bar as business logic —
an untested authz rule is an outage with a CVE number.

## Typical findings to raise

Authorisation only in the UI · object id trusted from the client (IDOR) · string-concatenated SQL ·
`alg`/issuer/audience unverified on a JWT · password hashed with SHA-256 · wildcard IAM policy ·
long-lived static access key · secret in a config file, image layer or log · unpinned dependency or
`:latest` base image · `curl | sh` in a build script · CORS `*` with credentials · user-supplied
URL fetched server-side without an allow-list · untrusted deserialisation · stack trace returned to
the client.
