---
title: Production readiness
description: Operational guarantees, failure behavior, and validation for running kwatch reliably.
sidebar_position: 1
keywords: [kwatch, production, readiness, failover, health, persistence, Kubernetes]
---

# Production readiness

Kwatch is designed for a Kubernetes-native, single-writer operating model.
Use this page to decide whether an installation is ready for the workload it
is expected to monitor and to choose the right signal when something fails.

## Supported operating model

The default deployment uses two replicas and a Kubernetes Lease:

- Exactly one replica is the active leader.
- The other `N-1` replicas are standbys that run election and health serving
  only. They do not watch resources, process incidents, send notifications,
  or write mutable persistence.
- Scaling from two to five adds takeover capacity, not monitoring throughput.
- One replica is supported for constrained clusters, but it has no Kwatch
  self-failover.
- Spread replicas across failure domains when node loss matters.

The Kubernetes API and Lease are the election authority. Kwatch does not form
its own quorum. This protects against normal process or Pod loss, but cannot
protect against a total Kubernetes API, cluster, node, or network failure.
Notification delivery is not exactly once; provider retries and a leadership
transition can produce a duplicate or require operator review.

## Operational targets

These are initial SLO-oriented targets for normal cluster conditions, not hard
protocol guarantees:

| Signal | Initial target |
| --- | --- |
| Healthy startup to readiness | 120 seconds |
| Leader takeover | 90 seconds |
| Graceful shutdown | 45 seconds |
| Normal persistence restore | 30 seconds |
| Delivery queue growth | Bounded by configured limits |
| Health endpoint responsiveness | Independent of monitor activity |

The deployment reserves at least 60 seconds for shutdown. Measure these targets
in the same cluster size and API-server conditions as the production workload.

## Health signals

| Endpoint | Meaning |
| --- | --- |
| `/healthz` | Process liveness. A leader and a standby can both be live. |
| `/readyz` | The active leader has restored required state and synchronized required sources. |
| `/availabilityz` | Deployment availability for a leader or standby participating in Lease election. |
| `/health` | Safe leadership, component, watcher, source, migration, and degradation state. |
| `/metrics` | Prometheus metrics with bounded labels. |

Diagnostic endpoints such as `/incidents`, `/deadletters`, `/persistence`,
`/informer`, `/kubelet`, `/security`, `/controlplane`, and `/test-alert` are
disabled unless explicitly enabled. When enabled for a production profile,
they require a bearer token. Pprof follows the same rule and is disabled by
default. Public health responses contain safe reason codes, not raw errors,
payloads, URLs, credentials, or Kubernetes object data.

Readiness should be false while the leader is restoring state, waiting for a
required cache, missing a required source, or recovering required persistence.
An unavailable optional API is degraded in `/health` but does not by itself
make an otherwise healthy leader unready.

The application evaluates readiness through one leadership-epoch coordinator.
For an active epoch, all of these required gates must be open: leader role,
startup restore, required controller caches, required source configuration,
required persistence writers, the incident engine, and configured delivery.
A callback from an older epoch cannot reopen readiness after a takeover or
shutdown.

## Leadership loss and recovery

When a leader loses its Lease or a required component fails, it:

1. Marks readiness false.
2. Cancels the active monitoring generation.
3. Stops delivery intake and provider retries.
4. Fences mutable persistence writes.
5. Stops producers and watcher generations, waiting for completion handles
   within bounded deadlines.
6. Performs a final persistence snapshot only when leadership fencing still
   permits it.
7. Exits so Kubernetes can restart it and a standby can take over.

The new leader loads the latest compatible state, produces one startup migration
report, restores incidents, groups, baseline, engine, threads, PVC, and other
supported state, then waits for required cache synchronization before active
processing. It reconciles current objects and reports the monitoring gap from
the last persisted liveness stamp. Kubernetes Events that expired during the
gap cannot be reconstructed and are reported as unknown history rather than
invented evidence.

## Required and optional components

Required startup and runtime components include health serving, Lease election,
state restore, the controller and required caches, incident processing, and
delivery when providers are configured. A required failure removes readiness,
stops active processing, and makes the Pod restart-eligible.

