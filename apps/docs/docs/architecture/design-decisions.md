---
sidebar_position: 6
title: Design Decisions
description: why kwatch uses informers, one decision loop, a state lock instead of failover, a local state file, and deterministic root cause
keywords: [kwatch, kubernetes, architecture, design decisions, informers, state lock, root cause]
pagination_prev: architecture/data-flow
---

# 🧠 Design decisions

These are the choices that shape kwatch: small, local, predictable, and useful
without a separate monitoring backend.

## Why a local state file instead of a database service?

kwatch uses Kubernetes informers (watch + list) to maintain an in-memory
model of cluster state. It does not require Prometheus, Grafana, or a TSDB.
With Pro, restart-critical state (incidents, changes, baselines, provider
threads, the delivery outbox) is kept in one transactional file on a PVC, not
in ConfigMaps. The Community edition keeps state in memory. This keeps the
deployment small while making recovery explicit instead of pretending that the
process is stateless.

## Why one replica and a state lock?

kwatch runs one replica with the `Recreate` strategy. A Kubernetes Lease is
only a lock: it stops two processes from writing the state volume at once,
which can happen briefly when a node is cut off from the network and
Kubernetes starts a replacement elsewhere. The state file is also fenced by an
epoch counter that only the Lease holder claims. There is no second Pod and no
kwatch self-failover; Kubernetes restarts the Pod and kwatch resumes from the
volume. Extra replicas wait as standbys, which is part of Pro. Notification
delivery is at least once, not exactly once.

## Why informer-based, not polling?

Kubernetes informers use watches (long-lived HTTP connections with push
semantics). This gives sub-second detection latency without API server
polling. `resyncSeconds` (default 300, `0` for purely event-driven) is only a safety
net for lost watch events, not the detection path.

## Why settle and update only on news?

Instead of alerting on every reconciliation, an incident settles for a short
window, is announced once, and is updated only when something new is true. A
refresh of counts, times or ids never sends a message on its own. Delivery
stays at-least-once in the presence of process and provider failures;
operators should not treat notifications as exactly-once.

## Why not use an LLM / cloud AI?

kwatch deliberately does **not** call an LLM API. Each incident is explained by
a deterministic root-cause engine that walks an in-memory graph of links
between objects (pod to node, owner, ConfigMaps, Secrets, PVCs and what points
at them) using a propagation table and scorers. The result is a stable,
auditable explanation, with zero data leaving the cluster, no API keys, no
per-call cost and no vendor dependency.

## Why one decision loop?

Every decision runs on one goroutine with no I/O. Sources, investigation,
storage writes and delivery run on bounded queues and workers around it. This
keeps decisions deterministic and testable, and a stuck loop shows up as a
stall that makes the Pod unready so Kubernetes restarts it.

## Why a state file with an epoch?

Writes are single transactions, so a kill at any moment leaves a file that
opens at the next start. A schema change resets the store rather than
migrating it; the delivery outbox and thread IDs are carried over so queued
pages are still sent.

## Why a single binary with no plugins?

All **55 alert providers** are compiled in. There's no plugin system, no
sidecar injection, and no external hooks. This makes
deployment trivial (one small container) and eliminates version
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
