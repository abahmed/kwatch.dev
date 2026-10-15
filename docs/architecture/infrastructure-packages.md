---
sidebar_position: 4
title: Infrastructure Packages
description: How kwatch stores state in one file, serves its endpoints, uses a single replica with a state lock, and guarantees at-least-once delivery.
keywords: [kwatch, kubernetes, architecture, infrastructure, storage, health, metrics, state lock]
pagination_prev: architecture/correlation-and-alerting
pagination_next: architecture/data-flow
---

# 🧱 Infrastructure

These parts connect kwatch to the volume, the health endpoints and the
providers. Persistence on disk (everything in the Storage section) is a
<span className="kw-pro">Pro</span> capability. The Community edition keeps incidents and history in
memory, so it starts from a fresh baseline after a restart.

## Storage

With Pro, state is one bbolt file, `state.db`, on the volume at `/var/lib/kwatch`. It has
one bucket per data class:

| Bucket | Holds | Kept |
| --- | --- | --- |
| `incidents` | The latest record per incident ID | Resolved ones for 7 days |
| `changes` | Full change records (actor, fields, revision, times) of workloads, config, services, policy and nodes, in one time-ordered stream | 7 days, at most 8 MiB; the last 24 hours reload at start |
| `baselines` | Rolling per-workload statistics over 7 days: restarts, readiness, memory, Warning events | Dropped 7 days after the workload is gone |
| `evidence` | Log excerpts and termination messages | 30 days, at most 128 MiB |
| `timeline` | Health transitions, changes, events, decisions | 7 days, at most 32 MiB |
| `fingerprints` | Last seen digest per object | No expiry |
| `state` | Cluster identity, version, startup and telemetry markers (with the pending digest and what digests listed in full today), each workload's last healthy time, the flight recorder's pseudonym salt, and the 7-day counts behind the cause self-check and the unexplained list in `/status` | No expiry; a healthy time lasts 7 days; the counts hold 7 days |
| `flight` | The flight recorder: sanitized, compressed batches of what the sources observed (names hashed, no messages), exported with `kwatch replay-export` | 48 hours, at most 64 MiB |
| `threads` | Provider thread IDs, so updates stay in one conversation | No expiry |
| `outbox` | Delivery jobs not yet accepted by a provider | Until accepted; at most 2048 jobs, none older than 24 hours |

A compactor off the decision loop enforces retention and a total size cap of
512 MiB of logical data (keys and values), of which evidence may use 128 MiB,
the timeline 32 MiB, the changes 8 MiB and the flight recording 64 MiB. When
most of the file is free pages, the compactor rewrites the file while running
(a copy of the live data renamed over the original; writes wait about a
second), so the file follows its content down.
Only history is evicted, oldest first; open incidents, baselines, fingerprints,
state, threads and the outbox are never evicted. The file itself is larger than
its logical data, because bbolt keeps freed pages. When the file is more than a
quarter past the cap, the compactor lowers its target by the excess, and the
next start rewrites the file by copying the live data, if the volume has room
for the copy plus a 64 MiB margin. On an `emptyDir` volume the chart passes the
real size limit (`KWATCH_VOLUME_LIMIT`), so that room is judged against the
limit and not against the node's disk. The default 2Gi volume fits the file and
the temporary copy. Only the Lease holder opens the file for writing, and every
write checks a claim epoch, so a process that lost the Lease cannot overwrite
newer state.

A restart reloads the last 24 hours of change records (the newest 1024) and
each workload's last healthy time into the model, before the sources report,
with the original actors and times. The comparison of fingerprints with the
cluster then adds only what the records do not explain: a change the records
hold for the same object and class, made after the snapshot, wins over
"changed while kwatch was down". A state file without these records restores
as before. Records carry a version, and one of a newer version is skipped.

Reset: if the file has another schema version or bbolt cannot read it, kwatch
renames it to `state.db.corrupt.<UTC time>` (the newest two copies are kept)
and starts fresh. Only structural errors reset: a locked or inaccessible file
fails startup instead. The reset is logged and shown in `/health`. A single
record that does not decode is skipped and counted. There is no migration
before the first stable release. To reset by hand, stop kwatch and delete
`state.db`; the next start
repeats the startup summary and relearns baselines.

## Endpoints

kwatch serves these endpoints and no others. There are no diagnostic, profiling
or user-facing API endpoints.

| Endpoint | Meaning |
| --- | --- |
| `/healthz` | Liveness: the process is alive. |
| `/readyz` | Monitoring readiness: this pod holds the Lease, claimed the state file, finished the initial list of every required source, and delivery is running. |
| `/availabilityz` | The pod takes part in the application lifecycle; used by Deployment rollouts. Not monitoring readiness. |
| `/health` | Optional component state and safe reason codes (unwatched kinds, a failed reset, missing permissions). |
| `/status` (Pro, opt-in with `healthCheck.statusEndpoint`) | Read-only "what is wrong right now": incidents, control plane, upgrade readiness, zones, coverage gaps, the per-rule cause self-check and what kwatch could not explain. Text, or JSON with `?format=json`. |
| `/metrics` | Prometheus metrics with bounded labels. |

## One replica and a state lock

kwatch runs as one replica with the `Recreate` strategy. The state volume is
a PVC. A Kubernetes Lease is only a lock: it guards the state volume during
a rollout or a node move. The state file is fenced by its own epoch counter,
which only the state lock holder claims. The application supervisor starts
the components when the pod holds the state lock and stops them when it is
lost. A required component that fails or stalls removes readiness and the pod
restarts. There is no second replica and no self-failover: if the pod or its
node fails, Kubernetes restarts it and kwatch resumes from the volume. The
lock is still needed with one replica, because an old pod on a node cut off
from the network can run beside its replacement for a while; see
[Production operations](/docs/operations/production-readiness).

## Delivery guarantee

Delivery is at least once, not exactly once. Every queued delivery is written
to the persisted outbox (`outbox` bucket) when a provider queue accepts it and
removed when that provider, or its fallback, accepted it or it was
dead-lettered. After a restart or a crash the next session re-queues what is
left, oldest first, before any new work. The outbox keeps at most 2048 jobs;
past that the oldest job loses its crash protection (it is still sent in this
session), and a job older than 24 hours is dropped at restore. So a message is
not lost across a restart, within those bounds. A send that
was interrupted mid-request may be repeated, because kwatch cannot know
whether the provider received it. If the state lock is lost, nothing more is
sent. Drops are counted by `kwatch_delivery_outbox_dropped_total` and
`kwatch_delivery_dropped_total`.

## Telemetry, update check and heartbeat

- **Adoption telemetry** sends a two-field pseudonymous heartbeat to
  `https://api.kwatch.dev` at most every 7 days. Disable it with
  `telemetry.enabled: false`. See [General configuration](/docs/general-configuration#-minimal-adoption-telemetry).
- **License client** (Pro) activates a key against `https://api.kwatch.dev`,
  renews daily, and tolerates up to 7 days offline.
- **Heartbeat monitor** (Pro) pings an external URL while monitoring is ready;
  see the [heartbeat guide](/docs/heartbeat-monitor-configuration).
