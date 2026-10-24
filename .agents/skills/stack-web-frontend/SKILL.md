---
name: stack-web-frontend
description: Architecture, quality and test checklist for browser front-ends built with Angular, React, or Vue (incl. Next/Nuxt/SvelteKit-style meta-frameworks) — feature-sliced structure, state management, the API/DTO boundary, forms and validation, XSS and auth-token handling in the browser, bundle/Core-Web-Vitals budgets, i18n and accessibility, and the front-end test pyramid. Invoke when the project has an Angular, React, or Vue application, or on explicit request — "frontend", "Angular", "React", "Vue", "SPA", "component", "bundle size".
---

# Web front-end — Angular · React · Vue

Applies `AGENTS.md` §2 (architecture rules) and §3a (quality gates) to code that runs in a hostile,
untrusted, wildly varying runtime: the user's browser.

## Layering (§2a, front-end dialect)

```
routes / pages        (composition + data loading; thin)
   ↓
feature modules       (one folder per business capability: components, state, api-client, model)
   ↓
domain model + logic  (pure TS — no framework imports, no fetch, no DOM)
   ↑
api layer             (HTTP client + DTOs + mapping to the domain model)
   ↓
shared / ui-kit       (framework-level primitives; depends on nothing feature-specific)
```

- **Slice by feature, not by type.** `features/checkout/{ui,state,api,model}` beats
  `components/`+`services/`+`models/` at 20 files and is unmanageable at 200. Cross-feature imports
  go through a feature's public entry point only — that is §2a's module boundary.
- **DTO ≠ view model** (§2a): map the API shape into your own model in the api layer. The day the
  backend renames a field you change one mapper, not forty components.
- **Domain logic is framework-free TypeScript.** Price calculation, eligibility rules, validation
  predicates — plain functions, unit-testable without a renderer.
- Presentational components take props and emit events; anything that fetches, routes, or holds
  global state is a container. Don't mix the two in one file.

## State

Choose deliberately and write it down: server state (TanStack Query / RTK Query / Angular
`resource`) is **not** client state (Zustand/Redux/Pinia/NgRx/signals) — conflating them is how
teams end up hand-rolling caching, retries and invalidation badly. Most "global state" is server
cache. Keep genuinely global client state small: session, theme, feature flags. Derive, don't
duplicate.

## Browser reality

- **XSS is your threat model.** Never `innerHTML` / `dangerouslySetInnerHTML` / `v-html` /
  `bypassSecurityTrust*` with anything that touched user input; sanitise (DOMPurify) if you truly
  must render HTML. Ship a **Content-Security-Policy** — it is the backstop when one slips through.
- **Tokens:** prefer `httpOnly`+`Secure`+`SameSite` cookies. `localStorage` is readable by any
  script on the page, so a single XSS becomes account takeover. If a bearer token must live in JS,
  keep it in memory only and refresh it silently.
- **Never trust the client.** Hiding a button is UX, not authorisation — every rule is enforced
  server-side too (see the **api-design** and **security** skills).
- **Performance is a budget, not a vibe.** Set and check Core Web Vitals (LCP/INP/CLS) and a bundle
  budget in CI. Route-level code splitting, lazy routes, `OnPush`/`memo`/`computed` where profiling
  says so — not everywhere on principle. Virtualise long lists. Serve modern image formats.
- **Accessibility is a requirement** (`accessibility-checker`, WCAG 2.2 AA): semantic elements
  before ARIA, keyboard operability, visible focus, labelled inputs, announced errors, contrast.
- **i18n from the start.** Retrofitting extraction into 300 components is a project, not a task —
  no hardcoded user-facing strings, and plural/date/number formatting via the framework's i18n.
- **Forms:** one validation source of truth (Zod/Yup/Angular validators) reused for types and
  runtime checks; validate on blur/submit, not on every keystroke; show errors next to the field
  and in an accessible summary.

## Toolchain & style (§3)

`prettier` + `eslint` (with the framework plugin and `eslint-plugin-jsx-a11y` / Angular a11y
rules); TypeScript in **strict** mode — `any` is a finding, and so is a stray `@ts-ignore`.
Pin dependencies; run `npm audit`/`osv-scanner` (see the **dependency-auditor**).

## Testing (§3a)

- **Unit** — domain functions and hooks/services, no renderer needed. > 80 % of changed logic.
- **Component** — Testing Library (React/Vue/Angular) or Vitest+jsdom. Query by **role and
  accessible name**, never by CSS class: a test that survives a refactor and fails when the a11y
  tree breaks is worth ten snapshot tests.
- **Contract** — the api layer against a mocked server (MSW), asserting the DTO→model mapping.
- **BDD E2E** (§3a mandatory) — Playwright or Cypress, Given/When/Then, against a real build. Add
  `axe-core` to the E2E run so accessibility regressions fail the pipeline.
- Test the states that get skipped: loading, empty, error, permission-denied, slow network,
  very long content, RTL locale, 200 % zoom.

## Typical findings to raise

Business rules inside a component · the API DTO bound straight into the template · server data in
a Redux/NgRx store with hand-written caching · `dangerouslySetInnerHTML` on user content · JWT in
`localStorage` · `any` or `@ts-ignore` in new code · a component file past a few hundred lines with
four responsibilities · hardcoded user-facing strings · no error/empty state · unbounded list
render · snapshot tests standing in for behaviour tests.
