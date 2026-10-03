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
| `core.pods.oom` | runtime | Detect out-of-memory kills and repeated OOMs | `core.detection.pods` |
| `core.pods.readiness` | runtime | Detect sustained pod readiness failures | `core.detection.pods` |
| `core.pods.restarts` | runtime | Detect crash loops and excessive restarts | `core.detection.pods` |
| `core.detection.workloads` | runtime | Detect workload rollout and execution failures | `none` |
| `core.workloads.rollouts` | runtime | Detect stuck workload rollouts | `core.detection.workloads` |
| `core.workloads.jobs` | runtime | Detect failed Jobs and failed or missed CronJobs | `core.detection.workloads` |
| `core.workloads.pdb` | runtime | Detect PodDisruptionBudgets that block disruption | `core.detection.workloads` |
| `core.workloads.hpa` | runtime | Diagnose HorizontalPodAutoscaler failures | `core.detection.workloads` |
| `core.detection.nodes` | runtime | Detect node readiness, pressure and draining | `none` |
| `core.nodes.usage` | runtime | Detect node resource pressure from kubelet stats | `core.detection.nodes` |
| `core.detection.storage` | runtime | Detect claim, volume and attachment failures | `none` |
| `core.storage.usage` | runtime | Predict volumes filling up | `core.detection.storage` |
| `core.detection.network` | runtime | Detect Service, Ingress and NetworkPolicy failures | `none` |
| `core.detection.admission` | runtime | Detect admission webhook and policy failures | `none` |
| `core.detection.certificates` | runtime | Detect expiring and invalid TLS certificates | `none` |
| `core.detection.quota` | runtime | Detect exhausted ResourceQuotas and LimitRange rejections | `none` |
| `core.detection.custom-resources` | runtime | Detect failing conditions on custom and built-in resources | `none` |
| `core.detection.control-plane` | runtime | Check API server, etcd, DNS, scheduler and controller-manager | `none` |
| `core.detection.probes` | runtime | Run configured HTTP, TCP and DNS checks | `none` |
| `analysis.root-cause` | runtime | Explain each incident by its most likely root cause | `none` |
| `analysis.changes` | runtime | Relate incidents to recent changes and who made them | `analysis.root-cause` |
| `analysis.impact` | runtime | Show which workloads and services an incident affects | `analysis.root-cause` |
| `analysis.investigation` | runtime | Attach a redacted log excerpt to announcements | `none` |
| `incidents.noise-control` | runtime | Settle, merge symptoms and send only material changes | `analysis.root-cause` |
| `incidents.flapping` | runtime | Recognise flapping and routine recurring incidents | `incidents.noise-control` |
| `incidents.startup-summary` | startup | Summarise pre-existing incidents once at cold start | `none` |
| `incidents.state` | startup | Keep incidents and history on disk across restarts | `none` |
| `incidents.downtime-changes` | startup | Report changes made while kwatch was down | `incidents.state` |
| `policy.scope` | runtime | Filter by namespace, reason, selector and silences | `none` |
| `policy.severity` | runtime | Override severity by reason and owner kind | `none` |
| `policy.maintenance` | runtime | Hold incidents for objects under maintenance | `none` |
| `policy.runbooks` | runtime | Attach reason-aware runbook links | `none` |
| `delivery.routing` | runtime | Route incidents to providers by scope | `none` |
| `delivery.threads` | runtime | Update one message thread per incident where supported | `none` |
| `delivery.templates` | runtime | Render operator-selected text templates | `none` |
| `delivery.audit-log` | runtime | Write a JSON line for every incident decision | `none` |
| `security.rbac-audit` | runtime | Report missing permissions | `none` |
