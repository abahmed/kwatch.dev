---
sidebar_position: 4
title: Infrastructure Packages
description: kwatch infrastructure packages for Kubernetes clients, persistence, health, metrics, heartbeat, PVCs, CRDs, and upgrades
keywords: [kwatch, kubernetes, architecture, infrastructure, k8s, client, state, health, metrics]
pagination_prev: architecture/correlation-and-alerting
pagination_next: architecture/data-flow
---

# 🧱 Infrastructure packages

These packages connect kwatch to Kubernetes, persistence, health endpoints,
metrics, and periodic monitors.

## 12. `internal/k8s/` — Kubernetes Utilities

**Path:** `internal/k8s/`

### Role

Shared Kubernetes access helpers: HTTP transport configuration, log/event
fetching, node summary queries, and namespace detection.

### Key Functions

| Function | Purpose |
|----------|---------|
| `InitHTTPClient(cfg)` | Configures proxy, TLS, and CA bundle for outbound HTTP |
| `GetDefaultClient()` | The shared HTTP client used by every provider send (`alert/util.Send`) |
| `GetNamespace()` | Returns `POD_NAMESPACE` env var, falling back to `"kwatch"` |
| `FetchContainerLogs(ctx, c, pod, opts)` | Fetches container logs from the K8s API (with a 15s timeout and one retry) |
| `GetPodEvents(ctx, c, name, ns)` | Fetches recent events for a pod via field selector |
| `GetNodeSummary(ctx, c, node)` | Fetches a node's kubelet `/stats/summary` through the API server proxy |
| `IsNodeReady(n)` / `GetNodes(ctx, c)` | Node condition helpers |

### HTTP transport

```
// Default timeout: 30s
// Proxy support via App.ProxyURL
// Custom CA via App.CABundlePath
// Insecure skip verify via App.InsecureSkipTLSVerify
```

---

## 13. `internal/client/` — Kubernetes Client

**Path:** `internal/client/client.go`

### Role

Creates and configures the Kubernetes clientset (`kubernetes.Interface`) used
by all components.

```go
func Create(appConfig *config.App) kubernetes.Interface {
    // Reads in-cluster config (service account)
    // OR ~/.kube/config for local development
    // Applies proxy settings from App.ProxyURL
    // Returns typed clientset
}

func GetRestConfig(appConfig *config.App) (*rest.Config, error)
```

`GetRestConfig` is used by the CRD watcher to build its dynamic client.

---

## 14. `internal/state/` — State Persistence

**Path:** `internal/state/state.go`, `retry.go`

### Role

kwatch keeps its state in **plain ConfigMaps** in its own namespace — no
database, no volume. The `StateManager` manages four of them, each through its
own `RetryConfigMapManager`:

| ConfigMap | Contents |
|-----------|----------|
| `kwatch-state` | Cluster identity (`cluster-id`), `first-run`, upgrade bookkeeping, and a `last-seen` liveness stamp |
| `kwatch-baseline` | Pre-existing problems seen at startup (gzip-compressed JSON) |
| `kwatch-incidents` | Every active incident (`PersistedIncident` records), trimmed to fit |
| `kwatch-pvc` | Last-known PVC usage (`PvcSample` records), gzip-compressed |

### Optimistic concurrency

Every write is a read-modify-write with conflict retry:

```go
const (
    maxRetries = 3
    retryDelay = 100 * time.Millisecond
)

for i := 0; i < maxRetries; i++ {
    cm, err := client.GetConfigMap(ctx, name, ns)
    // modify cm.Data
    _, err = client.UpdateConfigMap(ctx, cm, metav1.UpdateOptions{})
    if err == nil {
        return nil // success
    }
    if apierrors.IsConflict(err) {
        time.Sleep(retryDelay) // retry with fresh data
        continue
    }
    return err
}
```

### Last-seen liveness gap

During the run, `app` calls `recordAlive` on a 60-second tick shared with the
incident-snapshot writer (one ConfigMap write a minute bounds the reported
gap). On the next start, a gap longer than **5 minutes** is reported alongside
the startup welcome message ("No monitoring for 52m before this start") so
silence can't hide a dead kwatch.

State written by older kwatch versions used a different layout (`kwatch-state`
held the baseline inline); `MigrateLegacyBaseline` reads and migrates it on
first start, so an upgrade keeps its incident memory.

---

## 15. `internal/health/` — Health & Metrics Server

**Path:** `internal/health/health.go`

### Role

HTTP server (default port 8060) serving health checks, Prometheus metrics,
and (when enabled) diagnostic endpoints.

### Endpoints

| Path | Method | Description |
|------|--------|-------------|
| `/healthz` | GET | Liveness probe (always 200) |
| `/health` | GET | `{"status":"ok"}` |
| `/readyz` | GET | Readiness probe (200 once informer cache sync sets ready) |
| `/metrics` | GET | Prometheus metrics (text format) |
| `/incidents` | GET | Active incidents as JSON (diagnostics only) |
| `/test-alert` | POST | Send a test notification (diagnostics only) |
| `/deadletters` | GET | Failed-delivery ring buffer (diagnostics only) |

