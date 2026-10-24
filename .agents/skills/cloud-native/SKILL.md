---
name: cloud-native
description: Packaging and running services in the cloud — container images, Docker Compose, Kubernetes manifests and Helm, EC2/VM deployments, microservice boundaries versus a modular monolith, 12-factor configuration, health probes, autoscaling, zero-downtime rollout, and the observability and cost consequences. Invoke when a change touches a Dockerfile, compose file, K8s/Helm manifest, Terraform, or a deployment pipeline, when service decomposition is being discussed, or on explicit request — "Docker", "container", "Kubernetes", "K8s", "Helm", "EC2", "microservice", "cloud-native", "deployment", "12-factor".
---

# Cloud-native — containers · Kubernetes · microservices

Implements §3a's "avoid growing a monolith — design modular boundaries and service-ready seams"
without pretending that more services is automatically better.

## Microservice or not

A service boundary should follow a **business capability that changes on its own schedule and is
owned by one team**. Splitting by technical layer (`user-api`, `user-service`, `user-db-service`)
produces a distributed monolith: all the network failure modes, none of the independence.

Start with a **modular monolith** with real internal boundaries (§2a module rules, one module = one
capability, communication through published interfaces only). It deploys as one unit, debugs in one
process, and can be split later precisely because the seams exist. Extract a service when you have
a concrete reason: independent scaling, independent release cadence, team ownership, a different
runtime, or a compliance boundary. "Microservices are best practice" is not a reason — record the
decision either way.

Every extraction you do take on: a network hop (timeouts, retries, circuit breaker — see
**stack-backend**), eventual consistency (no cross-service transaction — see **messaging-events**),
a versioned contract (see **api-design**), distributed tracing, and its own pipeline, secrets and
on-call story. Do not split what shares a transaction.

## Container images

- **Multi-stage build**: compile in a full image, ship only the artifact and its runtime. A
  400 MB image for a 30 MB binary is attack surface plus egress cost.
- **Pin the base image** by digest or an exact patch tag, never `:latest` — an unpinned base makes
  the build unreproducible and silently pulls in changes.
- **Run as a non-root user**, read-only root filesystem, no unnecessary capabilities. A container
  running as root with a writable filesystem turns one RCE into a host problem.
- **No secrets in the image or in `ARG`** — they persist in layers and in the registry. Inject at
  runtime.
- `.dockerignore` excludes `.git`, `node_modules`, `.env`, build caches.
- **One process per container**, PID 1 handles signals (an init or an exec-form `CMD`) so
  `SIGTERM` actually reaches the app and graceful shutdown works.
- Scan the image in CI (Trivy, Grype) and fail on high/critical — see the **security** skill.

## 12-factor essentials

Config from the environment, never baked in. Backing services are attached resources reached by
URL. Processes are **stateless and disposable** — anything on local disk is gone at the next
restart; sessions belong in Redis or a token. Logs go to **stdout as structured JSON**; the
platform ships them, the app does not write files or rotate them. Dev/prod parity: same image,
different config. Admin tasks (migrations) run as a one-off job against the same image, not by
hand on a pod.

## Kubernetes

- **Probes are three different questions.** *Liveness* = restart me if this fails (must not check
  dependencies, or a DB blip restarts your whole fleet). *Readiness* = take me out of the load
  balancer (may check dependencies). *Startup* = give me time to boot before liveness applies.
- **Requests and limits on everything.** No requests means the scheduler is guessing; no memory
  limit means one leak evicts its neighbours. CPU limits throttle — set them deliberately.
- **Rolling updates need `maxUnavailable`/`maxSurge`, a PodDisruptionBudget, and a
  `terminationGracePeriod` longer than your drain time**, plus `preStop` to stop taking traffic
  before shutdown. Otherwise "zero-downtime" means dropped requests.
- **Secrets:** K8s Secrets are base64, not encryption — use the platform's secret store (External
  Secrets, Sealed Secrets, Vault, cloud KMS) and enable encryption at rest. Never a secret in a
  ConfigMap or a committed values file.
- **Manifests are code**: in version control, reviewed, environment differences via Helm values or
  Kustomize overlays — never a hand-edited resource in the cluster. A `kubectl edit` in production
  is an incident waiting to be un-reproducible.
- Namespaces + NetworkPolicies + RBAC scoped to what the workload needs (least privilege — see the
  **security** skill). Default-deny egress is worth the effort.
- HPA on a metric that reflects load (RPS, queue depth) rather than CPU when CPU isn't the
  bottleneck. Autoscaling a service whose database is the constraint just moves the queue.

## EC2 / VM deployments

Immutable images (Packer) over configuration drift; an autoscaling group with a health check and a
load balancer over a pet instance; deploys are blue/green or rolling, never in-place `scp`. Same
observability and secret-management rules apply — a VM is not an excuse for a `.env` on disk with
600 permissions and no rotation.

## Observability & cost

Structured logs with a correlation id, RED/USE metrics, and traces spanning service boundaries
(OpenTelemetry) — cross-service debugging without traces is guesswork. Alert on symptoms users feel
(error rate, latency percentiles, saturation), not on CPU. And keep an eye on the bill: an
always-on cluster for a service with ten daily users, a `LoadBalancer` per service, unbounded log
retention, and cross-AZ chatter are the usual suspects.

## Testing (§3a)

Build the image in CI and run the integration suite **against the container**, not against a local
`go run` — the image is what ships. Validate manifests (`kubeval`/`kubeconform`, `helm lint`,
`helm template` diff in the PR). Smoke-test after deploy against the real health endpoints, and
make sure the rollback path is exercised, not assumed.

## Typical findings to raise

`:latest` base image · container running as root · secret in an image layer, ConfigMap or committed
values file · liveness probe checking the database · no resource requests/limits · no
PodDisruptionBudget on a multi-replica service · state on local disk in a stateless service · logs
written to a file inside the container · service split along technical layers · a new service
introduced with no recorded decision · manifest changed by hand in the cluster.
