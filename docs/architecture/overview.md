---
sidebar_position: 1
title: Overview
description: High-level kwatch architecture — how the stateless controller watches, detects, correlates, and alerts
keywords: [kwatch, kubernetes, architecture, overview, informers, correlation]
pagination_next: architecture/packages-overview
---

# 🏗️ Architecture Overview

kwatch is a **stateless, single-binary** Kubernetes controller that watches
cluster resources via informers, detects incidents, builds a dependency graph
to explain why they happened, correlates and deduplicates them, and dispatches
alerts through **56 providers**.

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
    │              Handler (process_*.go)               │
    │  Pod filters → container filters → hints          │
    │  (namespace, reason, state, logs, events, ...)    │
    └──────────────────────┬───────────────────────────┘
                           │
                           ▼ Incident
    ┌──────────────────────────────────────────────────┐
    │        Correlation Engine (internal/correlation)  │
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
    │           Alert Manager (internal/alert)           │
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

The source tree under `internal/` organizes the controller, handler, correlation,
insight, config, alert providers, and periodic watchdogs. Each is described in
more detail on the following pages.

---

Continue reading to explore each package, the end-to-end data flow, and the
design decisions that shaped kwatch.
