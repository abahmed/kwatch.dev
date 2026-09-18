---
sidebar_position: 1
title: Overview
description: High-level kwatch architecture — how the restart-safe controller watches, detects, manages incidents, and alerts
keywords: [kwatch, kubernetes, architecture, overview, informers, incidents, leader election]
pagination_next: architecture/packages-overview
---

# 🏗️ Architecture overview

This section is for people who want to understand the system, extend it, or
debug an unusual alert. Start here, then follow the alert path from detection
to delivery.

kwatch is a **restart-safe, single-binary** Kubernetes controller that watches
cluster resources via informers, detects incidents, builds a dependency graph
to explain why they happened, correlates and deduplicates them, and dispatches
alerts through **56 providers**. Restart-critical state is persisted in
namespace-scoped ConfigMaps.

The default deployment runs two replicas with Kubernetes Lease election. One
replica is the active leader; the other is a standby that serves health
endpoints and participates in election. Only the leader watches resources,
delivers notifications, or writes mutable state. A one-replica deployment is
supported but has no Kwatch self-failover.

---

## High-Level Architecture

```
                    ┌─────────────────────────────────────┐
                    │         Kubernetes API Server        │
                    └────────┬────────┬────────┬───────────┘
                             │        │        │
               ┌──────────────┘   ┌────┘   ┌────┘
               ▼                  ▼        ▼
┌───────────────────────┐  ┌──────────┐  ┌────────────────┐
│  Pod Informer         │  │Node Inf. │  │Deploy/Job/DS/  │
│  (events, secrets)    │  │          │  │CJ/HPA Inf.     │
└──────────┬────────────┘  └────┬─────┘  └───────┬────────┘
           │                    │                 │
           ▼                    ▼                 ▼
    ┌──────────────────────────────────────────────────┐
    │        Monitor families + direct runtimes          │
    │  policy → enrichment → observations → hints        │
    └──────────────────────┬───────────────────────────┘
                           │
                           ▼ Incident
    ┌──────────────────────────────────────────────────┐
    │        Incident Engine (internal/incident)        │
    │  • Incidents keyed by owner (create/update/resolve)│
    │  • Insight engine: cause, impact, what-changed    │
    │  • Dependency graph (pod→node/owner/config)       │
    │  • Mass-failure detection (30% blast radius)       │
    │  • Smart grouping + cooldown + escalation          │
    │  • Node inhibition                                 │
    │  • Resolve hold-down (flap dampening)             │
    └──────────────────────┬───────────────────────────┘
                           │
                           ▼ Enriched Incident
    ┌──────────────────────────────────────────────────┐
    │           Delivery Manager (internal/delivery)    │
    │  • 56 providers, one report for all               │
    │  • Non-blocking fan-out                           │
    │  • Retry (only retryable failures)                 │
    │  • Fallback provider                              │
    │  • Dead-letter queue                              │
    └──┬───────────┬───────────┬───────────┬────────────┘
       ▼           ▼           ▼           ▼
    ┌──────┐  ┌────────┐  ┌───────┐  ┌──────────┐
    │Slack │  │Discord │  │Email  │  │Webhook   │  ...56 providers
    └──────┘  └────────┘  └───────┘  └──────────┘
```

The source tree under `internal/` organizes the controller, monitor families,
incident engine, insight, config, delivery providers, and periodic watchdogs.
Each is described in
more detail on the following pages.

---

Continue reading to explore each package, the end-to-end data flow, and the
design decisions that shaped kwatch.
