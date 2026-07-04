---
description: Run the modernization-advisor over the whole brownfield codebase — proposes modernisation concepts (microservices, REST/cloud-native, git, supported stacks, test frameworks) as a report for the architect. Report only; no code changes, no beads. Not part of the delivery loop.
---

Run a full modernisation review.

Use the **modernization-advisor** agent. Walk the entire codebase and write modernisation concepts
to `.aiflow/modernization-report.md`: stack currency (flag EOL/unsupported versions), monolith →
microservice extraction candidates (incremental, strangler-fig), legacy integration → REST/JSON +
modern eventing, svn → git, containerisation/CI/observability gaps, missing unit/BDD/E2E test
frameworks (name concrete ones for the stack), and caching/search decoupling opportunities
(Redis/Elasticsearch). Maintainability and security lead the ranking — end-of-life technology
first. Per concept: what, why, incremental how, effort, suggested priority; end with a ranked
table and the top-3 starting moves. The architect reviews the report manually and decides what
becomes Beads issues — do not create beads and do not change code.
