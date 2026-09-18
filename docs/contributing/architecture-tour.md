---
title: Architecture tour
description: A practical guide to the kwatch codebase for new contributors.
sidebar_position: 1
---

# Architecture tour

Start with the runtime flow rather than opening every package:

```text
event → observation → finding → incident decision → lifecycle event → delivery
```

## Repository map

| Area | Responsibility |
| --- | --- |
| `cmd/kwatch` | Thin command entry point |
| `internal/app` | Composition root and startup/shutdown lifecycle |
| `internal/controller` | Informers, queues, reconciliation, and graph wiring |
| `internal/observe` | Kubernetes objects to domain observations |
| `internal/monitor` | Monitor metadata and typed family extension contract |
| `internal/monitor/pod/policy` | Pure Pod/container policy decisions |
| `internal/monitor/pod/enrichment` | Pod events, owners, logs, suppression I/O |
| `internal/incident` | Domain-facing incident lifecycle boundary |
| `internal/insight` | Cause, impact, and recent-change analysis |
| `internal/delivery` | Domain-facing notification boundary |
| `internal/persistence` | Domain-facing restart-safe state boundary |
| `internal/model` | Shared domain objects and persistence projections |
| `internal/event` | Shared event and observation conversion types |
| `internal/config` | Loading, defaults, validation, and suppression indexes |
| `internal/client` | Application-owned Kubernetes, HTTP, DNS, kubelet, and clock dependencies |
| `internal/health` | Liveness, readiness, safe diagnostics, and metrics serving |
| `internal/k8s/dynamicwatch` | Shared dynamic informer discovery and generation lifecycle |
| `internal/rbac` | Permission auditing and RBAC health |

## Where should a change go?

- Kubernetes watch, queue, or reconciliation: `internal/controller`.
- Kubernetes object parsing or owner lookup: `internal/observe`.
- Resource-specific detection: a monitor package.
- Pure Pod/container detection: `internal/monitor/pod/policy`.
- Event, owner, log, or suppression enrichment:
  `internal/monitor/pod/enrichment`, then `internal/monitor/pod` orchestration.
- Incident grouping, attribution, cooldown, or resolution: `internal/incident`.
- Cause and blast-radius analysis: `internal/insight`.
- Provider payload or transport behavior: `internal/delivery`.
- Restart and ConfigMap state: `internal/persistence`.
- Cross-cutting logs, metrics, or health: use the existing owning package
  boundary and `internal/health`; do not create a new observability god package.

Avoid adding business logic to `internal/app`. The application package should
assemble components and coordinate lifecycle; it should not become another
god package.

## Monitor families

Monitor families group related detection policy without creating one package
per Kubernetes resource. Pod/container, workload, node, network, and security
detection use concrete family boundaries; storage, telemetry, and control-plane
monitors remain in their existing cohesive lifecycle packages. The Pod family
separates deterministic policy from enrichment: policy receives configuration
and an injected clock, while enrichment receives explicit read-only sources.
A family owns typed detector ordering and Kubernetes-specific interpretation;
it does not own incident identity, delivery, or persistence.

Do not create one universal monitor interface containing every resource method.
Use a small family-specific API and explicit composition-root wiring. The
controller dispatches through `controller.RuntimeSet`; no handler façade is
needed in production detection paths.

The controller is wired through `controller.RuntimeSet`, a set of narrow
family capability bundles. Add a processor to the family that owns it; do not
grow a universal runtime interface.

## Runtime boundaries contributors must preserve

- `config.RuntimeConfig` is the immutable production snapshot. Compile
  defaults, overlays, policies, routes, templates, thresholds, and intervals
  once. Do not pass raw `config.Config` into runtime components.
- `internal/client.ClientSet` is the application-owned construction boundary
  for Kubernetes, discovery, dynamic, REST, HTTP, DNS, kubelet, and clock
  dependencies. Domain constructors receive only the narrow dependency they
  need; they must not fall back to global clients or clocks.
- Family sources are configured once through a typed `ConfigureSources` seam
  before processing starts. A missing lister means unavailable capability:
  detection is skipped and no synthetic incident is created or resolved.
- The application owns long-running goroutines and shutdown. Health owns only
  `Open → Serve → Stop`; watcher generations have completion handles and stale
  generations cannot clear current status.
- With the default two replicas, one Lease holder is active and the other is a
  standby. Standbys do not watch, deliver, or write mutable persistence.

## Dependency boundaries

Dependencies point toward the domain and shared leaf packages. Provider
adapters use the delivery transport and receive the configured outbound HTTP
client from the composition root; they do not import `internal/k8s`,
`internal/controller`. Shared packages such as
`internal/model` and `internal/event` do not depend on orchestration or
provider code.

Run the boundary check before opening a pull request:

```sh
make architecture-check
```

## Test organization

Tests are organized by the behavior or boundary they specify, not by the
order in which files were created. For example, controller tests use names
such as `controller_queue_test.go` and `controller_baseline_test.go`, while
incident tests use names such as `engine_grouping_scope_test.go`.

When a test file grows, first ask whether it contains separate responsibilities
such as lifecycle, persistence, transport, or fixtures. Move each responsibility
to a descriptive file and keep shared setup in `fixtures_test.go` or
`test_helpers_test.go`. Do not create `part2`, `part3`, or `extra` files. A
single cohesive test file can remain large; arbitrary numbered fragments make
the package harder to search and maintain.

Run the repository test-layout check together with the normal verification:

```sh
sh scripts/check-test-layout.sh
```

The architecture check above is intentionally small and import-based. It
catches accidental upward dependencies early while leaving design decisions
visible in code review. Both checks run as part of `make verify` and the main
repository CI job.

When changing a long-running component, add a deterministic cancellation test,
a completion assertion, a bounded failure/status reason, and a focused metric
if the failure is operationally important. When changing persistence or
configuration, review schema/overlay behavior and update the generated website
reference rather than hand-editing generated pages.

The retired correlation, alert-manager, and state-manager boundaries were
removed because they were internal implementation details. New code should use
the canonical `internal/incident`, `internal/delivery`, and
`internal/persistence` packages.

## A useful debugging path

When an alert is missing, inspect the system in this order:

1. Was the informer synchronized?
2. Was the resource enqueued?
3. Did controller reconciliation return an error?
4. Did observation extraction produce the expected identity?
5. Did Pod policy or enrichment suppress the finding?
6. Did the incident engine create or update an incident?
7. Did delivery route and process the lifecycle event?
8. Did persistence or provider failure affect recovery?
