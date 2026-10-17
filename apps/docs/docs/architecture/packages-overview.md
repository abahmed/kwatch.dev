---
sidebar_position: 2
title: Core Packages
description: The kwatch source tree - what each internal package does and the import direction rules that keep the layers apart.
keywords: [kwatch, kubernetes, architecture, packages, inventory, detection, rootcause, incident, delivery]
pagination_prev: architecture/overview
pagination_next: architecture/correlation-and-alerting
---

# 🧩 Core packages

This is the source-tree guide. Read the [overview](/architecture/overview)
first for behavior. The dependency rules below are enforced in the repository
by `scripts/check-architecture.sh`. Capability tiers (Community and Pro) are
defined in `internal/feature`.

## Packages

Each line matches the package's `doc.go`.

| Package | What it does |
| --- | --- |
| `cmd/kwatch` | Thin entrypoint: flags, subcommands, calls `app`. |
| `internal/app` | Assembles kwatch and owns its process lifecycle: clients, Lease, supervision, readiness, shutdown. |
| `internal/inventory` | The in-memory model of the cluster: entities, relations, attributes and recent changes. Knows nothing about Kubernetes. |
| `internal/inventory/kube` | Turns Kubernetes objects into observations: one schema per kind, discovery, watch modes, kubelet stats, probes, log reads. |
| `internal/inventory/kube/dynamicwatch` | Shared dynamic informer mechanics for discovered kinds. |
| `internal/detection` | Finds abnormal conditions (findings with health and mode); the tracker reports raised, changed and cleared. |
| `internal/detection/detectors` | The built-in detectors. Read entity attributes, return findings. |
| `internal/detection/reasons` | Stable reason codes. A leaf, shared by every layer. |
| `internal/rootcause` | What the root-cause engine shares with the layers above it: the `Cause` record, confidence levels, scheduler-message helpers. |
| `internal/rootcause/explain` | The engine: propagation table, candidate walk, scorers, greedy weighted set-cover solver, incremental cache. |
| `internal/incident` | Groups findings that share a cause into an incident and decides when people hear about it: announce, update, resolve. |
| `internal/notification` | The provider-neutral `Message`, severities and rendering helpers. A leaf. |
| `internal/notification/compose` | Writes the note for an incident decision as a short narrative. |
| `internal/scope` | Namespaces, reasons, silences and maintenance holds: which findings are in scope. |
| `internal/pipeline` | The decision loop, bounded investigation and storage workers, downtime reconciliation, audit entries. |
| `internal/pipeline/announce` | Startup summary, digest, roll-up and namespace outage collecting. |
| `internal/pipeline/coverage` | Memory and timings of the coverage backstop; its `doc.go` explains the whole check. |
| `internal/pipeline/investigate` | Evidence investigators run by the investigation pool. |
| `internal/storage` | The bbolt state file: one bucket per data class, epoch fencing, retention, reset. |
| `internal/delivery` | Routing, retries, pacing, fallback and provider dispatch. |
| `internal/delivery/transport` | The shared outbound HTTP boundary providers use. |
| `internal/delivery/api` | The small contracts shared by delivery and the provider catalog. |
| `internal/delivery/providertest` | Provider test fixtures. Never imported by production code. |
| `internal/delivery/signing` | AWS request signing for providers that talk to AWS. |
| `internal/alert/*` | One adapter per provider: builds the payload, sends it through transport. |
| `internal/alert/catalog` | Statically links provider adapters and constructs them. |
| `internal/provider/catalog` | Provider identities and metadata. |
| `internal/health` | `/healthz`, `/readyz`, `/availabilityz`, `/health` and `/metrics`, plus `/status` when `healthCheck.statusEndpoint` is on. |
| `internal/status` | The read-only report that `/status` serves. |
| `internal/metrics` | The process-wide Prometheus registry; labels are always bounded. |
| `internal/config` | Loads, normalizes and validates configuration. |
| `internal/config/crd` | Watches `KwatchConfig` resources, including late installs. |
| `internal/rbac` | Audits the permissions kwatch uses and reports what is missing. |
| `internal/kubeclient` | Kubernetes client construction and informer helpers. Only `app` constructs clients. |
| `internal/redact` | Removes secrets from text before kwatch keeps or sends it. A leaf. |
| `internal/format`, `internal/ratelimit`, `internal/clock` | Pure text helpers, the rate-limit error type, the time dependency. |
| `internal/audit` | One JSON line per incident decision, for offline scoring. |
| `internal/replay` | Records and replays observations on a simulated clock. Test tooling; only `internal/flight` imports it in production code, for its log format and sanitizer. |
| `internal/flight` | The flight recorder: a bounded, sanitized ring of the observation stream in the state file, and `kwatch replay-export`. |
| `internal/selfcheck` | Per-rule counts of whether recovery followed a change to the named cause. Display only. |
| `internal/scenarios` | Labelled scenario library and the scorecard gate. Tests only. |
| `internal/scorecard` | Measures notification quality against the production goals. |
| `internal/feature`, `internal/heartbeat`, `internal/telemetry`, `internal/upgrader`, `internal/version` | Feature identifiers, the external heartbeat ping, adoption telemetry, release check, build version. |
| `internal/architecture` | Tests that enforce repository layout. No production code. |

