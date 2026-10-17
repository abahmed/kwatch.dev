---
title: Runtime architecture
description: How kwatch watches Kubernetes, evaluates findings, manages incidents, and delivers notifications, and where each responsibility sits.
sidebar_position: 1
---

# Runtime architecture

kwatch is a single Kubernetes application. It watches Kubernetes through
sources, evaluates the observations in one decision loop, and turns confirmed
findings into incident decisions that delivery sends to providers.

```text
Kubernetes API / kubelet / probes / logs
      │  observations
      ▼
inventory (objects, links, health, changes)
      │
      ▼
detection ─► rootcause ─► incident ─► notification/compose
      │                                        │
      ├── storage (state.db, Pro)              ▼
      └── audit (Pro)                  delivery ─► providers
```

## The responsibility boundaries

- **Sources** (`internal/inventory/kube`) own clients, queues and cache sync.
  They turn objects into observations. A source that cannot read a resource
  makes that object unknown; it never creates or resolves an incident.
- **Detection** computes health and failure mode per object. Detectors read the
  model and an injected clock only.
- **Root cause** (`internal/rootcause`) chooses the small set of causes that
  explain the failures, from a propagation table and scorers. It is a pure
  function of a snapshot.
- **Incidents** (`internal/incident`) group findings that share a cause and
  decide when people hear about it: announce, update, resolve.
- **Compose** (`internal/notification/compose`) writes one short narrative per
  decision.
- **Delivery** (`internal/delivery`, `internal/alert/*`) owns routing, retries,
  pacing, fallback and the shared outbound transport. Providers only build
  their payload.
- **Storage** (`internal/storage`) is one bbolt file, fenced by an epoch only
  the Lease holder claims. Persistence on disk is a Pro capability; Community
  keeps state in memory.

## Extension rule

Adding a detector or a propagation rule should not require understanding every
provider. Detectors live in `detection/detectors`, a new way for failure to
spread is a row in the propagation table, and a new watched kind is a schema in
`inventory/kube`. See the [contributing guides](/contributing/architecture-tour).
