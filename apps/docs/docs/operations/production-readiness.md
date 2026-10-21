---
title: "Run kwatch in production: readiness checklist"
sidebar_label: Production readiness
description: Operating model, health signals, memory sizing, delivery guarantees, and validation for running kwatch reliably on Kubernetes.
sidebar_position: 1
keywords: [kwatch, production, readiness, failover, health, persistence, Kubernetes]
---

# Production readiness

kwatch is designed for a Kubernetes-native, single-writer operating model. Use this page to decide whether an installation is ready for the workload it monitors and to choose the right signal when something fails. It is an operations reference, not a promise of high availability.

## Supported operating model

- kwatch runs **one replica** with the `Recreate` strategy.
- With Pro, state lives in a database file on a `ReadWriteOnce` PVC mounted at `/var/lib/kwatch`. Community keeps state in memory.
- A Kubernetes Lease is only a **lock**: it stops two processes from writing the volume at once. There is no second Pod and no kwatch self-failover; if the Pod or its node fails, Kubernetes restarts it.
- There is no high availability in v1, in Community or Pro. See [Replication and failover](/operations/replication-and-failover) and [Is kwatch working?](/operations/is-kwatch-working).

Notification delivery is at least once, not exactly once; provider retries and a restart can produce a duplicate.

## Operational targets

Initial targets for normal cluster conditions, not guarantees: readiness within 120 seconds after a healthy startup, and graceful shutdown within 45 seconds (the deployment allows 60 seconds). After a hard node failure, plan for up to about 7 to 8 minutes without monitoring (see [Replication and failover](/operations/replication-and-failover#node-failure-the-real-monitoring-gap)).

## Health signals

| Endpoint | Meaning |
| --- | --- |
| `/healthz` | Process liveness. |
| `/readyz` | The Pod holds the Lease, has claimed the state file, every source finished its initial list, and delivery is running. |
| `/availabilityz` | Deployment availability, used for rolling updates. Not monitoring readiness. |
| `/health` | JSON with overall status, state lock status, component states, coverage and bounded reason codes. |
| `/metrics` | <span className="kw-pro">Pro</span> Prometheus metrics with bounded labels. Off in Community. |
| `/status` | Opt-in (`healthCheck.statusEndpoint: true`), read-only list of open incidents. Short plain text in Community; full text and JSON is <span className="kw-pro">Pro</span>. |

kwatch serves no other endpoints: there are no profiling or test-alert endpoints. `/status` lists object names to anyone who can reach the health port, so keep that port inside the cluster and read it with `kubectl port-forward`. Health responses carry safe reason codes, not raw errors. The full reason vocabulary is in [General configuration](/general-configuration#-health-reasons).

An unavailable optional API is degraded in `/health` and does not make kwatch unready. Readiness is withdrawn while a required source (Pods, Nodes) is unavailable, for example after its permission is revoked, and returns when it recovers.

## Shutdown and recovery

On termination readiness drops at once, sources stop, the final incident snapshot is written, queued alerts are sent (or dead-lettered once the drain deadline passes, keeping their outbox records for the next start) and the state file is closed. A required component failure makes the Pod unready and lets Kubernetes restart it. The heartbeat monitor <span className="kw-pro">Pro</span> pings only while monitoring is ready, so an external dead man's switch notices a Pod that is up but not monitoring.

With Pro, after a restart kwatch restores open incidents from the state file, so they are not announced again, and records changes made while it was down. See [Persistence and recovery](/operations/persistence-recovery). Without a license, state is in memory and a restart takes a fresh baseline.

## Memory and CPU

The default memory limit is 512Mi (the Go soft limit is set to 90% of it) and the default CPU is a 100m request with a 500m limit. kwatch holds about 26 KB of live heap per pod; plan for twice that.

| Pods | Memory request and limit |
| --- | --- |
| up to 5,000 | `512Mi` (default; suits about 8,000 realistic pods) |
| 10,000 | `768Mi` |
| 20,000 | `1Gi` |

Raise `resources.requests.memory` and `resources.limits.memory` together, and measure with the `self-health` log line rather than trusting the table at the edges.

## Delivery, queues, and outages

Delivery uses bounded per-provider queues, retries for failures that can succeed (timeouts, 5xx, rate limits), fallbacks and a dead-letter list. Queued deliveries are kept in a persisted outbox (at most 2048 jobs, none older than 24 hours at restore). A provider outage should raise retry and terminal-failure metrics and may produce dead letters; it should not make the process appear dead. Alert on `kwatch_delivery_dropped_total`: it is the difference between "no incidents" and "no deliveries".

## Kubernetes and security review

For production installations, review:

- the read-only ClusterRole and `rbac.mode` (`least-privilege` by default; `full` is opt-in with `--set rbac.mode=full`), see [RBAC and deployment security](/operations/rbac-and-security);
- the state volume: `ReadWriteOnce` block storage, never NFS or `ReadWriteMany`;
- a 60-second termination grace period, probes, and resource requests and limits;
- non-root execution, read-only root filesystem, dropped capabilities and the `RuntimeDefault` seccomp profile (the shipped manifests set these);
- the optional NetworkPolicy: allow egress to the kubelet port (10250), and open any probe, proxy or non-443 provider port you use;
- release image digests rather than mutable tags.

Verify the service account with `kubectl auth can-i` in the target cluster. The `kwatch.sh` installer applies release resources with the documented lock, security, probe, persistence and shutdown settings.

## First-response checklist

When an alert is missing or delayed:

1. Check `/healthz`, `/readyz` and `/health`.
2. Confirm the Pod holds the Lease and that required sources are synced.
3. Check delivery queue depth, retry and failure metrics, and provider status.
4. Check namespace and reason scope, silences, baseline, cooldown and the audit log.

See [Troubleshoot missing alerts](/operations/troubleshooting) for the detailed path.
