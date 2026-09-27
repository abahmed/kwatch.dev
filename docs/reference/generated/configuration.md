---
title: Configuration reference
description: Generated configuration fields and defaults for kwatch.
sidebar_position: 1
generated: true
---

# Configuration reference

> This page is generated from the Kwatch configuration catalog. Edit the Go
> configuration source and catalog metadata instead of editing this page.

## Performance

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `workers` | integer | `1` | active | Number of Kubernetes work queues processed in parallel. |
| `resyncSeconds` | integer | `0` | active | Periodic safety resync interval in seconds; zero keeps event-driven mode. |

## Alerts

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `maxRecentLogLines` | integer | `50` | active | Maximum recent log lines attached to an incident. |
| `containerRestartThreshold` | integer | `0` | active | Alert when a container reaches this cumulative restart count; zero disables it. |
| `includeEvents` | boolean | `true` | active | Include recent Kubernetes events in incident messages. |
| `includeLogs` | boolean | `true` | active | Include recent container logs in incident messages. |
| `message.includePrivateLogAddresses` | boolean | `false` | active | Keep private application addresses visible in evidence; credentials remain redacted. |
| `severityByOwnerKind` | json | `{}` | active | JSON map overriding severity by workload owner kind. |
| `severityByReason` | json | `{}` | active | JSON map overriding severity by detected reason. |

## Scope

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `namespaces` | list | `all` | active | Comma-separated namespaces to watch; leave empty to watch every namespace. |
| `namespaceSelector` | string | `empty` | active | Kubernetes label selector used to choose namespaces. |
| `reasons` | list | `all` | active | Comma-separated event reasons to allow or exclude with a leading !. |

## Noise reduction

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `ignoreFailedGracefulShutdown` | boolean | `true` | active | Ignore forceful container termination during an intentional shutdown. |
| `ignoreDisruptionTerminations` | boolean | `true` | active | Ignore pods being deliberately evicted, preempted, or disrupted. |
| `adaptiveThresholds` | boolean | `true` | active | Add bounded grace during normal partial rollouts. |
| `reportStartupBaseline` | boolean | `true` | active | Summarize issues that already existed when kwatch started. |
| `smartGrouping.windowSeconds` | integer | `60` | active | Seconds for grouping related failures into one notification. |
| `smartGrouping.namespaceFanOutThreshold` | integer | `3` | active | Owners failing alike before a namespace fan-out incident is created. |
| `inhibition.nodeSuppressesPods` | boolean | `true` | active | Suppress pod symptoms while their node has an active incident. |
| `silences` | json | `[]` | active | JSON array of scoped silence rules, including eventMessages substring matches for attached Kubernetes Events. |

## Incident memory

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `correlation.window` | integer | `10` | active | Minutes in which related signals are correlated. |
| `correlation.lifecycleInterval` | integer | `1` | active | Minutes between lifecycle and resolution sweeps. |
| `correlation.resolveHoldDown` | integer | `300` | active | Seconds a signal must stay healthy before resolving. |
| `correlation.cooldownMinutes` | integer | `10` | deprecated | Accepted and ignored; the post-resolve cooldown is correlation.window. |
| `correlation.maxBaseline` | integer | `5000` | active | Maximum persisted baseline entries. |
| `correlation.escalation` | json | `{"enabled":true,"tiers":[3,10]}` | active | JSON object controlling restart-count severity escalation. |
| `correlation.renotify` | json | `{"maxPerIncident":3}` | active | JSON object controlling periodic re-notification. |