Graphs, status and probe integrations, control-plane checks, kubelet metrics,
RBAC checks, TLS sweeps, CRD watching after initial setup, telemetry, upgrader,
heartbeat, cleanup, and snapshots may be optional. Optional failures are
reported with bounded reason codes and retried with capped backoff while core
monitoring continues. Missing listers always skip detection: they never create
or resolve a synthetic incident.

## Persistence and migration

Restart-critical data is kept in namespace-scoped ConfigMaps. Writes use
optimistic concurrency and bounded conflict retries. Missing state is a safe
first-run condition; corrupt data, malformed schema metadata, and unsupported
future versions are preserved and reported. Required restore failures block
active monitoring and delivery so a restart cannot silently fork incident
state.

Before upgrades:

1. Confirm the current ConfigMaps and their backups are present.
2. Review the migration report in protected diagnostics and logs.
3. Verify the target version's migration and rollback notes.
4. Keep a recoverable backup until the new version is healthy.

For recovery, restore the last known-good ConfigMaps, restart one controlled
leader, and verify readiness, incident identity, and provider delivery before
scaling back to the desired replica count.

## Delivery, queues, and outages

Delivery uses immutable provider generations, bounded queues, shared context-aware
transport, retry classification, fallbacks by stable name, and a dead-letter
ring. A provider outage should increase retry and terminal-failure metrics and
may populate dead letters; it should not make the process appear dead. Queue
saturation drops the arriving job and records the bounded failure signal.

During reconfiguration, a generation moves from `accepting` to `draining` and
then to `stopped` or `failed`. The replacement is not published until the old
generation has stopped. A successful drain is a normal reconfiguration event;
a failed or timed-out drain makes required delivery unavailable and stops active
processing rather than allowing two ambiguous worker generations to run.

Payload limits are explicit per-provider policy. Known protocol limits use
deterministic truncation that preserves the headline, reason, resource identity,
and newest evidence. Providers whose final renderer owns its limit are marked
`provider_owned` instead of receiving an arbitrary universal limit. Complete
payloads and secrets are never written to logs or diagnostics.

Inspect provider status, retry counts, queue saturation, dead letters, and
provider-specific rate limits before changing retry settings. Do not place
credentials or complete provider payloads in logs or diagnostics.

## Kubernetes and security review

For production installations, review:

- two replicas, Lease Role/RoleBinding, and a PodDisruptionBudget with
  `minAvailable: 1` for multi-replica deployments;
- 60-second or longer termination grace, probes, resource requests and limits,
  and topology spread or preferred anti-affinity;
- non-root execution, read-only root filesystem, dropped capabilities, and
  seccomp settings;
- feature-specific RBAC, including the documented Secret access needed by TLS
  and dependency evidence;
- optional NetworkPolicy and restricted diagnostic exposure;
- immutable image tags or, preferably, release image digests.

Use the feature-permission matrix before disabling or enabling monitors. Verify
the service account with `kubectl auth can-i` in the target namespace and
cluster. Helm and raw manifests should expose equivalent election, security,
probe, persistence, and shutdown settings.

## Release and validation checklist

Before calling a release production-ready, run the repository's unit, lint,
architecture, manifest, security, documentation, and race checks. CI or an
operational cluster must additionally test:

- replicas 1 through 5, scale-up and scale-down, standby deletion, and leader
  deletion or process termination;
- API and provider outage/recovery, queue saturation, large event bursts, and
  optional API absence;
- migration, ConfigMap conflict and partial-write recovery, restart, rollback,
  and graceful shutdown;
- RBAC `can-i`, readiness/liveness, node placement, and persisted incident
  identity after takeover.

Kind, Docker, kubectl, real provider outages, large-cluster load, and disaster
recovery are environment-dependent. Do not describe them as locally passed
when those tools or environments are unavailable. Verify release checksums,
image signatures, provenance, SBOMs, and vulnerability policy before rollout.

## First-response checklist

When an alert is missing or delayed:

1. Check `/healthz`, `/readyz`, and protected `/health` diagnostics.
2. Confirm the Pod's Lease role and whether it is the active leader.
3. Check required source and informer synchronization status.
4. Check queue depth, retry/failure metrics, dead letters, and provider status.
5. Check persistence migration or restore status after a restart.
6. Review namespace/reason scope, filters, baseline, cooldown, inhibition,
   grouping, and audit records.

See [Troubleshoot missing alerts](./troubleshooting) for the detailed decision
path.
