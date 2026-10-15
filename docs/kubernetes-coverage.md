---
sidebar_position: 6
title: Kubernetes failure coverage
description: What kwatch can detect across Kubernetes workloads, storage, nodes, services, and cluster signals, and which detectors are Community or Pro.
keywords: [kwatch coverage, Kubernetes monitoring, Kubernetes failures, cluster health]
---

# 🎯 Kubernetes failure coverage

This page answers one question: **what can kwatch notice?** It is a technical
reference for operators who want to understand the signals behind an alert.
For a quick overview, see the [getting started guide](/docs).

kwatch combines informer state, status conditions, Kubernetes Events, logs,
kubelet stats, active probes and (with Pro) incident state kept on disk. It does
not require Prometheus, Grafana, or another external monitoring product. No
single Kubernetes object status proves that application traffic, DNS, or runtime
health is working, so the categories below use different signal sources.

kwatch always watches every supported resource; there are no per-resource
monitor switches. `namespaces`, `reasons` and `silences` filter what is
delivered, not what is watched.

## Community and Pro detectors

The Community edition covers pod and node failures and explains them with a
root-cause headline. Every other detector below is part of kwatch Pro, which is
free during early access. See [Community vs Pro](/docs/editions).

| Area | Signals | Edition |
| --- | --- | --- |
| Pods | Pending and unschedulable pods, crash loops and restarts, OOM kills and repeated OOMs, image pull, config, create, sandbox and lifecycle-hook failures, eviction evidence | Community |
| Pods | Sustained readiness failures | <span className="kw-pro">Pro</span> |
| Nodes | Not Ready, memory, disk, PID and network pressure, draining, lost heartbeat | Community |
| Nodes | Resource pressure read from kubelet stats | <span className="kw-pro">Pro</span> |
| Workloads | Stuck Deployment and StatefulSet rollouts, DaemonSet availability, failed or suspended Jobs, failed or missed CronJobs, PodDisruptionBudgets that block disruption, HPA failures | <span className="kw-pro">Pro</span> |
| Storage | PVC Pending or Lost, PV Released or Failed, resize and attach errors, volumes nearly full | <span className="kw-pro">Pro</span> |
| Network | Services without ready endpoints, Ingress and Gateway backends, NetworkPolicy problems | <span className="kw-pro">Pro</span> |
| Admission | Webhook and admission policy failures, unreachable webhook backends | <span className="kw-pro">Pro</span> |
| Certificates | Expiring and invalid TLS certificates | <span className="kw-pro">Pro</span> |
| Quota | Exhausted ResourceQuotas and LimitRange rejections | <span className="kw-pro">Pro</span> |
| Custom resources | Failure-shaped conditions on built-in and custom resources | <span className="kw-pro">Pro</span> |
| Control plane | API server, etcd, DNS, scheduler and controller-manager checks | <span className="kw-pro">Pro</span> |
| Probes | Configured HTTP, TCP and DNS checks | <span className="kw-pro">Pro</span> |
| Unusual events | Repeated Warning events no detector covers, quoting the event | <span className="kw-pro">Pro</span> |
| Security | RBAC self-audit that reports missing permissions | Community |

The authoritative list is the feature catalog shipped with each release; the
generated [feature reference](/docs/reference/generated/features) shows every
capability ID.

## Object and lifecycle signals

- **Pods:** Pending and every `PodScheduled=False` reason, `DisruptionTarget`,
  Failed/Unknown phases, init containers, waiting and terminated container
  states, restart transitions, CrashLoopBackOff, image pull/config/create/
  sandbox/probe/lifecycle-hook failures, OOM and eviction evidence,
  ephemeral-storage and filesystem messages, and stuck pod deletion finalizers.
- **Deployments, ReplicaSets, StatefulSets, DaemonSets, Jobs and CronJobs:**
  rollout and availability conditions, replica failure, scheduling and taint
  symptoms, Job deadline, backoff and suspension, plus CronJob suspension,
  missed schedules and starting-deadline handling.
- **Nodes:** Ready, memory/disk/PID/network pressure, lease heartbeat
  staleness, node deletion finalizers, bootstrap grace periods, and
  request/allocatable overcommit.
