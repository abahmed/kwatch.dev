---
title: Feature reference
description: Generated Kwatch capability catalog and dependencies.
sidebar_position: 3
generated: true
---

# Feature reference

> This page is generated from the Kwatch feature catalog. Feature IDs are
> stable product vocabulary and should not be renamed without a migration.

| Feature ID | Lifecycle | Description | Dependencies |
| --- | --- | --- | --- |
| `core.detection.pods` | runtime | Detect pod and container failures | `none` |
| `core.pods.scheduling` | runtime | Detect pod scheduling failures | `core.detection.pods` |
| `core.pods.pending` | runtime | Detect pods stuck Pending | `core.detection.pods` |
| `core.pods.oom` | runtime | Detect repeated out-of-memory failures | `core.detection.pods` |
| `core.pods.readiness` | runtime | Detect sustained pod readiness failures | `core.detection.pods` |
| `core.pods.restarts` | runtime | Detect excessive container restarts | `core.detection.pods` |
| `core.detection.workloads` | runtime | Detect workload rollout and execution failures | `none` |
| `core.workloads.deployment-rollout` | runtime | Detect stuck Deployment rollouts | `core.detection.workloads` |
| `core.workloads.statefulset-rollout` | runtime | Detect stuck StatefulSet rollouts | `core.detection.workloads` |
| `core.workloads.daemonset-rollout` | runtime | Detect stuck DaemonSet rollouts | `core.detection.workloads` |
| `core.workloads.job-failures` | runtime | Detect failed and suspended Jobs | `core.detection.workloads` |
| `core.workloads.cronjob-failures` | runtime | Detect failed and missed CronJobs | `core.detection.workloads` |
| `core.workloads.pdb-violations` | runtime | Detect PodDisruptionBudget violations | `core.detection.workloads` |
| `core.workloads.hpa-diagnostics` | runtime | Diagnose HorizontalPodAutoscaler failures | `core.detection.workloads` |
| `core.detection.nodes` | runtime | Detect node readiness and resource failures | `none` |
| `core.nodes.conditions` | runtime | Detect node conditions and lifecycle failures | `core.detection.nodes` |
| `core.nodes.resources` | runtime | Detect node resource pressure | `core.detection.nodes` |
| `core.detection.storage` | runtime | Detect persistent storage failures | `none` |
| `core.storage.pvc-usage` | runtime | Detect PVC usage and volume failures | `core.detection.storage` |
| `core.detection.network` | runtime | Detect service and network failures | `none` |
| `core.network.service-endpoints` | runtime | Detect Service and EndpointSlice failures | `core.detection.network` |
| `core.network.ingress-backends` | runtime | Detect Ingress backend failures | `core.detection.network` |
| `core.network.policies` | runtime | Detect NetworkPolicy failures | `core.detection.network` |
| `core.detection.security` | runtime | Detect security and admission failures | `none` |
| `core.security.admission-webhooks` | runtime | Detect admission webhook failures | `core.detection.security` |
| `core.cluster-resources.status` | runtime | Detect cluster resource status failures | `none` |
| `core.security.tls` | runtime | Detect TLS certificate expiry | `core.detection.security` |
| `intelligence.diagnosis.direct` | runtime | Explain the most likely direct cause | `none` |
| `intelligence.diagnosis.dependency-graph` | runtime | Trace related Kubernetes dependencies | `intelligence.diagnosis.direct` |
| `intelligence.diagnosis.impact` | runtime | Estimate affected resources and blast radius | `intelligence.diagnosis.dependency-graph` |
| `intelligence.diagnosis.change-diff` | runtime | Relate incidents to recent changes | `intelligence.diagnosis.direct` |
| `intelligence.diagnosis.timeline` | runtime | Keep a compact incident timeline | `none` |
| `intelligence.diagnosis.confidence` | runtime | Show confidence and supporting evidence | `intelligence.diagnosis.direct` |
| `intelligence.diagnosis.feedback` | runtime | Persist operator feedback for RCA improvement | `intelligence.diagnosis.direct` |
| `incidents.lifecycle.cooldown` | runtime | Suppress repeated notifications during cooldown | `none` |
| `incidents.lifecycle.grouping` | runtime | Group related incidents into one narrative | `none` |
| `incidents.lifecycle.mass-failure` | runtime | Reduce noise during broad failures | `incidents.lifecycle.grouping` |
| `incidents.lifecycle.cascade-suppression` | runtime | Suppress symptoms after a root cause is known | `intelligence.diagnosis.dependency-graph` |
| `incidents.persistence.active` | startup | Restore active incident lifecycle after restart | `none` |
| `incidents.persistence.baseline` | startup | Persist startup baseline state | `none` |
| `incidents.persistence.change-history` | runtime | Persist recent change history | `none` |
| `telemetry.kubelet.summary` | runtime | Read built-in kubelet summary telemetry | `none` |
| `telemetry.cpu.usage` | runtime | Detect CPU usage pressure | `telemetry.kubelet.summary` |
| `telemetry.cpu.throttling` | runtime | Detect container CPU throttling | `telemetry.kubelet.summary` |
| `telemetry.memory.usage` | runtime | Detect memory pressure and overuse | `telemetry.kubelet.summary` |
| `telemetry.storage.usage` | runtime | Detect ephemeral storage and inode pressure | `telemetry.kubelet.summary` |
| `telemetry.pressure` | runtime | Detect cgroup pressure signals | `telemetry.kubelet.summary` |
| `telemetry.network.errors` | runtime | Detect kubelet-observed network errors | `telemetry.kubelet.summary` |
| `telemetry.runtime.errors` | runtime | Detect container runtime error rates | `telemetry.kubelet.summary` |
| `telemetry.metrics-api` | runtime | Read the optional Kubernetes metrics API | `none` |
| `telemetry.adaptive-baseline` | runtime | Adapt bounded thresholds to observed usage | `none` |
| `probes.http` | runtime | Run configured HTTP checks | `none` |
| `probes.tcp` | runtime | Run configured TCP checks | `none` |
| `probes.dns` | runtime | Run configured DNS checks | `none` |
| `probes.services.automatic` | runtime | Derive safe probe targets from services | `none` |
| `probes.latency` | runtime | Detect probe latency regressions | `none` |
| `control-plane.pods` | runtime | Observe control-plane component pods | `none` |
| `control-plane.api.health` | runtime | Check Kubernetes API health endpoints | `none` |
| `control-plane.api.latency` | runtime | Measure Kubernetes API latency | `control-plane.api.health` |
| `control-plane.scheduler` | runtime | Observe scheduler health | `control-plane.pods` |
| `control-plane.controller-manager` | runtime | Observe controller-manager health | `control-plane.pods` |
| `control-plane.etcd` | runtime | Observe etcd health signals | `control-plane.api.health` |
| `cluster-resources.status` | runtime | Observe status conditions on cluster resources | `core.cluster-resources.status` |
| `cluster-resources.crd-discovery` | startup | Discover supported custom resources dynamically | `none` |
| `security.rbac.audit` | runtime | Report missing permissions and RBAC drift | `none` |
| `security.tls` | runtime | Monitor configured Kubernetes TLS secrets | `none` |
| `security.audit-log` | runtime | Write structured incident audit records | `none` |
| `delivery.escalation` | runtime | Escalate incidents through alert tiers | `none` |
| `delivery.templates` | runtime | Render operator-selected alert templates | `none` |
| `delivery.runbooks` | runtime | Attach reason-aware runbook links | `none` |
