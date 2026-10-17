---
sidebar_position: 1
title: Overview
description: High-level kwatch architecture - how one decision loop turns Kubernetes observations into objects, health, root causes, incidents and messages.
keywords: [kwatch, kubernetes, architecture, overview, informers, incidents, root cause]
pagination_next: architecture/packages-overview
---

# 🏗️ Architecture overview

This section is for people who want to understand the system, extend it, or
debug an unusual alert. Start here, then follow an alert from detection to
delivery.

kwatch does not forward Kubernetes events to chat. It keeps a model of the
whole cluster, finds what is unhealthy, works out a small set of causes that
explain it, and sends one short message per incident. A node that runs out of
memory and takes forty pods with it is one incident that names the node.

## The pipeline

```text
 Kubernetes API   kubelet stats   probes   pod logs
        │ observations (one common format)
        ▼
 ┌─────────────────────── internal/pipeline ───────────────────────────┐
 │  decision loop (one goroutine, no I/O)                              │
 │                                                                     │
 │  inventory ─► detection ─► rootcause/explain ─► incident            │
 │  objects      health +      chosen causes        settle, update,    │
 │  links        failure mode  that cover the       resolve, flapping  │
 │  changes      per object    failures                  │             │
 │                                                       ▼             │
 │                                       notification/compose          │
 └───────┬───────────────────────────────────────────────┬─────────────┘
         │ bounded workers                               │ Message
         ▼                                               ▼
   investigation (logs, scheduler text)        delivery manager
   storage writer (about once a second)        retries, pacing, fallback
         │                                               │
         ▼                                               ▼
   state.db (one file, Pro)                    providers (55 integrations)
```

One goroutine, the engine loop, owns every decision. Sources submit
observations from any goroutine into a bounded queue. The loop applies them to
the inventory in order, asks the detectors about each touched object, solves
root cause once for the whole batch, and ticks the incident lifecycles. Slow
work (log reads, storage writes, delivery) never runs on the loop. Every loop
iteration reports progress, so a stuck loop shows up as a stall and Kubernetes
restarts the pod.

## The four concepts

| Concept | Meaning |
| --- | --- |
| Object | Anything with identity: every Kubernetes object, plus virtual ones such as a registry, cluster DNS, a zone, a node pool or the API server. |
| Link | A typed, directed relation between objects: owned-by, runs-on, selects, references, mounts, routes-to, serves, pulls. Links say how failure can travel. |
| Health | The state a detector computes for an object: healthy, degraded, failing or unknown, plus a short failure mode such as `CrashLoop` or `MemoryPressure`. |
| Change | A recorded edit to an object: what changed, who changed it, when. Status churn is not a change. |

Unknown is a real state. An object kwatch cannot observe (no permission, API
not served, cache not synced) is unknown. Unknown never causes a blame and
never lets an incident resolve.

## Editions

One binary, two editions (see [Community vs Pro](/editions)). Community
detects pod crashes, OOM, Pending and restarts and node failures, explains them
with a root-cause headline, and keeps state in memory. Pro adds the other
detectors, full proof, who changed what, impact and log excerpts, routing,
threads, templates, persistence on disk and standby replicas. Pro is free during
early access.

## One replica and a state lock

kwatch runs as one replica with the `Recreate` strategy. A Kubernetes Lease is
only a lock that guards the state volume; there is no second Pod and no
self-failover. See [Replication and failover](/operations/replication-and-failover).

Continue reading to explore each package, the end-to-end data flow, and the
design decisions that shaped kwatch.
