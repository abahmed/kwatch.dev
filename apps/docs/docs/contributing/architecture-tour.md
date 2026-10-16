---
title: Architecture tour
description: A practical guide to the kwatch codebase for new contributors - the pipeline, the package map, and where a change should go.
sidebar_position: 1
---

# Architecture tour

Start with the runtime flow rather than opening every package:

```text
observation → detection → root cause → incident → message → delivery
```

Read the [architecture overview](/docs/architecture/overview) for behavior and
the [core packages](/docs/architecture/packages-overview) page for the full
package map and import rules.

## Repository map

| Area | Responsibility |
| --- | --- |
| `cmd/kwatch` | Thin command entry point |
| `internal/app` | Composition root and process lifecycle: clients, Lease, supervision, readiness, shutdown |
| `internal/inventory` | In-memory model of the cluster: objects, links, attributes, changes |
| `internal/inventory/kube` | Kubernetes objects to observations: schemas, discovery, watch modes, kubelet stats, probes, logs |
| `internal/detection` | Detectors that turn object state into health and failure mode |
| `internal/rootcause` | Propagation table, scorers and the solver that chooses causes |
| `internal/incident` | Groups findings into incidents; announce, update, resolve |
| `internal/notification` | Provider-neutral message; `compose` writes the note |
| `internal/pipeline` | The decision loop, bounded workers, downtime reconciliation |
| `internal/storage` | The bbolt state file with epoch fencing |
| `internal/delivery`, `internal/alert/*` | Routing, retries, fallback, transport and one adapter per provider |
| `internal/health`, `internal/status` | Endpoints and the `/status` report |
| `internal/config` | Loading, defaults and validation |
| `internal/feature`, `internal/license` | Feature identifiers with their Community or Pro tier, and the license client |
| `internal/rbac` | Permission auditing |

## Where should a change go?

- A new abnormal state: a detector in `internal/detection/detectors`
  ([Add a monitor](/docs/contributing/adding-monitor)).
- A new way failure spreads: a row in the propagation table.
- A new watched kind: a schema in `internal/inventory/kube`.
- A new fact in the message: a sentence writer in `notification/compose`.
- A provider: `internal/alert/<provider>` ([Add a provider](/docs/contributing/adding-provider)).
- A state-file change: `internal/storage`, bump `SchemaVersion`.

Keep clients, queues and cache sync in the source. Detectors and rules see only
the model and an injected clock. Do not add a method to a universal interface;
add a small function or table row instead. Avoid adding business logic to
`internal/app`.

## Runtime boundaries to preserve

- Unknown is a real state. A source that cannot read a resource makes the
  object unknown; it never creates or resolves an incident.
- One goroutine makes every decision and does no I/O. Slow work runs on bounded
  workers.
- kwatch runs one replica; the Lease is a lock for the state volume, not a
  failover mechanism. Extra replicas wait as standbys (Pro).
- Production code does not call `time.Now`, `http.DefaultClient` or the default
  resolver; use the injected clock and the shared transport.

## Test organization

Name tests after behavior and split large test files by responsibility, with
shared setup in `fixtures_test.go`. Use fake clocks and fake clients, not
sleeps. Run `make verify` before handing off, and `make verify-focused
PKGS="./internal/foo"` during work.

## A useful debugging path

When an alert is missing, inspect the system in this order:

1. Was the source for the kind synced and permitted (`/health` coverage)?
2. Did the detector produce a finding for the object?
3. Was the finding in scope, not silenced and not held?
4. Did the incident settle and decide to announce?
5. Did delivery route it and did the provider accept it?
