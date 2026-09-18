---
title: Replication and failover
description: How Kwatch replicas share leadership and recover from a failed leader.
sidebar_position: 2
---

# Replication and failover

Kwatch uses a Kubernetes Lease as a single-writer lock. It is not an
active-active controller and replicas do not form an application quorum.

## Replica behavior

| Replicas | Active leaders | Standbys | Limitation |
| --- | --- | --- | --- |
| 1 | 1 | 0 | No Kwatch self-failover |
| `N > 1` | 1 | `N-1` | More takeover capacity, not more throughput |

The leader owns informer watches and queues, monitor workers, incident
processing, provider delivery, and mutable persistence. A standby runs health
serving and Lease election only. Scale-up does not interrupt the leader.
Scale-down is safe when a standby is removed; removing the leader causes a
remaining standby to acquire the Lease after the normal election delay.

Use preferred anti-affinity or topology spread when replicas must survive a
node failure. More replicas cannot protect against loss of the Kubernetes API,
the entire cluster, or the network path to a provider.

## Leadership-loss sequence

The active generation is fenced before leadership is released:

1. Readiness becomes false.
2. Monitoring, watcher, delivery, retry, and persistence contexts are canceled.
3. Completion handles are awaited within bounded shutdown deadlines.
4. A final persistence write is attempted only while leadership is still valid.
5. The old process exits; it cannot send or write after loss.

The replacement leader restores compatible state, reports the startup migration
cycle, waits for required caches, and reconciles current objects. Incident
identity, grouping, cooldown, and baseline state are restored when the persisted
snapshot is available. Expired Kubernetes Events are not reconstructed.

## What to verify

In CI or an operational cluster, verify replicas 1 through 5, leader deletion,
leader process termination, standby deletion, scale-up, scale-down, rolling
upgrade, rollback, and a hung leader. Assert that:

- the Lease has at most one holder;
- exactly one leader becomes ready;
- standbys create no monitoring or delivery side effects;
- persisted incident identity survives takeover;
- old watcher generations stop before replacement starts;
- readiness and safe diagnostics identify the role and epoch.

Local unit tests cannot prove node placement or Kubernetes Lease behavior. Keep
those checks in the Kind workflow or a production-like operational environment.