- **Storage:** mounted volume usage, PVC Pending/Lost, resize and attach
  failures, PV Released/Failed, and stuck PVC/PV finalizers.
- **Services and admission backends:** EndpointSlice readiness, missing
  endpoints, port mismatches, LoadBalancer provisioning failures, and webhook
  services with no usable endpoints.
- **Cluster resources:** exhausted ResourceQuota, contradictory LimitRange
  constraints, stuck Namespace termination.
- **Resource-level Events:** recent failure-shaped Warning Events for
  scheduling, storage, autoscaling, admission, discovery and node health are
  correlated to their involved object.
- **Control plane and DNS:** `/readyz` availability and latency checks for the
  API server, and an in-cluster lookup of `kubernetes.default.svc` that tests
  the full service-discovery path from the kwatch Pod. Component absence is
  reported as unsupported rather than as a failure, because managed control
  planes are often hidden from tenant RBAC.
- **Kubelet stats:** kwatch reads node, container and volume usage directly from
  each node's kubelet on port 10250 (RBAC `nodes/stats` and `nodes/metrics`, not
  `nodes/proxy`). A node it cannot reach loses only usage attributes.
- **Active probes** <span className="kw-pro">Pro</span>**:** opt-in HTTP, TCP and
  DNS checks through `activeProbeMonitor`, with latency thresholds on HTTP
  targets. `autoServices` probes ClusterIP Services and `autoDependencies`
  probes endpoints outside the cluster that pod environments name. Both are off
  by default. A target must fail `failureThreshold` consecutive checks before
  alerting and resolves on its first success.

## Watch modes and dynamic status

Every resource the cluster serves that supports list and watch is discovered at
start and again when CRDs or APIServices change. A watch mode bounds memory per
kind: `full` (pods, nodes, workloads, services, storage, policy), `status`
(custom resources and other kinds with status), `metadata` (Leases,
ControllerRevisions, RBAC) and `hashed` (Secrets and ConfigMaps: a hash only,
never the values). Custom resources are watched for failure-shaped `Ready=False`,
`Available=False`, `Degraded=True` and `Progressing=False` conditions
(<span className="kw-pro">Pro</span>), with reasons and messages kept as
evidence.

APIs that are not served or not permitted are reported in `/health` with a
bounded reason (`permission_denied`, `api_unavailable`, `sync_timeout`,
`budget_exceeded`, `object_cap_reached` or `disabled_by_config`) and never
create a fabricated incident. Set `watch.secrets: false` to remove Secret
access; checks that need Secrets then report that they cannot verify. See
[General configuration](/docs/general-configuration#-kubernetes-permissions-and-graceful-degradation).

## Root cause

Root-cause analysis follows owner chains, projected ConfigMaps and Secrets,
image pull Secrets, CSI drivers, Service selectors, EndpointSlices, node Leases,
Gateway and Ingress routes and local PV node affinity. The Community edition
states the most likely root cause in a headline. Full proof, shared-factor
suspects (a node that failing workloads share), who changed what, impact on
workloads and services, and redacted log excerpts are
<span className="kw-pro">Pro</span>.

## Noise and recovery controls

Every edition settles findings into one incident per cause, merges symptoms
under that cause, applies cooldowns and sends only material changes.
Flapping detection, the startup summary and reporting of changes made while
kwatch was down are <span className="kw-pro">Pro</span> and need state on disk;
the Community edition keeps state in memory and takes a fresh baseline after a
restart.

## Important boundary

Kubernetes API objects cannot expose every runtime failure. API latency, packet
loss, service-mesh health, cloud-provider volume state, VPA/KEDA/Cluster
Autoscaler internals and application SLOs need metrics, logs, traces or active
probes. kwatch uses the evidence available through pod and node summaries,
active probes and events; it does not claim that informer status alone covers
these signals. Individual admission denials are returned in the API response but
Kubernetes keeps no watchable object for them, so kwatch detects durable policy
misconfiguration and the resulting object and event symptoms.

See the Kubernetes documentation for [Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/),
[Node status](https://kubernetes.io/docs/reference/node/node-status/),
[PersistentVolumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/),
[EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/),
and [observability](https://kubernetes.io/docs/concepts/cluster-administration/observability/).