Diagnostic endpoints require `healthCheck.diagnostics: true` and honour an
optional Bearer token (`diagnosticsToken`, constant-time compared).
`healthCheck.pprof` adds `/debug/pprof/*` behind the same guard. `/metrics` is
always served. The readiness flag is set by the controller once all informers
have synced.

---

## 16. `internal/metrics/` — Metrics Registry

**Path:** `internal/metrics/metrics.go`

### Role

Package-level registry of atomic counters/gauges, rendered by the `/metrics`
handler:

```
kwatch_incidents_total{action="create|update|resolved|grouped"}
kwatch_notifications_total
kwatch_notifications_dropped_total
kwatch_incidents_active
kwatch_baseline_size
kwatch_graph_nodes          # resources in the dependency graph
kwatch_graph_edges          # relationships in the dependency graph
```

`kwatch_graph_nodes`/`kwatch_graph_edges` are the first thing to check when
diagnoses come back empty on a large cluster — an empty graph explains nothing.

---

## 17. `internal/startup/` — Startup Lifecycle

**Path:** `internal/startup/startup.go`

### Role

Manages the startup lifecycle: ensures a cluster ID, creates the state
ConfigMaps, measures monitoring downtime from the `last-seen` stamp, and
decides whether to send a welcome/update message.

### Key Functions

| Function | Purpose |
|----------|---------|
| `NewStartupManager(k8sClient, ns, alertCfg, appCfg)` | Creates the manager (and the alert manager) |
| `HandleStartup(ctx)` | Ensures `cluster-id`, creates state ConfigMaps |
| `RecordAlive(ctx)` | Stamps `last-seen` once a minute |
| `NotifyStartup()` | Sends the welcome message when it is news (first run, upgrade, or downtime) |
| `GetAlertManager()` / `GetStateManager()` | Hand out the wired components |

`shouldNotify` is true only for the first run, an upgrade, or a detected
monitoring gap — an ordinary restart stays quiet.

---

## 18. `internal/heartbeat/` — Heartbeat Monitor

**Path:** `internal/heartbeat/`

### Role

