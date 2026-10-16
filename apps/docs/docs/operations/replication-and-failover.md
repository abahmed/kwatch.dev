---
title: Replication and failover
description: How kwatch runs as one replica with a state lock, what happens when its Pod or node fails, and how extra replicas wait as standbys.
sidebar_position: 2
---

# Replication and failover

:::info Pro
Running more than one replica (high availability) is part of kwatch Pro, which is free during early access. The Community edition runs one replica. See [Community vs Pro](/docs/editions).
:::

By default kwatch runs **one replica** with the `Recreate` strategy. Its state lives in a file on a PersistentVolumeClaim mounted at `/var/lib/kwatch`. A Kubernetes Lease is used only as a **lock**: it stops two processes from writing the volume at once. There is no second Pod by default and no kwatch self-failover. If the Pod or its node fails, Kubernetes restarts the Pod and kwatch resumes from the volume.

Some names still say "leader" (`KWATCH_LEADER_ELECTION_NAME`, the `<id>-leader` Lease, the `kwatch_leadership_*` metrics). They are kept so existing installs and dashboards keep working, and they all refer to this state lock.

## Why a lock with one replica

Two kwatch processes can overlap for a short time: a node cut off from the network keeps its old Pod running while Kubernetes starts a new one elsewhere, and a Pod stuck in `Terminating` or a manual restart can overlap the next one. The process that loses the Lease stops sending and stops writing, so alerts are not sent twice and the state file has one writer. Only the Lease holder claims the state file, with an epoch counter kept in the file itself, so a superseded process cannot overwrite newer state.

## Replica behavior

| Replicas | Edition | Behavior |
| --- | --- | --- |
| 1 | Community and Pro | One process holds the lock. No kwatch self-failover; Kubernetes restarts the Pod. |
| More than 1 | Pro | One replica holds the lock; the others wait as standbys and take over if the holder loses the Lease. |

On Community, extra replicas still wait as standbys, and kwatch logs that the edition supports one replica and that high availability needs kwatch Pro. A standby does not watch resources, send notifications or write state until it holds the Lease.

## Node failure: the real monitoring gap

A crashed or unreachable node is the slowest case, because Kubernetes decides when the Pod may start elsewhere. Plan for up to about 7 to 8 minutes without monitoring after a hard node failure: about 70 to 80 seconds for node detection and eviction (the chart shortens the default toleration to 30 seconds), then up to about 6 minutes more for a `ReadWriteOnce` volume to detach. The heartbeat monitor (Pro) is the only signal during that window.

If you know the node is really down (powered off, not just partitioned), you can shorten the gap by tainting it out of service:

```sh
kubectl taint nodes <node> node.kubernetes.io/out-of-service=nodeshutdown:NoExecute
```

Remove the taint after the node is repaired or deleted. Never apply it to a node that might still be running. See the [source operations guide](https://github.com/abahmed/kwatch/blob/main/docs/production-operations.md#node-failure-the-real-monitoring-gap) for details.

## Volume requirements

The state volume must be `ReadWriteOnce` block storage (for example EBS, Persistent Disk, Azure Disk, or a local volume). Do not use NFS, EFS, CephFS, Azure Files or any `ReadWriteMany` class: file locks are not reliable over network file systems and the state file can be corrupted.

## When the lock is lost

The process that loses the Lease stops sending and stops writing: readiness drops, queued alerts are dead-lettered (their outbox records stay for the next session), and the process exits so Kubernetes can restart it. The next session restores open incidents from the state file, so they are not announced again, and records changes made while kwatch was down. Kubernetes Events that expired in the gap cannot be reconstructed.

Delivery is at least once, not exactly once. A send interrupted mid-request may repeat after a restart.

During a rolling update, `/availabilityz` lets a Pod waiting for the lock count as available so the update can progress; `/readyz` remains the monitoring contract.

## Community and in-memory state

Persistence on disk is part of kwatch Pro. Without a license kwatch keeps state in memory: after a restart it quietly takes a fresh baseline, so existing failures are not re-sent and only new ones, or ones that get worse, alert. See [Persistence and recovery](/docs/operations/persistence-recovery).
