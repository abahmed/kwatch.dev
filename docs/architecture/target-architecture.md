---
title: Runtime architecture
description: How kwatch watches Kubernetes, evaluates findings, manages incidents, and delivers notifications.
sidebar_position: 1
---

# Runtime architecture

Kwatch is a single Kubernetes application built around informer-backed
reconciliation. It watches Kubernetes resources, evaluates observations, and
turns confirmed findings into incident lifecycle decisions.

```text
Kubernetes API
      │
      ▼
Informers and listers
      │
      ▼
Controller pipelines and workqueues
      │
      ▼
Observations and monitor findings
      │
      ▼
Incident lifecycle engine
      │
      ├── persistence
      ├── audit
      ├── insight
      └── delivery providers
```

## The responsibility boundaries

### Controllers

Controllers watch resources, enqueue keys, reconcile cached state, and report
retryable errors. They do not decide how an incident is grouped or which
notification provider receives it.

### Observations

The observation layer converts Kubernetes objects into a consistent domain
representation. It owns resource identity, owner resolution, labels, status,
and evidence extraction that is common to multiple monitors.

### Monitors

Monitors detect facts such as a failed container, a stuck rollout, or an
unhealthy endpoint. A monitor returns structured findings. It does not send a
notification or write incident state.

For the Pod family, deterministic rules live in `internal/monitor/pod/policy`.
They receive configuration and an injected clock only. Event, owner, log, and
suppression enrichment is implemented in `internal/monitor/pod/enrichment` and
orchestrated by `internal/monitor/pod`.

### Incident engine

The incident engine owns lifecycle decisions:

1. Baseline handling.
2. Attribution.
3. Cooldown.
4. Identity.
5. Announcement.

This ordering is intentional. Attribution happens before cooldown so a
cooling-down symptom can still be counted against its owning workload or
shared dependency.

### Insight engine

The insight engine analyzes dependencies, recent changes, probable causes, and
impact. It explains an incident but does not decide whether the incident is
emitted.

### Delivery

Delivery routes lifecycle events to configured providers. Shared transport code
owns timeouts, status classification, retry behavior, rate limits, and
redaction. Individual providers only build their provider-specific payloads.
The composition root owns the configured outbound HTTP client and injects it
into SDK-backed providers; provider packages do not reach into Kubernetes
client setup.

### Persistence

Persistence stores restart-critical state independently from the in-memory
incident model. Persisted data has an explicit format version and migration or
recovery behavior.

## Extension rule

Adding a monitor should not require understanding every provider. A new monitor
has a descriptor, explicit application wiring, configuration and validation,
tests, metrics, documentation metadata, and an operator guide where the
feature introduces a new failure mode.

The monitor registry describes capabilities. It is not a hidden service
locator; runtime construction remains explicit in the application composition
root.

## Architecture migration

The codebase is moving from broad implementation names to domain names:

| Transitional package | Domain boundary |
| --- | --- |
| `controller.RuntimeSet` | controller-to-family wiring boundary |
| `monitor/pod/enrichment` | Pod event, owner, log, and suppression enrichment |
| `correlation` configuration | incident lifecycle configuration (external name preserved) |
| `alert` | static provider adapters and catalog construction |
| `state` | persisted data and migration vocabulary |

Internal compatibility seams are not production extension points. External
configuration and persisted data remain compatible through explicit validation,
versioned migration, backups, and round-trip tests.
