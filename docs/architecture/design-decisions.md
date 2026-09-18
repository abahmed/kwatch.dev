---
sidebar_position: 6
title: Design Decisions
description: why kwatch uses restart-safe Kubernetes informers, Lease election, dependency graphs, workqueues, and filter pipelines
keywords: [kwatch, kubernetes, architecture, design decisions, informers, leader election, edge-triggered]
pagination_prev: architecture/data-flow
---

# 🧠 Design decisions

These are the choices that shape kwatch: small, local, predictable, and useful
without a separate monitoring backend.

## Why Kubernetes-native state instead of a database?

kwatch uses Kubernetes informers (watch + list) to maintain an in-memory
cache of cluster state. It does not require Prometheus, Grafana, or a TSDB.
Restart-critical state is persisted in namespace-scoped ConfigMaps, including
incident, baseline, group, thread, engine, PVC, change, and telemetry state.
This keeps the deployment small and Kubernetes-native while making recovery
explicit instead of pretending that the process is stateless.

## Why one leader and standby replicas?

The default deployment runs two replicas using a Kubernetes Lease. Exactly one
leader starts monitoring, incident processing, delivery, and mutable
persistence; the other replica participates in election and serves health
endpoints. With `N` replicas there is one leader and `N-1` standbys. A single
replica is supported but has no Kwatch self-failover, and more replicas improve
takeover capacity rather than monitoring throughput.

The Lease is authoritative. Leadership loss makes the active instance not
ready, cancels its active generation, fences delivery and persistence, and
lets Kubernetes restart it. This protects against duplicate active processing
under normal transitions, but does not protect against a total Kubernetes API,
cluster, node, or network failure. Notification delivery is not exactly once.

## Why informer-based, not polling?

Kubernetes informers use watches (long-lived HTTP connections with push
semantics). This gives sub-second detection latency without API server
polling. Configurable `resyncSeconds` (default 0) means purely event-driven
by default, consuming minimal API server resources.

## Why edge-triggered notifications?

Instead of alerting on every reconciliation loop, kwatch computes a
notification signature (`firing|severity` or `resolved|severity`) and only
sends when it changes. This prevents duplicate alerts while the incident is
active. Delivery remains at-least-once in the presence of process, provider,
and leadership failures; operators should not treat notifications as
exactly-once.

## Why not use an LLM / cloud AI?

kwatch deliberately does **not** call an LLM API. Each crash alert is explained by a
deterministic **insight engine** that walks an in-memory **dependency graph** of the cluster —
mapping each pod to its node, owner, ConfigMaps, Secrets and PVCs, and what points at them.
It produces a stable, auditable, plain-English **cause** ("node may be unhealthy", "referenced
Secret may have changed"), **impact** ("12 pods, affecting 2 services"), and **what-changed**
hint — with zero data leaving the cluster, no API keys, no per-call cost, and no latency or
vendor dependency.

## Why per-resource informers with separate workqueues?

Each resource type (pods, nodes, deployments, etc.) gets its own informer and
workqueue. This prevents a slow deployment reconcile from blocking a pod
crash alert. CPU/memory cost scales linearly with enabled informers, but the
isolation provides reliable detection latency for critical pod issues.

## Why circuit breakers everywhere?

Alert providers and ConfigMap state operations have circuit breakers. Three
consecutive failures trigger a 60-second cooldown.
This prevents cascade failures when, for example, a Slack webhook is down —
kwatch stops hammering it and moves on to other providers.

## ConfigMap-based state with optimistic concurrency

Baseline and PVC state are stored in ConfigMaps (free, native Kubernetes
resource). Optimistic concurrency (resourceVersion conflict detection) with
retries prevents races across worker goroutines. The 1 MB ConfigMap limit is
managed with gzip compression and hard caps (20000 entries / ~1,032,192
bytes, reserving 16 KB safety margin).

## Why family policy plus enrichment instead of a handler god object?

Pod monitoring has two different kinds of work. Pure state decisions need
determinism, an injected clock, and configuration; event lookup, owner
resolution, kubelet logs, and suppression evidence need listers or a client.
`internal/monitor/pod/policy` owns the first kind, while
`internal/monitor/pod/enrichment` owns the second. This keeps policy
tests fast and makes I/O dependencies visible.

Rules stay independently testable and are registered in the Pod family. A new
container-state rule changes `monitor/pod/policy`, while a new enrichment
source changes the enrichment boundary. Neither requires provider or incident
lifecycle changes, and the controller remains an infrastructure coordinator
rather than a second policy engine.

## Why a single binary with no plugins?

All **56 alert providers** are compiled in. There's no plugin system, no
sidecar injection, and no external hooks. This makes
deployment trivial (one small container per replica) and eliminates version
mismatch issues between components.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 1 | General error (config load failure, runtime error) |
| 137 | OOM killed (SIGKILL) |
| 139 | Segmentation fault (SIGSEGV) |
| 143 | Graceful shutdown (SIGTERM) |
| 255 | Exit status out of range |

Graceful shutdown sequence:
1. Mark readiness false and stop accepting new work.
2. Cancel active monitoring and stop producers and watcher generations.
3. Stop delivery intake and drain or cancel provider workers.
4. Wait for persistence writers, then perform one bounded final snapshot when
   leadership fencing still permits it.
5. Stop health serving and exit.

The deployment reserves at least 60 seconds for this bounded shutdown. Required
component failures are observable and cause a restart-eligible exit; optional
component failures are reported as safe degradation and retried with bounded
backoff.
