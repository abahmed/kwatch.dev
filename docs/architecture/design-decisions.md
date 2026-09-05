---
sidebar_position: 6
title: Design Decisions
description: why kwatch uses stateless Kubernetes informers, dependency graphs, workqueues, circuit breakers, and filter pipelines
keywords: [kwatch, kubernetes, architecture, design decisions, stateless, informers, edge-triggered]
pagination_prev: architecture/data-flow
---

# 🧠 Design decisions

These are the choices that shape kwatch: small, local, predictable, and useful
without a separate monitoring backend.

## Why stateless? No database needed

kwatch uses Kubernetes informers (watch + list) to maintain an in-memory
cache of cluster state. No Prometheus, no Grafana, no TSDB. State persistence
is limited to ConfigMaps for baseline dedup and PVC history. This makes
kwatch a ~20 MB single binary with zero external dependencies.

## Why informer-based, not polling?

Kubernetes informers use watches (long-lived HTTP connections with push
semantics). This gives sub-second detection latency without API server
polling. Configurable `resyncSeconds` (default 0) means purely event-driven
by default, consuming minimal API server resources.

## Why edge-triggered notifications?

Instead of alerting on every reconciliation loop, kwatch computes a
notification signature (`firing|severity` or `resolved|severity`) and only
sends when it changes. This prevents duplicate alerts while the incident is
active and ensures resolution is always delivered exactly once.

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

## Why 16 filters instead of if/else chains?

The filter pipeline pattern allows each detection and enrichment concern to be
independently tested, disabled, or reordered. Each filter is a single Go file
with its own test file. Adding a new detector (e.g., a new container state)
means adding one filter file and registering it — no changes to the handler.

## Why a single binary with no plugins?

All **56 alert providers** are compiled in. There's no plugin system, no
sidecar injection, and no external hooks. This makes
deployment trivial (one pod, one container) and eliminates version
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
1. Receive SIGTERM/SIGINT
2. Stop informers and drain workqueues
3. Wait up to 10s for alert manager to flush pending notifications
4. Save baseline state to ConfigMap with 5s timeout
5. Health server marks not-ready and stops
6. Exit code 0