## Monitors

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `nodeMonitor.enabled` | boolean | `true` | active | Watch node readiness and pressure conditions. |
| `nodeMonitor.sustainedMinutes` | integer | `3` | active | Minutes a node condition must persist before alerting. |
| `pvcMonitor.enabled` | boolean | `true` | active | Watch mounted PVC usage and storage pressure. |
| `pvcMonitor.interval` | integer | `5` | active | Minutes between PVC usage checks. |
| `pvcMonitor.threshold` | float | `80` | active | PVC usage percentage that creates a warning. |
| `pvcMonitor.criticalThreshold` | float | `90` | active | PVC usage percentage that creates a high-severity alert. |
| `pvcMonitor.clearThreshold` | float | `75` | active | PVC usage percentage below which an alert resolves. |
| `rolloutMonitor.enabled` | boolean | `true` | active | Watch Deployments for stuck rollouts. |
| `rolloutMonitor.sustainedMinutes` | integer | `5` | active | Minutes a Deployment may remain unavailable before alerting. |
| `statefulSetMonitor.enabled` | boolean | `true` | active | Watch StatefulSets for stuck updates. |
| `statefulSetMonitor.sustainedMinutes` | integer | `5` | active | Minutes a StatefulSet may remain unavailable before alerting. |
| `daemonSetMonitor.enabled` | boolean | `true` | active | Watch DaemonSets for unavailable pods and scheduling failures. |
| `daemonSetMonitor.sustainedMinutes` | integer | `5` | active | Minutes a DaemonSet may remain unavailable before alerting. |
| `jobMonitor.enabled` | boolean | `true` | active | Watch Jobs for failures and deadline problems. |
| `cronJobMonitor.enabled` | boolean | `true` | active | Watch CronJobs for missed or suspended work. |
| `cronJobMonitor.sustainedMinutes` | integer | `5` | active | Minutes a CronJob condition must persist before alerting. |
| `hpaMonitor.enabled` | boolean | `true` | active | Watch HPAs that remain constrained or maxed out. |
| `hpaMonitor.sustainedMinutes` | integer | `20` | active | Minutes an HPA must remain constrained before alerting. |
| `serviceMonitor.enabled` | boolean | `true` | active | Watch Services with no ready backends. |
| `ingressMonitor.enabled` | boolean | `true` | active | Watch Ingress backend availability. |
| `networkPolicyMonitor.enabled` | boolean | `true` | active | Detect evidence of restrictive NetworkPolicies. |
| `admissionWebhookMonitor.enabled` | boolean | `true` | active | Watch admission webhook availability and failures. |
| `controlPlaneMonitor.enabled` | boolean | `true` | active | Watch API server and control-plane health signals. |
| `clusterResourceMonitor.enabled` | boolean | `true` | active | Watch quota, namespace, and lease lifecycle failures. |
| `clusterResourceMonitor.sustainedMinutes` | integer | `10` | active | Minutes a terminating namespace or quota condition must persist before alerting. |
| `clusterResourceMonitor.nodeLeaseStaleSeconds` | integer | `90` | active | Seconds without a node lease renewal before reporting a stale heartbeat. |
| `heartbeatMonitor.enabled` | boolean | `false` | active | Send a periodic external dead-man heartbeat. |
| `heartbeatMonitor.interval` | integer | `300` | active | Seconds between heartbeat notifications. |
| `scheduleMonitor.enabled` | boolean | `true` | active | Include scheduling delay and unschedulable diagnostics. |
| `oomMonitor.enabled` | boolean | `true` | active | Track repeating OOM kills independently from current pod state. |
| `oomMonitor.threshold` | integer | `3` | active | OOM kills within the window before raising a repeating-OOM incident. |
| `oomMonitor.windowMinutes` | integer | `60` | active | Sliding window used for repeating OOM detection. |
| `pendingPodMonitor.enabled` | boolean | `true` | active | Watch pods that remain Pending. |
| `pendingPodMonitor.threshold` | integer | `300` | active | Seconds a pod may remain Pending before alerting. |
| `notReadyMonitor.enabled` | boolean | `true` | active | Watch running pods that remain not ready. |
| `pdbMonitor.enabled` | boolean | `true` | active | Watch PodDisruptionBudgets that block voluntary disruption. |
| `pdbMonitor.sustainedMinutes` | integer | `5` | active | Minutes a PDB violation must persist before alerting. |
| `nodeResourceMonitor.enabled` | boolean | `true` | active | Watch node overcommit and filesystem/inode pressure. |
| `nodeResourceMonitor.intervalSeconds` | integer | `300` | active | Seconds between node resource checks. |
| `nodeResourceMonitor.cpuWarning` | float | `2.0` | active | CPU requested-to-capacity ratio that raises a warning. |
| `nodeResourceMonitor.cpuCritical` | float | `4.0` | active | CPU requested-to-capacity ratio that raises a critical alert. |
| `nodeResourceMonitor.memWarning` | float | `2.0` | active | Memory requested-to-capacity ratio that raises a warning. |
| `nodeResourceMonitor.memCritical` | float | `4.0` | active | Memory requested-to-capacity ratio that raises a critical alert. |
| `nodeResourceMonitor.filesystemWarningPercent` | float | `90` | active | Node filesystem usage warning threshold. |
| `nodeResourceMonitor.filesystemCriticalPercent` | float | `95` | active | Node filesystem usage critical threshold. |
| `nodeResourceMonitor.inodeWarningPercent` | float | `90` | active | Node inode usage warning threshold. |
| `nodeResourceMonitor.inodeCriticalPercent` | float | `95` | active | Node inode usage critical threshold. |
| `runtimeMetricsMonitor.enabled` | boolean | `false` | active | Use metrics.k8s.io when available for workload usage diagnostics. |
| `runtimeMetricsMonitor.intervalSeconds` | integer | `60` | active | Seconds between runtime metrics checks. |
| `runtimeMetricsMonitor.memoryWarningPercent` | integer | `90` | active | Memory usage warning percentage when metrics.k8s.io is available. |
| `runtimeMetricsMonitor.memoryCriticalPercent` | integer | `95` | active | Memory usage critical percentage when metrics.k8s.io is available. |
| `runtimeMetricsMonitor.cpuWarningPercent` | integer | `90` | active | CPU usage warning percentage when metrics.k8s.io is available. |
| `runtimeMetricsMonitor.cpuCriticalPercent` | integer | `100` | active | CPU usage critical percentage when metrics.k8s.io is available. |
| `clusterAutoscalerMonitor.enabled` | boolean | `true` | active | Watch built-in cluster-autoscaler evidence from Kubernetes resources and events. |
| `tlsMonitor.threshold` | integer | `30` | active | Days before certificate expiry to warn. |
| `tlsMonitor.criticalThreshold` | integer | `3` | active | Days before certificate expiry for a high-severity alert. |
| `controlPlaneMonitor.intervalSeconds` | integer | `30` | active | Seconds between API and control-plane health checks. |
| `controlPlaneMonitor.apiServerLatencyWarningMs` | integer | `1000` | active | API readyz latency warning threshold in milliseconds. |
| `controlPlaneMonitor.failureThreshold` | integer | `2` | active | Consecutive control-plane failures before alerting. |
| `controlPlaneMonitor.recoveryThreshold` | integer | `2` | active | Consecutive successful checks before resolving. |
| `kubeletTelemetryMonitor.enabled` | boolean | `true` | active | Read built-in kubelet telemetry without an agent. |
| `kubeletTelemetryMonitor.intervalSeconds` | integer | `60` | active | Seconds between built-in kubelet telemetry sweeps. |
| `kubeletTelemetryMonitor.persistState` | boolean | `true` | active | Persist telemetry counters across restarts. |
| `kubeletTelemetryMonitor.failureThreshold` | integer | `2` | active | Consecutive kubelet telemetry failures before alerting. |
| `kubeletTelemetryMonitor.recoveryThreshold` | integer | `2` | active | Consecutive successful telemetry checks before resolving. |
| `kubeletTelemetryMonitor.memoryWarningPercent` | float | `90` | active | Kubelet memory usage warning threshold. |
| `kubeletTelemetryMonitor.memoryCriticalPercent` | float | `95` | active | Kubelet memory usage critical threshold. |
| `kubeletTelemetryMonitor.ephemeralStorageWarningPercent` | float | `90` | active | Ephemeral-storage usage warning threshold. |
| `kubeletTelemetryMonitor.ephemeralStorageCriticalPercent` | float | `95` | active | Ephemeral-storage usage critical threshold. |
| `kubeletTelemetryMonitor.cpuWarningPercent` | float | `90` | active | CPU usage warning threshold from kubelet telemetry. |
| `kubeletTelemetryMonitor.cpuCriticalPercent` | float | `100` | active | CPU usage critical threshold from kubelet telemetry. |
| `kubeletTelemetryMonitor.cpuThrottlingWarningPercent` | float | `50` | active | CPU throttling warning threshold. |
| `kubeletTelemetryMonitor.cpuThrottlingCriticalPercent` | float | `75` | active | CPU throttling critical threshold. |
| `kubeletTelemetryMonitor.psiWarningPercent` | float | `20` | active | Pressure stall warning threshold. |
| `kubeletTelemetryMonitor.psiCriticalPercent` | float | `50` | active | Pressure stall critical threshold. |
| `kubeletTelemetryMonitor.networkErrorRateWarning` | float | `1` | active | Network error rate warning threshold. |
| `kubeletTelemetryMonitor.networkErrorRateCritical` | float | `10` | active | Network error rate critical threshold. |
| `kubeletTelemetryMonitor.runtimeErrorRateWarning` | float | `1` | active | Container runtime error rate warning threshold. |
| `kubeletTelemetryMonitor.runtimeErrorRateCritical` | float | `10` | active | Container runtime error rate critical threshold. |
| `tlsMonitor.enabled` | boolean | `false` | active | Watch TLS certificates before expiry; reads certificate Secrets. |
| `activeProbeMonitor.enabled` | boolean | `false` | active | Run explicitly configured application probes. |
| `activeProbeMonitor.intervalSeconds` | integer | `30` | active | Seconds between active probe rounds. |
| `activeProbeMonitor.timeoutSeconds` | integer | `5` | active | Timeout for each active probe. |
| `activeProbeMonitor.failureThreshold` | integer | `3` | active | Consecutive probe failures before alerting. |
| `activeProbeMonitor.recoveryThreshold` | integer | `2` | active | Consecutive successes before resolving a probe incident. |
| `activeProbeMonitor.autoServices` | boolean | `false` | active | Probe discoverable Service ports automatically; opt in to avoid unexpected traffic. |
| `activeProbeMonitor.excludeNamespaces` | list | `[]` | active | Namespaces automatic Service probing skips, for default-deny ingress that does not admit kwatch. |
| `activeProbeMonitor.http` | json | `[]` | active | JSON array of HTTP probe targets with optional paths, headers, and latency limits. |
| `activeProbeMonitor.tcp` | json | `[]` | active | JSON array of TCP probe targets. |
| `activeProbeMonitor.dns` | json | `[]` | active | JSON array of DNS probe targets. |

