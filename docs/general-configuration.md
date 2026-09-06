---
sidebar_position: 3
title: General Configuration
description: configure kwatch Kubernetes monitoring, alert routing, silences, correlation, monitors, CRD overlays, and Secret-backed credentials
keywords: [kwatch configuration, Kubernetes monitoring configuration, Kubernetes alerts, silences, alert routing, CRD, monitors, secrets]
pagination_next: null
pagination_prev: null
---

# ⚙️ General configuration

This is the complete settings reference. Most people only need to choose an
alert channel; the defaults already cover the common Kubernetes failures.

## 🗺️ Find a setting quickly

| You want to... | Start with... |
| --- | --- |
| Choose a notification destination | [Channels](/docs/channels) |
| Watch fewer namespaces | [`namespaces`](#-general) |
| Ignore an intentional failure | [Silences](#-silences--advanced-suppression) |
| Group related incidents | [Correlation](#-correlation--incident-lifecycle) |
| Add a runbook link | [Custom templates and runbooks](#-custom-templates--runbooks) |
| Keep credentials safe | [Secret-backed credentials](#-secret-backed-credentials-are-required) |
| See every accepted key | [Complete configuration reference](/docs/configuration-reference) |

### ✅ A safe change checklist

1. Change one setting.
2. Run `kwatch lint`.
3. Apply the config through `kwatch.sh` and wait for the Pod to become ready.
4. Use `kwatch lint --check` or `/test-alert` after changing a provider.

Every default below is the value used by the binary unless the installation
method says otherwise. TLS, heartbeat, Metrics Server, and active probes are
opt-in.

The base config is read from `CONFIG_FILE` (default `/config/config.yaml`).
The interactive manager mounts it from a Kubernetes Secret and can also enable
a `KwatchConfig` resource as a versioned configuration overlay. If you maintain
a custom deployment, preserve the same file and Secret contract. Every field
below maps directly to the Go struct at
[`internal/config/config.go`](https://github.com/abahmed/kwatch/blob/main/internal/config/config.go).
Sensitive strings must use an exact `${file:/absolute/path}` reference to read
a file mounted from a Kubernetes Secret at startup.

> **The good news: you probably don't need this page.** Every option below has a safe
> default and works out of the box. Use this reference when you want to *change* something —
> fewer alerts, a different channel, a custom message — or when a term in an alert confuses
> you. After editing your `config.yaml`, run `kwatch lint` (add `--check` to also verify
> credentials for providers that support checks).

---

## 🔧 General

Decide **what** to watch and **how often**.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxRecentLogLines` | `int` | `50` | Max recent log lines per container in alert messages. Also caps events. |
| `resyncSeconds` | `int` | `0` | Periodic informer resync interval. `0` = event-driven only (recommended). Raisable to e.g. `600` as a safety net. |
| `workers` | `int` | `1` | Parallel reconcile workers per queue. Raise for clusters with 200+ pods. Alert ordering becomes non-deterministic (dedup unaffected). |
| `containerRestartThreshold` | `int` | `0` | Alert when a *running* container exceeds this cumulative restart count. `0` = disabled. |
| `ignoreFailedGracefulShutdown` | `bool` | `true` | Skip containers stopped by a clean/graceful shutdown. |
| `ignoreDisruptionTerminations` | `bool` | `true` | Skip pods evicted during node drains (DeletionTimestamp / DisruptionTarget). |
| `adaptiveThresholds` | `bool` | `true` | Add bounded workload-aware grace during normal partial rollouts. |
| `reportStartupBaseline` | `bool` | `true` | Send one startup summary of pre-existing issues (suppressed from individual alerts). Anything already broken when kwatch starts is otherwise quiet for **24 hours**, so keep this on. |
| `maintenance` | `object` | enabled | Suppress explicitly marked pod/container maintenance without disabling cluster-level alerts. |
| `namespaces` | `[]string` | all | Watch only these namespaces — or use `!kube-system` to watch *everything except* it. |
| `namespaceSelector` | `string` | `""` | Kubernetes label selector to discover namespaces. Use *instead of* `namespaces`, not with it. |
| `reasons` | `[]string` | all | Alert on these event reasons only — or exclude with `!` (e.g. `reasons: ["!Started"]`). |
| `includeEvents` | `bool` | `true` | Include Kubernetes events in alert messages (at most the 40 most recent). |
| `includeLogs` | `bool` | `true` | Include container logs in alert messages. |
| `runbooks` | `map[string]string` | `{}` | Add a link to your runbook for each error reason, so every alert comes with help attached. |

### 🔽 Namespace / Reason filtering

```yaml
# Watch only these namespaces
namespaces:
  - default
  - production

# Or exclude some (can't mix both)
namespaces:
  - !kube-system
  - !monitoring

# Filter by event reason
reasons:
  - CrashLoopBackOff
  - ImagePullBackOff

# Or exclude reasons
reasons:
  - !Started
  - !Killing
```

---

## 📱 App

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `app.clusterName` | `string` | `""` | Name shown in alerts so you know which cluster. |
| `app.proxyURL` | `string` | `""` | Outbound HTTP proxy used for all provider calls. |
| `app.disableStartupMessage` | `bool` | `false` | Silence the "kwatch is alive" welcome message. |
| `app.logFormatter` | `string` | `"text"` | Log format: `text` or `json`. |
| `app.insecureSkipTLSVerify` | `bool` | `false` | Skip TLS verification for outbound HTTP (providers). |
| `app.caBundlePath` | `string` | `""` | Path to a PEM file with custom CA certificates. |

```yaml
app:
  clusterName: production-us-east
  logFormatter: json
```

---

## 💓 Health Check

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `healthCheck.enabled` | `bool` | `true` | Expose health endpoints. |
| `healthCheck.port` | `int` | `8060` | HTTP listen port. |
| `healthCheck.pprof` | `bool` | `false` | Enable Go `/debug/pprof/*` profiling endpoints. |
| `healthCheck.diagnostics` | `bool` | `false` | Enable `/incidents`, `/test-alert`, `/deadletters` endpoints. |
| `healthCheck.diagnosticsToken` | `string` | `""` | Bearer token; must use `${file:/absolute/path}`. |

**Endpoints:**
| Path | Description | Requires |
|------|-------------|----------|
| `GET /healthz` | Liveness probe | — |
| `GET /readyz` | Readiness probe (waits for cache sync) | — |
| `GET /health` | `{"status": "ok"}` | — |
| `GET /metrics` | Prometheus metrics (incidents, notifications, baseline, graph size) | — |
| `GET /incidents` | Active incidents as JSON | `diagnostics: true` |
| `POST /test-alert` | Send a test notification | `diagnostics: true` |
| `GET /deadletters` | Recent delivery failures | `diagnostics: true` |

```yaml
healthCheck:
  port: 8060
  diagnostics: true
```

---

## 🔄 Upgrader

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `upgrader.disableUpdateCheck` | `bool` | `false` | Don't check GitHub for new kwatch releases. |

---

## 🎯 Severity

Every alert carries a severity, shown as the colour of its headline. Severity drives
urgent channels, escalation, and re-notification.

| Severity | Meaning |
|:--|:--|
| `critical` | 🔴 Something users feel right now |
| `high` | 🟠 Needs a person soon |
| `warning` / `medium` | 🟡 Worth a look |
| `normal` | 🔵 Informational |

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `severityByOwnerKind` | `map[string]string` | `StatefulSet → high` | Set severity per resource type, e.g. `StatefulSet: "high"`. |
| `severityByReason` | `map[string]string` | `{}` | Set severity per event reason, checked before owner kind. |

```yaml
severityByOwnerKind:
  StatefulSet: "high"
  DaemonSet: "low"

severityByReason:
  OOMKilled: "high"
  CrashLoopBackOff: "high"
```

---

## 🔇 Silences — advanced suppression

Silences suppress an incident that matches **any** rule — no alert, no group, nothing.
Build rules from anything on the incident:

| Field | Type | Description |
|-------|------|-------------|
| `namespaces` | `[]string` | Suppress matching namespaces. |
| `reasons` | `[]string` | Suppress matching reasons. |
| `podNamePatterns` | `[]string` | Regex patterns for pod names. |
| `containerNames` | `[]string` | Suppress matching container names. |
| `logPatterns` | `[]string` | Regex patterns for log content. |
| `containerMessages` | `[]string` | Substring match on container status message. |
| `eventMessages` | `[]string` | Substring match on an attached Kubernetes Event message. |
| `nodeReasons` | `[]string` | Suppress matching node reasons. |
| `nodeMessages` | `[]string` | Substring match on node condition message. |

```yaml
silences:
  - namespaces: ["kube-system"]
  - reasons: ["BackOff"]
  - podNamePatterns: ["my-fancy-pod-.*"]
  - eventMessages: ["failed to sync configmap cache"]
  - nodeReasons: ["KubeletNotReady"]
    nodeMessages: ["kubelet has no node IP"]
```

`eventMessages` uses a case-sensitive substring match against Events attached
to the affected Pod. It suppresses the whole incident; `includeEvents` only
controls whether those Events are shown in the notification.

> **Deprecated top-level fields** (`ignoreContainerNames`, `ignorePodNames`,
> `ignoreLogPatterns`, `ignoreContainerMessages`, `ignoreNodeReasons`,
> `ignoreNodeMessages`) still work but are internally merged into the silence
> index. Prefer `silences` for new configs.

---

## 🚫 Inhibition — no double alerts

When the **node** is down, don't also page you about every **pod** on it — you can't
fix pods that have no machine.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `inhibition.nodeSuppressesPods` | `bool` | `true` | If a node has an active incident, pod incidents on that node are suppressed. Lifts as soon as the node recovers. |

---

## 🧠 Correlation — incident lifecycle

This is kwatch's **memory** — how it remembers that "this crash" and "that crash five
minutes ago" are the same problem, when it's allowed to yell again, and when it should
escalate a recurring crash.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `correlation.window` | `int` (min) | `10` | Keep incidents in memory. Outside this → new incident. |
| `correlation.lifecycleInterval` | `int` (min) | `1` | How often lifecycle checks (stale, resolve) run. |
| `correlation.resolveHoldDown` | `int` (sec) | `300` | Wait before sending "resolved". Flap dampening. Must be ≤ `window * 60`. |
| `correlation.cooldownMinutes` | `int` (min) | `10` | Min time between identical crash re-alerts. `0` = off. |
| `correlation.maxBaseline` | `int` | `5000` | Max baseline entries (prevents re-paging after restart). |
| `correlation.escalation.enabled` | `bool` | `true` | Escalate severity when restart count crosses tiers. |
| `correlation.escalation.tiers` | `[]int` | `[3, 10]` | Crossing the first → `high`, the second → `critical`. Must be strictly ascending. |
| `correlation.renotify.intervalBySeverity` | `map[string]int` | `{}` | Min minutes between renotifications per severity. `"default"` is the fallback key. Unset = off. |
| `correlation.renotify.maxPerIncident` | `int` | `3` | Max renotifications per incident lifetime. |

```yaml
correlation:
  window: 10
  resolveHoldDown: 300
  cooldownMinutes: 10
  escalation:
    enabled: true
    tiers: [3, 10]
  renotify:
    intervalBySeverity:
      critical: 15
      high: 60
      default: 120
```

---

## 🧹 Smart Grouping — coalesce duplicate notifications

Many pods failing the same way = one alert, not one per pod. Related failures over a short
window are collected and summarized into a single notification, then re-notified on a gentle
cooldown instead of every event.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `smartGrouping.windowSeconds` | `int` (sec) | `60` | Grouping window. `0` disables. |
| `smartGrouping.namespaceFanOutThreshold` | `int` | `3` | Distinct owners failing the same way in one namespace, within one window, before their groups collapse into one alert. `0` disables. |

```yaml
smartGrouping:
  windowSeconds: 60
  namespaceFanOutThreshold: 3
```

---

## 📝 Custom Templates & Runbooks

Override the alert message per reason (Go `text/template`), and attach documentation URLs.

```yaml
templates:
  CrashLoopBackOff: "{{.Incident.Name}} — {{.Action}} — {{.Incident.Hint}}"
  OOMKilled: "🔴 {{.Incident.Name}} ran out of memory in {{.Incident.Namespace}}"

runbooks:
  OOMKilled: "https://wiki.example.com/oom"
  CrashLoopBackOff: "https://wiki.example.com/crashloop"
```

**Template variables:** `{{.Incident.Key}}`, `{{.Incident.Reason}}`,
`{{.Incident.Name}}`, `{{.Incident.Namespace}}`, `{{.Incident.Hint}}`,
`{{.Action}}` (`create`/`update`/`resolved`), `{{.Message}}`.

---

## 📝 Audit log

For every incident *transition* (created, updated, resolved, skipped), kwatch writes one
structured JSON line — feed it to your log pipeline for a searchable history.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `auditLog.enabled` | `bool` | `true` | Write one structured JSON entry per incident transition. |
| `auditLog.output` | `string` | `"stdout"` | Destination: `stdout` or a file path. |

---

## 🧰 Operations and security

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `telemetry.enabled` | `bool` | `true` | Send a weekly adoption heartbeat containing only a random installation ID and the kwatch version. |
| `maintenance.enabled` | `bool` | `true` | Honor maintenance annotations. |
| `maintenance.annotation` | `string` | `kwatch.io/maintenance` | Annotation used to mark deliberate maintenance. |
| `maintenance.untilAnnotation` | `string` | `kwatch.io/maintenance-until` | Optional annotation containing the maintenance expiry time. |

For maintenance behavior and examples, keep the annotations in the Pod template
and use the [`maintenance.annotation`](#-operations-and-security) and
`maintenance.untilAnnotation` keys above.

---

## 📋 CRD — configuration overlay with automatic restart

Instead of editing the base config, you can store a non-sensitive overlay in a
small custom resource. Provider settings, heartbeat URLs, and diagnostic
tokens are forbidden in `KwatchConfig`; they remain in the mounted Secret. The
overlay is applied at startup. When the resource changes, kwatch restarts its
Pod so the complete configuration is rebuilt consistently. It is off by
default in the generic binary.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `crd.enabled` | `bool` | `false` | Watch `KwatchConfig` custom resources and restart kwatch when the overlay changes. |
| `crd.failureConditions` | `list` | `[]` | Extra CRD status rules such as `Ready=False` or `Degraded=True`. |
| `crd.graphReferences` | `list` | `[]` | Optional references that add custom CRD edges to dependency analysis. |

```yaml
apiVersion: kwatch.abahmed.dev/v1alpha1
kind: KwatchConfig
metadata:
  name: kwatch-config
  namespace: kwatch
spec:
  maxRecentLogLines: 100
  silences:
    - namespaces: ["kube-system"]
```

---

## 📊 Monitors

All monitors below are **on by default** unless the table says `default: false`.

### 🖥️ Node Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nodeMonitor.enabled` | `bool` | `true` | Detect `NotReady`, `Unknown`, `MemoryPressure`, `DiskPressure`, `PIDPressure`, `NetworkUnavailable`. |
| `nodeMonitor.sustainedMinutes` | `int` | `3` | Minutes a node condition must persist before alerting. |

### ⏳ Pending Pod Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pendingPodMonitor.enabled` | `bool` | `true` | Detect pods stuck in `Pending`. |
| `pendingPodMonitor.threshold` | `int` (sec) | `300` | Seconds stuck before alerting. |

Includes `scheduleMonitor.enabled` (default `true`) to add how long the scheduler has been
stalling ("unschedulable for 5m30s") to the hint.

### 🟡 Not Ready Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `notReadyMonitor.enabled` | `bool` | `true` | Alert with `ContainersNotReady` when a Running pod's Ready condition stays false too long. The budget is derived from the pod's own probes, not a fixed number. |

### 🚀 Rollout Monitor (Deployments)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `rolloutMonitor.enabled` | `bool` | `true` | Detect `ProgressDeadlineExceeded` and stalled rollouts. |
| `rolloutMonitor.sustainedMinutes` | `int` | `5` | Minutes of unavailability before alerting. |

### 🧩 StatefulSet Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `statefulSetMonitor.enabled` | `bool` | `true` | Detect unavailable StatefulSet pods. |
| `statefulSetMonitor.sustainedMinutes` | `int` | `5` | Minutes of unavailability before alerting, plus 15-minute rollout grace. |

### 📡 DaemonSet Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `daemonSetMonitor.enabled` | `bool` | `true` | Detect unavailable DaemonSet pods. |
| `daemonSetMonitor.sustainedMinutes` | `int` | `5` | Debounce before alerting. |

### 🧑‍💼 Job Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `jobMonitor.enabled` | `bool` | `true` | Detect failed (`JobFailed`) or suspended Jobs. |

### ⏰ CronJob Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cronJobMonitor.enabled` | `bool` | `true` | Detect suspended CronJobs or missed schedules. |
| `cronJobMonitor.sustainedMinutes` | `int` | `5` | Minutes a CronJob must stay suspended before alerting. |

### 📈 HPA Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hpaMonitor.enabled` | `bool` | `true` | Detect HPAs stuck at max replicas. |
| `hpaMonitor.sustainedMinutes` | `int` | `20` | Minutes sustained before alerting. |

### 🚀 Cluster Autoscaler Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clusterAutoscalerMonitor.enabled` | `bool` | `true` | Detect `FailedToScaleUp` / `NotTriggerScaleUp` (autoscaler can't add capacity). |

### 💾 PVC Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pvcMonitor.enabled` | `bool` | `true` | Monitor PersistentVolumeClaim disk usage. |
| `pvcMonitor.interval` | `int` (min) | `5` | Check frequency. |
| `pvcMonitor.threshold` | `float` (%) | `80` | Warn threshold. |
| `pvcMonitor.criticalThreshold` | `float` (%) | `90` | High-severity threshold. Must be ≥ `threshold`. |
| `pvcMonitor.clearThreshold` | `float` (%) | `75` | Resolve below this %. Must be ≤ `threshold`. |

### 💓 Heartbeat Monitor (dead man's switch)

**Off by default.** Sends periodic HTTP pings to an external health-check URL. If kwatch
stops, the external monitor stops getting pings and pages you.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `heartbeatMonitor.enabled` | `bool` | `false` | Enable heartbeat pings. |
| `heartbeatMonitor.interval` | `int` (sec) | `300` | Seconds between pings. |
| `heartbeatMonitor.url` | `string` | `""` | Secret-backed `${file:/absolute/path}` heartbeat URL. |

### 🔒 TLS Certificate Monitor

**Off by default** because it requires an additional `secrets` RBAC permission. Warns with
30 days to go, and raises severity to high with 3 days to go.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tlsMonitor.enabled` | `bool` | `false` | Enable TLS certificate monitoring. |
| `tlsMonitor.threshold` | `int` (days) | `30` | Days before expiry to warn. |
| `tlsMonitor.criticalThreshold` | `int` (days) | `3` | Days before expiry to raise severity to `high`. |

### 🔗 Service Endpoint Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceMonitor.enabled` | `bool` | `true` | Detect Services with zero ready endpoints (60s debounce). |

### 🧩 Admission Webhook Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `admissionWebhookMonitor.enabled` | `bool` | `true` | Detect webhooks whose backing service has no ready endpoints. |

### 🏛️ Control-Plane Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `controlPlaneMonitor.enabled` | `bool` | `true` | Detect container issues in control-plane pods (apiserver, scheduler, controller-manager, etcd, kube-proxy, coredns). |
| `controlPlaneMonitor.intervalSeconds` | `int` | `30` | Seconds between API and control-plane health checks. |
| `controlPlaneMonitor.apiServerLatencyWarningMs` | `int` | `1000` | API server `/readyz` latency warning threshold in milliseconds. |
| `controlPlaneMonitor.failureThreshold` | `int` | `2` | Consecutive failures before alerting. |
| `controlPlaneMonitor.recoveryThreshold` | `int` | `2` | Consecutive successes before resolving. |

### 🌐 Ingress Backend Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ingressMonitor.enabled` | `bool` | `true` | Detect ingress backends with zero ready endpoints. |

### 🚧 Network Policy Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `networkPolicyMonitor.enabled` | `bool` | `true` | Detect NetworkPolicies that deny **all** inbound traffic. |

### 🔄 PDB Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `pdbMonitor.enabled` | `bool` | `true` | Detect PDBs blocking voluntary disruptions (`disruptionsAllowed=0`). |
| `pdbMonitor.sustainedMinutes` | `int` | `5` | Minutes of blocking before alerting. |

### 🏭 Node Resource Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `nodeResourceMonitor.enabled` | `bool` | `true` | Check node CPU/memory overcommit levels. |
| `nodeResourceMonitor.intervalSeconds` | `int` | `300` | How often to check. |
| `nodeResourceMonitor.cpuWarning` | `float` | `2.0` | CPU overcommit ratio for warning. |
| `nodeResourceMonitor.cpuCritical` | `float` | `4.0` | CPU overcommit ratio for critical. |
| `nodeResourceMonitor.memWarning` | `float` | `2.0` | Memory overcommit ratio for warning. |
| `nodeResourceMonitor.memCritical` | `float` | `4.0` | Memory overcommit ratio for critical. |
| `nodeResourceMonitor.filesystemWarningPercent` | `float` | `90` | Node filesystem usage warning threshold. `0` disables it. |
| `nodeResourceMonitor.filesystemCriticalPercent` | `float` | `95` | Node filesystem usage critical threshold. `0` disables it. |
| `nodeResourceMonitor.inodeWarningPercent` | `float` | `90` | Node inode usage warning threshold. `0` disables it. |
| `nodeResourceMonitor.inodeCriticalPercent` | `float` | `95` | Node inode usage critical threshold. `0` disables it. |

### 📊 Optional Metrics Server monitor

`runtimeMetricsMonitor` reads the optional `metrics.k8s.io` API. It is disabled
by default and is not required for kwatch's built-in kubelet telemetry.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `runtimeMetricsMonitor.enabled` | `bool` | `false` | Use Metrics Server data for workload usage diagnostics. |
| `runtimeMetricsMonitor.intervalSeconds` | `int` | `60` | Seconds between checks. |
| `runtimeMetricsMonitor.memoryWarningPercent` | `int` | `90` | Memory usage warning percentage. |
| `runtimeMetricsMonitor.memoryCriticalPercent` | `int` | `100` | Memory usage critical percentage. |
| `runtimeMetricsMonitor.cpuWarningPercent` | `int` | `90` | CPU usage warning percentage. |
| `runtimeMetricsMonitor.cpuCriticalPercent` | `int` | `100` | CPU usage critical percentage. |

The shipped RBAC does not grant the extra `metrics.k8s.io` permission by
default. Add it only when this monitor is enabled.

### 🏛️ Cluster resource monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clusterResourceMonitor.enabled` | `bool` | `true` | Watch quota, namespace, and node-lease lifecycle failures. |
| `clusterResourceMonitor.sustainedMinutes` | `int` | `10` | Minutes a terminating namespace or quota condition must persist. |
| `clusterResourceMonitor.nodeLeaseStaleSeconds` | `int` | `90` | Seconds without a node lease renewal before reporting a stale heartbeat. |

### 🧠 Kubelet telemetry monitor

This monitor uses built-in kubelet endpoints. It does not need an agent or
Prometheus.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `kubeletTelemetryMonitor.enabled` | `bool` | `true` | Read built-in kubelet telemetry. |
| `kubeletTelemetryMonitor.intervalSeconds` | `int` | `60` | Seconds between telemetry sweeps. |
| `kubeletTelemetryMonitor.failureThreshold` | `int` | `2` | Consecutive failed samples before alerting. |
| `kubeletTelemetryMonitor.recoveryThreshold` | `int` | `2` | Consecutive healthy samples before resolving. |
| `kubeletTelemetryMonitor.persistState` | `bool` | `true` | Persist telemetry counters across restarts. |
| `kubeletTelemetryMonitor.memoryWarningPercent` | `float` | `90` | Container memory warning threshold. |
| `kubeletTelemetryMonitor.memoryCriticalPercent` | `float` | `100` | Container memory critical threshold. |
| `kubeletTelemetryMonitor.ephemeralStorageWarningPercent` | `float` | `90` | Ephemeral-storage warning threshold. |
| `kubeletTelemetryMonitor.ephemeralStorageCriticalPercent` | `float` | `95` | Ephemeral-storage critical threshold. |
| `kubeletTelemetryMonitor.cpuWarningPercent` | `float` | `90` | CPU usage warning threshold. |
| `kubeletTelemetryMonitor.cpuCriticalPercent` | `float` | `100` | CPU usage critical threshold. |
| `kubeletTelemetryMonitor.cpuThrottlingWarningPercent` | `float` | `25` | CPU throttling warning threshold. |
| `kubeletTelemetryMonitor.cpuThrottlingCriticalPercent` | `float` | `50` | CPU throttling critical threshold. |
| `kubeletTelemetryMonitor.psiWarningPercent` | `float` | `20` | PSI warning threshold. |
| `kubeletTelemetryMonitor.psiCriticalPercent` | `float` | `50` | PSI critical threshold. |
| `kubeletTelemetryMonitor.networkErrorRateWarning` | `float` | `1` | Network errors per second warning threshold. |
| `kubeletTelemetryMonitor.networkErrorRateCritical` | `float` | `10` | Network errors per second critical threshold. |
| `kubeletTelemetryMonitor.runtimeErrorRateWarning` | `float` | `1` | Runtime errors per second warning threshold. |
| `kubeletTelemetryMonitor.runtimeErrorRateCritical` | `float` | `10` | Runtime errors per second critical threshold. |

### 🎯 Active probes

Active probes are disabled by default because they create traffic. Explicit
HTTP, TCP, and DNS targets are the recommended low-noise mode. Set
`autoServices: true` only when you want kwatch to probe advertised Service
ports automatically.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `activeProbeMonitor.enabled` | `bool` | `false` | Run configured application probes. |
| `activeProbeMonitor.intervalSeconds` | `int` | `30` | Seconds between probe rounds. |
| `activeProbeMonitor.timeoutSeconds` | `int` | `5` | Timeout for each probe. |
| `activeProbeMonitor.failureThreshold` | `int` | `3` | Consecutive failures before alerting. |
| `activeProbeMonitor.recoveryThreshold` | `int` | `2` | Consecutive successes before resolving. |
| `activeProbeMonitor.autoServices` | `bool` | `false` | Probe discoverable Service ports automatically. |
| `activeProbeMonitor.http` | `list` | `[]` | HTTP targets with optional status and latency limits. |
| `activeProbeMonitor.tcp` | `list` | `[]` | TCP targets. |
| `activeProbeMonitor.dns` | `list` | `[]` | DNS targets. |

```yaml
activeProbeMonitor:
  enabled: true
  http:
    - name: api
      url: https://api.example.com/ready
      expectedStatus: 200
  tcp:
    - name: postgres
      address: postgres.database.svc:5432
  dns:
    - name: cluster-dns
      host: kubernetes.default.svc
```

### 💥 OOM Pattern Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `oomMonitor.enabled` | `bool` | `true` | Track repeating OOMs (memory leaks). |
| `oomMonitor.threshold` | `int` | `3` | OOM count within window to flag. |
| `oomMonitor.windowMinutes` | `int` | `60` | Sliding window in minutes. |

---

## 🔐 Secret-backed credentials are required

Provider credentials, diagnostic tokens, and heartbeat URLs must be files
mounted from a Kubernetes Secret. Plain values and `${ENV_VAR}` substitutions
are rejected for sensitive fields:

```yaml
# config.yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
```

```bash
kubectl -n kwatch create secret generic kwatch-config \
  --from-file=config.yaml \
  --from-file=slack-webhook
```

Mount `kwatch-config` at `/config`, or set the Helm `configSecretName` value to
`kwatch-config`. `${VAR}` remains available for non-sensitive strings only.

The shipped workloads use a non-root user, read-only root filesystem, dropped
Linux capabilities, disabled privilege escalation, and the `RuntimeDefault`
seccomp profile. Protect the Secret with least-privilege RBAC, enable API
server/etcd encryption at rest, and restart the deployment after rotating it.

---

## 🚦 Alert Providers

kwatch delivers to **56 alert integrations**. Configure one or more under `alert:`. Routing,
retry, and fallback are supported by every provider:

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
    retry:
      maxAttempts: 5
      delay: 5s
    fallback: pagerduty

  pagerduty:
    integrationKey: "${file:/config/pagerduty-integration-key}"

  discord:
    webhook: "${file:/config/discord-webhook}"

  telegram:
    token: "${file:/config/telegram-token}"
    chatId: <chat>

  email:
    from: <from>
    to: <to>
    password: "${file:/config/email-password}"
    host: <smtp-host>
    port: <smtp-port>
```

The [complete provider reference](/docs/channels/providers) lists all 56
integrations and every catalog field. The [complete configuration reference](/docs/configuration-reference)
lists every accepted configuration key, type, default, category, and status.
Both pages are generated from the versioned catalogs shipped with `kwatch.sh`.

### Routes

An incident must match **at least one** route to be delivered. If no routes are configured,
all incidents are delivered.

```yaml
routes:
  - namespaces: ["production"]
    severities: ["critical"]
    reasons: ["OOMKilled"]
```

### Retry & Fallback

```yaml
retry:
  maxAttempts: 5          # max send attempts (default: 3)
  delay: 5s               # delay between attempts

fallback: pagerduty        # secondary provider (configured at top level)
```

Only failures that *can* succeed on a retry are retried (timeout, 5xx, rate limit). A 4xx
or rejected payload is given up on immediately and goes to the dead-letter queue, so it
cannot hold up other alerts.

---

## 📋 Example — full config

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  slack-webhook: "replace-me"
  pagerduty-integration-key: "replace-me"
  config.yaml: |
    maxRecentLogLines: 50
    ignoreFailedGracefulShutdown: true
    workers: 2

    app:
      clusterName: prod-us-east

    correlation:
      window: 10
      resolveHoldDown: 300
      escalation:
        enabled: true
        tiers: [3, 10]

    smartGrouping:
      windowSeconds: 60
      namespaceFanOutThreshold: 3

    silences:
      - namespaces: ["kube-system"]

    nodeMonitor:
      enabled: true

    pendingPodMonitor:
      enabled: true
      threshold: 300

    healthCheck:
      enabled: true
      port: 8060

    alert:
      slack:
        webhook: "${file:/config/slack-webhook}"
      pagerduty:
        integrationKey: "${file:/config/pagerduty-integration-key}"
```
