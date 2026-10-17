---
title: Persistence and recovery
description: Where kwatch keeps its state, what is retained, how it recovers after a crash or schema change, and what the Community edition keeps in memory.
sidebar_position: 3
---

# Persistence and recovery

:::info Pro
Keeping incidents and history on disk across restarts is part of kwatch Pro, which is free during early access. The Community edition keeps state in memory. See [Community vs Pro](/editions).
:::

With Pro, kwatch stores restart-critical state in one transactional database file, `/var/lib/kwatch/state.db`, on a PVC. It is not stored in ConfigMaps. The file is created with owner-only permissions and holds one bucket per data class: incidents, changes, baselines, evidence, timeline, object fingerprints, lifecycle state, provider thread IDs, the delivery outbox and the flight recording.

Without a license (Community), kwatch keeps state in memory. After a restart it takes a fresh baseline, so existing failures are not re-sent.

## Retention

| Data | Retention |
| --- | --- |
| Changes | 7 days, at most 8 MiB |
| Timeline | 7 days, at most 32 MiB |
| Flight recording | 48 hours, at most 64 MiB |
| Evidence | 30 days, at most 128 MiB |
| Resolved incidents | 7 days after resolution |
| Baselines | Dropped 7 days after their workload is gone |
| Delivery outbox | Until a provider accepts the job; at most 2048 jobs, none older than 24 hours at restore |
| Open incidents, fingerprints, state, threads | No expiry |

The logical size of the store is capped at 512 MiB by default. Over the cap, the oldest entries are deleted first across evidence, timeline, changes and resolved incidents. Open incidents, baselines, fingerprints, state, threads and the outbox are never evicted; if they alone keep the store over the cap, `/health` shows `state-store-size` as degraded with `storage_over_cap`. Retention and caps are fixed in this release.

## Schema changes reset the store

There are no migrations. When the state file has another schema version, or cannot be read, kwatch renames it to `state.db.corrupt.<UTC time>` (the newest two copies are kept), creates a fresh store and continues. It starts cold and sends one startup summary; open incidents are re-announced once. After a schema change the delivery outbox and thread IDs are copied into the fresh file so queued pages and resolves are still sent. The reset appears on `/health` as the degraded `state-store` component with reason `storage_reset` and is counted by `kwatch_storage_resets_total`; it does not affect readiness. A file locked by another process is not reset: startup fails and Kubernetes retries.

## After a crash

A kill at any moment (SIGKILL, OOM, node loss) leaves a file that opens at the next start. Every incident and change write is one transaction: it is there whole or not at all, and open incidents come back open. A message accepted by a provider just before a crash may be sent once more at the next start, with the same conversation key so a thread or paging alert treats it as the same one.

## Reset or recover

The state file can be removed to reset kwatch: it then starts cold and sends one startup summary. To recover, scale the Deployment to zero, restore or remove the file on the volume, and start one replica. Open incidents are restored from the file, and kwatch compares saved object fingerprints with the live cluster to record changes made while it was down.

If a copy is wanted before an upgrade, copy `/var/lib/kwatch/state.db` from the volume while the Pod is stopped. See [Replication and failover](/operations/replication-and-failover) for the volume requirements.

Never assume a notification was delivered exactly once. Delivery is at least once; use incident state, the audit log, provider logs and dead letters to reconcile.