Periodically sends HTTP GET pings to an external URL (dead man's switch). If
kwatch stops or crashes, the external monitor stops receiving pings and
alerts.

```go
type HeartbeatMonitor struct {
    enabled  bool
    interval time.Duration
    url      string // e.g. https://hc-ping.com/uuid
}
```

---

## 19. `internal/pvc/` — PVC Monitor

**Path:** `internal/pvc/pvc.go`, `check_usage.go`, `get_usage.go`

### Role

Periodically checks PersistentVolumeClaim disk usage. For each node it fetches
the kubelet `/stats/summary` through the Kubernetes API proxy
(`k8s.GetNodeSummary`), extracts `usedBytes`/`capacityBytes` per volume, and
reports incidents at the configured thresholds.

### How it works

1. Lists PVCs once per minute to build a PVC→PV map
2. Iterates nodes, querying each kubelet summary API (bounded concurrency)
3. Computes usage % per mounted volume
4. Warns at `threshold`, raises severity to `high` at `criticalThreshold`
5. Retains a `lastUsage` cache (persisted to `kwatch-pvc`) so high-but-unmounted
   volumes (Job/CronJob runs) keep their state across unmounts and restarts
6. Resolves below `clearThreshold` (hysteresis)

### Configuration fields

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Enable PVC monitoring |
| `interval` | `5` (minutes) | Check frequency |
| `threshold` | `80` (%) | Warn threshold |
| `criticalThreshold` | `90` (%) | High-severity threshold |
| `clearThreshold` | `75` (%) | Resolve below this |

---

## 20. `internal/crdwatch/` — CRD Watcher

**Path:** `internal/crdwatch/`

### Role

When `crd.enabled: true`, watches `KwatchConfig` custom resources and applies
config changes at runtime without restarting kwatch. The CR's spec carries a
subset of the live-reloadable fields (silences, templates, severity maps, ...).
On change, the watcher pushes the new values into the alert manager — no
restart required.

---

## 21. `internal/upgrader/` — Version Checker

**Path:** `internal/upgrader/`

### Role

Periodically checks GitHub releases for new kwatch versions (every 24 hours,
disabled by `upgrader.disableUpdateCheck`). If a newer version exists, it
sends a notification to the configured channels.

---

## 22. `internal/constant/` — Shared Constants

**Path:** `internal/constant/`

### Role

Shared constants used across packages: severity/reason strings, metric
labels, the reason keys the enricher maps hints and severities from
(`ReasonOOMKilled`, `ReasonCrashLoopBackOff`, `ReasonImagePullBackOff`,
`ReasonEvicted`, node pressure reasons, rollout/job/cronjob reasons, ...), and
message templates.

---

## 23. `internal/ratelimit/` & `internal/format/` — Helpers

**Path:** `internal/ratelimit/ratelimit.go`, `internal/format/format.go`

### Role

- `ratelimit.ParseRetryAfter(resp)` parses HTTP `Retry-After` headers (both
  integer seconds and HTTP-date formats) from provider 429 responses. The
  delivery retry loop honours the result.
- `format` provides small formatting helpers shared by renderers.

---

## 24. `internal/version/` — Build Version

**Path:** `internal/version/version.go`

### Role

Injects build-time version information via `-ldflags -X`.

```go
var (
    version     = "dev"      // -X github.com/abahmed/kwatch/internal/version.version=vX.Y.Z
    gitCommitID = "none"     // -X .../version.gitCommitID=abc1234
    buildDate   = "unknown"  // -X .../version.buildDate=2026-08-27T00:00:00Z
)

func Short() string // returns the version string (e.g. "vX.Y.Z"); printed by `kwatch --version`
```

---

## 25. `internal/graphcontext/` — Dependency Graph & Change Tracker

**Path:** `internal/graphcontext/graph.go`, `tracker.go`

### Role

Two data structures power the insight engine:

- **`ResourceGraph`** — the in-memory map of the cluster. The controller adds
  an edge per relationship: pod→node, pod→owner (Deployment/StatefulSet/
  DaemonSet/Job), pod→ConfigMap/Secret/PVC, Service→pods, Ingress→Service.
  `DependenciesOf` and `DependentsOf` answer "what does X depend on" and "who
  depends on X" — the two directions cause analysis and impact analysis walk.
- **`ChangeTracker`** — a bounded log of resource updates (`Change{Resource,
  Namespace, Name, Type, Timestamp}`). `RecentChangesBefore(age)` answers "what
  changed just before this incident" for the "what-changed" diagnosis.

Both are built at startup, refreshed on resync, and patched by the
controller's `recordChange` handlers. The graph is what the mass-failure scan
walks to count dependents sharing a node, ConfigMap, Secret, or PVC.

---

## 26. `internal/message/` — Report Builder & Renderers

**Path:** `internal/message/`

### Role

Builds one provider-agnostic `Report` per notification, then renders it per
provider. Sections are populated selectively based on the incident's reason —
nil sections are omitted by renderers.

```go
type Report struct {
    Action, Reason, Severity, Resource, Name, Namespace, Cluster string
    Summary   SummarySection   // always present (emoji, label, age, count)
    Identity  *IdentitySection // container, image, node, owner kind
    State     *StateSection    // message, exit code, restarts
    Diagnosis *DiagnosisSection // hint, cause, impact, pattern
    Evidence  *EvidenceSection  // logs, events
    Changes   *ChangesSection   // recent resource changes
    Runbook   string
    OOM       *OOMSection     // memory limit, kill timeline, leak flag
    Probe     *ProbeSection   // probe type + endpoint
    Image     *ImageSection   // registry hint, pull secrets
    Pending   *PendingSection // scheduling delay, resource requests
    ...
}
```

`ReportBuilder` turns an incident (plus the `insight.Insight` diagnosis) into a
Report; per-provider renderers (`slack_renderer.go`, `discord_renderer.go`,
`plaintext_renderer.go`, `text_renderer.go`) lay it out for the target
provider. `internal/format` shares the low-level formatting helpers.

---

## 27. `internal/audit/` — Structured Audit Log

**Path:** `internal/audit/audit.go`

### Role

Writes one structured JSON line per incident decision (`enabled` +
`output: stdout` or a file). Each entry records the action (create/update/
resolve/skip), the incident key, reason, and severity — plus a stable
`skipReason` (`baseline`, `node_inhibition`, `mass_failure`,
`cascading_suppression`, `cooldown`) when the event was suppressed. Logging
happens once per incident, not once per poll, so "why didn't kwatch tell me?"
always has an answer without drowning the log in duplicate lines.

---

## 28. `internal/app/` — Composition Root

**Path:** `internal/app/run.go`, `correlator.go`, `serve.go`

### Role

`app.Run()` loads the config and wires every component in order — HTTP client,
clientset, startup/state, alert manager, health server, upgrader, change
tracker, resource graph, insight engine, correlation engine, PVC and heartbeat
monitors, handler, controller — then runs until shutdown. It also owns the
hooks that make the engine the single notification door:

- **`lifecycleHook`** — for every non-skipped incident edge, audits the event
  and calls `AlertManager.NotifyIncident(inc, action, insight)` with a
  diagnosis computed by `insight.Engine.Analyze`.
- **`massFailureHook`** — runs `insight.ScanMassFailures` on the lifecycle
  tick, opening and resolving shared-dependency incidents.
- **`onBaselineChange` / persistence goroutines** — forward baseline and
  incident snapshots to the state ConfigMaps.
- **`restoreIncidents`** — rehydrates `kwatch-incidents` back into the engine
  at startup so a restart resumes exactly where it left off.