## Operations

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `upgrader.disableUpdateCheck` | boolean | `false` | active | Disable the update notification. |
| `telemetry.enabled` | boolean | `true` | active | Send the weekly adoption heartbeat. |
| `maintenance.enabled` | boolean | `true` | active | Honor maintenance annotations while preserving cluster-level alerts. |
| `maintenance.annotation` | string | `kwatch.io/maintenance` | active | Annotation that marks deliberate maintenance on a resource. |
| `maintenance.untilAnnotation` | string | `kwatch.io/maintenance-until` | active | Optional annotation containing the maintenance expiry timestamp. |
| `healthCheck.diagnostics` | boolean | `false` | active | Expose diagnostic endpoints such as incidents and test-alert. |
| `healthCheck.pprof` | boolean | `false` | active | Expose Go profiling endpoints; keep disabled in production. |
| `app.clusterName` | string | `empty` | active | Cluster name shown in notifications. |
| `app.proxyURL` | string | `empty` | active | Optional proxy for outbound provider requests. |
| `app.disableStartupMessage` | boolean | `false` | active | Disable the startup notification. |
| `app.logFormatter` | string | `text` | active | Log output format: text or json. |
| `healthCheck.enabled` | boolean | `true` | active | Expose the built-in health endpoint. |
| `healthCheck.port` | integer | `8060` | active | Port for health and optional diagnostic endpoints. |
| `crd.enabled` | boolean | `true` | active | Watch KwatchConfig and supported CRD status conditions; restart kwatch when configuration changes; enabled by the interactive installer after installing the CRD. |
| `crd.failureConditions` | list | `empty` | active | Additional CRD condition rules such as Ready=False or Degraded=True. |
| `crd.graphReferences` | list | `empty` | active | Optional CRD references used by dependency and impact analysis. |
| `auditLog.enabled` | boolean | `true` | active | Write structured incident lifecycle records to the configured audit sink. |
| `auditLog.output` | string | `stdout` | active | Audit output: stdout or a supported output sink. |
| `templates` | json | `{}` | active | JSON map of optional reason-specific message templates. |
| `runbooks` | json | `{}` | active | JSON map of reason-to-runbook URLs. |

## Security

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `app.insecureSkipTLSVerify` | boolean | `false` | active | Skip TLS verification for outbound providers; strongly discouraged. |
| `app.caBundlePath` | string | `empty` | active | Path to a mounted PEM bundle for outbound provider TLS. |
| `heartbeatMonitor.url` | string | `empty` | secret | External dead-man heartbeat URL; stored only through a mounted Secret. |
| `healthCheck.diagnosticsToken` | string | `empty` | secret | Bearer token for diagnostic endpoints; stored only through a mounted Secret. |

## Compatibility

| Field | Type | Default | Status | Description |
| --- | --- | --- | --- | --- |
| `ignoreContainerNames` | list | `legacy` | deprecated | Legacy container suppression field. |
| `ignorePodNames` | list | `legacy` | deprecated | Legacy pod-name suppression field. |
| `ignoreLogPatterns` | list | `legacy` | deprecated | Legacy log suppression field. |
| `ignoreContainerMessages` | list | `legacy` | deprecated | Legacy container-message suppression field. |
| `ignoreNodeReasons` | list | `legacy` | deprecated | Legacy node-reason suppression field. |
| `ignoreNodeMessages` | list | `legacy` | deprecated | Legacy node-message suppression field. |
