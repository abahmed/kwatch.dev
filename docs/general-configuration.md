---
sidebar_position: 3
title: General Configuration
description: all configuration options for kwatch, verified against the kwatch Go source
keywords: [kwatch, kubernetes, configuration, general, silences, inhibition, correlation, templates, crd, severity, monitors]
pagination_next: null
pagination_prev: null
---

# General Configuration

All config lives in a single ConfigMap. kwatch watches `CONFIG_FILE` (default
`/config/config.yaml`). Every field below maps directly to the Go struct at
[`internal/config/config.go`](https://github.com/abahmed/kwatch/blob/main/internal/config/config.go).

> **The good news: you probably don't need this page.** Every option below has a safe
> default and works out of the box. Use this reference when you want to *change* something —
> fewer alerts, a different channel, a custom message — or when a term in an alert confuses
> you. After editing your `config.yaml`, run `kwatch lint` (add `--check` to also verify
> your alert-provider credentials).

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
| `reportStartupBaseline` | `bool` | `true` | Send one startup summary of pre-existing issues (suppressed from individual alerts). Anything already broken when kwatch starts is otherwise quiet for **24 hours**, so keep this on. |
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
| `healthCheck.diagnosticsToken` | `string` | `""` | Bearer token required for diagnostic endpoints. Empty = no auth. |

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
| `nodeReasons` | `[]string` | Suppress matching node reasons. |
| `nodeMessages` | `[]string` | Substring match on node condition message. |

```yaml
silences:
  - namespaces: ["kube-system"]
  - reasons: ["BackOff"]
  - podNamePatterns: ["my-fancy-pod-.*"]
  - nodeReasons: ["KubeletNotReady"]
    nodeMessages: ["kubelet has no node IP"]
```

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

## 📋 CRD — live config reloading

Instead of editing the ConfigMap and restarting, push config changes live with a small
custom resource. Off by default.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `crd.enabled` | `bool` | `false` | Watch `KwatchConfig` custom resources for live config changes. |

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
| `pvcMonitor.criticalThreshold` | `float` (%) | `90` | Critical threshold. Must be ≥ `threshold`. |
| `pvcMonitor.clearThreshold` | `float` (%) | `75` | Resolve below this %. Must be ≤ `threshold`. |

### 💓 Heartbeat Monitor (dead man's switch)

**Off by default.** Sends periodic HTTP pings to an external health-check URL. If kwatch
stops, the external monitor stops getting pings and pages you.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `heartbeatMonitor.enabled` | `bool` | `false` | Enable heartbeat pings. |
| `heartbeatMonitor.interval` | `int` (sec) | `300` | Seconds between pings. |
| `heartbeatMonitor.url` | `string` | `""` | External URL (e.g. Healthchecks.io). |

### 🔒 TLS Certificate Monitor

**Off by default** because it requires an additional `secrets` RBAC permission. Warns with
30 days to go, pages with 3 days to go.

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

### 💥 OOM Pattern Monitor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `oomMonitor.enabled` | `bool` | `true` | Track repeating OOMs (memory leaks). |
| `oomMonitor.threshold` | `int` | `3` | OOM count within window to flag. |
| `oomMonitor.windowMinutes` | `int` | `60` | Sliding window in minutes. |

---

## 🔐 Keeping credentials out of the ConfigMap

ConfigMaps are readable by anyone with `get` access and are not encrypted at rest by
default. kwatch expands `${VAR}` in its config, so keep the secret in a Secret and reference it:

```yaml
# config.yaml
alert:
  slack:
    token: "${SLACK_TOKEN}"
```

```yaml
# kwatch container in the Deployment
env:
  - name: SLACK_TOKEN
    valueFrom:
      secretKeyRef:
        name: kwatch-credentials
        key: SLACK_TOKEN
```

Only `${VAR}` (braced) is expanded, and only where the value is a string.

---

## 🚦 Alert Providers

kwatch delivers to **56 alert providers**. Configure one or more under `alert:`. Routing,
retry, and fallback are supported by every provider:

```yaml
alert:
  slack:
    webhook: <url>
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
    retry:
      maxAttempts: 5
      delay: 5s
    fallback: pagerduty

  pagerduty:
    integrationKey: <key>

  discord:
    webhook: <url>

  telegram:
    token: <token>
    chatId: <chat>

  email:
    from: <from>
    to: <to>
    password: <pass>
    host: <smtp-host>
    port: <smtp-port>
```

The full list of all 56 providers — with every parameter and example — is in
[`docs/providers.md`](https://github.com/abahmed/kwatch/blob/main/docs/providers.md) in the
kwatch repository, and the dedicated pages under [Channels](/docs/channels).

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
kind: ConfigMap
metadata:
  name: kwatch
  namespace: kwatch
data:
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
        webhook: https://hooks.slack.com/services/...
      pagerduty:
        integrationKey: abc123
```