## Import direction

The flow is the dependency direction. Lower layers never import upper ones.

```text
inventory → detection → rootcause → incident → notification/compose
          → pipeline → app
```

The script enforces these rules:

- `inventory` imports none of detection, rootcause, incident, notification,
  pipeline, storage, scope, delivery, alert, app, health or rbac. Only
  `inventory/kube` may import Kubernetes libraries.
- `detection` does not import rootcause, incident, notification, pipeline,
  storage, scope, delivery, alert or app. `rootcause` does not import
  incident or anything above it. `incident` does not import notification,
  pipeline, storage, scope, delivery, alert or app. `notification/compose`
  does not import pipeline, storage, scope, delivery, alert or app.
- `storage` imports no domain package. `scope` imports nothing at or above
  rootcause, and `rbac` nothing at or above detection.
- `pipeline` does not import delivery, alert, app, health or config. Only
  `app` (and `replay`, which is test tooling) imports `pipeline`. Its
  subpackages `announce`, `coverage` and `investigate` never import
  `pipeline` or each other; the pipeline wires them.
- Leaf packages (`notification`, `format`, `redact`, `ratelimit`,
  `detection/reasons`) import no upper layer.
- `alert/*` and `delivery` import no domain package, no `kube`, no
  Kubernetes client library and not `app`. Providers never use `net/http`
  directly; they call `delivery/transport`, which decides status
  classification, timeout and retry.
- Clients are built in `internal/kubeclient` and `internal/app` only. Dynamic
  informers are built only in `dynamicwatch`. `config.Config` is read only
  by `config`, `app` and commands. Production code does not call `time.Now`
  (use an injected clock), `http.DefaultClient`, `net.DefaultResolver`,
  `context.WithValue` or dynamic Prometheus label values.
- Retired packages (`controller`, `insight`, `persistence`, `handler`,
  `monitor`, `model`, `message` and others listed in the script) must not
  return.

## Where to put new code

| You want to | Put it in |
| --- | --- |
| Detect a new abnormal state | `detection/detectors`, reason in `detection/reasons` |
| Teach root cause a new way failure spreads | A row in `rootcause/explain/table_rows*.go` |
| Watch a new kind or add a source | `inventory/kube` (schema, registration, watch mode) |
| Say a new fact in the message | A sentence writer in `notification/compose` |
| Prove a behavior end to end | A labelled scenario in `internal/scenarios` |
| Add a provider | `internal/alert/<provider>`, catalog metadata, transport tests |
| Change the state file | `internal/storage`, bump `SchemaVersion` |

See [Contributing](/contributing) for the full guides.
