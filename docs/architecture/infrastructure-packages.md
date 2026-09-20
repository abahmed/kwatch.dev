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

Shared Kubernetes access helpers: log/event fetching, node summary queries,
and namespace detection. `internal/client` owns application-wide Kubernetes,
HTTP, DNS, and clock construction; `internal/kubelet` owns bounded
container-log requests used by Pod enrichment.

### Key Functions

| Function | Purpose |
|----------|---------|
| `GetNamespace()` | Returns `POD_NAMESPACE` env var, falling back to `"kwatch"` |
| `kubelet.GetPodContainerLogs(...)` | Fetches bounded container logs (with a 15s timeout and one retry) |
| `GetPodEvents(ctx, c, name, ns)` | Fetches recent events for a pod via field selector |
| `GetNodeSummary(ctx, c, node)` | Fetches a node's kubelet `/stats/summary` through the API server proxy |
| `IsNodeReady(n)` / `GetNodes(ctx, c)` | Node condition helpers |

### HTTP transport

```
// Outbound HTTP is created once by internal/client from RuntimeConfig.
// Operation-specific deadlines are supplied with context.Context.
```

---

## 13. `internal/client/` — Kubernetes Client

**Path:** `internal/client/client.go`

### Role

Creates the application-owned external dependency bundle. Consumers receive
only the narrow dependency they need.

```go
type ClientSet struct {
    Kubernetes kubernetes.Interface
    Dynamic    dynamic.Interface
    Discovery  discovery.DiscoveryInterface
    REST       rest.Interface
    HTTP       *http.Client
    Resolver   HostResolver
    Clock      clock.Clock
}

func NewClientSetWithRuntime(
    runtime config.RuntimeConfig,
    resolver HostResolver,
    now clock.Clock,
) (ClientSet, error)
```

The application calls this once after configuration overlays are compiled.
Canonical constructors reject missing required dependencies; they do not use
default HTTP clients, DNS resolvers, clocks, or hidden context values.

---

## 14. `internal/persistence/` — State Persistence

**Domain path:** `internal/persistence/`

The ConfigMap implementation lives in `internal/persistence/`. The persisted
wire format and ConfigMap names remain unchanged.

### Role

kwatch keeps its state in **plain ConfigMaps** in its own namespace — no
database, no volume. The `Manager` exposes narrow stores for restart-critical
state and migration reporting:

| ConfigMap | Contents |
|-----------|----------|
| `kwatch-state` | Cluster identity, startup metadata, upgrade bookkeeping, and `last-seen` |
| `kwatch-baseline` | Pre-existing problems seen at startup |
| `kwatch-incidents` / `kwatch-groups` | Active incidents and smart-group state |
| `kwatch-engine` / `kwatch-threads` | Engine and provider thread state |
| `kwatch-pvc` | Last-known PVC usage samples |
| `kwatch-changes` / `kwatch-telemetry` | Change history and telemetry state |
| `kwatch-rca` | Persisted RCA feedback and analysis state when enabled |

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

Startup produces one migration report containing every store operation. Missing
state is a safe first-run condition; corrupt, malformed, or future-version
state is preserved and reported rather than silently overwritten. Active
monitoring and delivery do not start until required restore operations succeed.

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
| `/health` | GET | Leadership, component, and bounded degradation status |
| `/readyz` | GET | Ready only for an active leader with restore, required sources/caches, persistence writers, incident processing, and configured delivery ready |
| `/availabilityz` | GET | Deployment availability for an elected leader or standby |
| `/metrics` | GET | Prometheus metrics (text format) |
| `/incidents` | GET | Active incidents as JSON (diagnostics only) |
| `/test-alert` | POST | Send a test notification (diagnostics only) |
| `/deadletters` | GET | Failed-delivery ring buffer (diagnostics only) |

Incident, test-alert, and dead-letter endpoints require
`healthCheck.diagnostics: true`. All protected diagnostic endpoints, including
informer, persistence, security, kubelet, and control-plane status, require a
configured Bearer token (`diagnosticsToken`, constant-time compared); an empty
token never permits anonymous access. `healthCheck.pprof` adds
`/debug/pprof/*` behind the same guard. `/metrics` is always served. Optional
API absence remains degraded but does not fail readiness. Health owns only the
HTTP listener; application supervision owns serving, cancellation, and
shutdown.

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
| `NewStartupManagerWithClock(state, appCfg, clock)` | Creates the startup decision component |
| `Start(ctx)` | Ensures cluster state and returns the startup decision |
| `RecordAlive(ctx)` | Stamps `last-seen` once a minute |
| `Result.ShouldNotify` | Tells application composition whether startup is news |

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
the supported live-reloadable fields at runtime. A change is compiled into a
new immutable runtime snapshot and applied through the reload boundary; it does
not mutate provider or source state in place. Missing CRDs are reported as a
waiting/degraded condition, while discovery and cache-sync failures have
bounded deadlines and safe diagnostics.

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

**Path:** `internal/app/`

### Role

`app.Run()` loads the config and wires every component in order — the shared
client set, startup/persistence, delivery manager, health listener, Lease
election, graph, insight engine, incident engine, monitor runtimes, and
controller — then runs until shutdown. Semantic files separate bootstrap,
runtime construction, election, supervision, persistence gates, optional
components, and serving. The application also owns the hooks that make the
engine the single notification door:

- **`lifecycleHook`** — for every non-skipped incident edge, audits the event
  and calls `delivery.Manager.NotifyIncident(inc, action, insight)` with a
  diagnosis computed by `insight.Engine.Analyze`.
- **`massFailureHook`** — runs `insight.ScanMassFailures` on the lifecycle
  tick, opening and resolving shared-dependency incidents.
- **`onBaselineChange` / persistence components** — forward baseline and
  incident snapshots to the state ConfigMaps after producer shutdown rules.
- **`restoreIncidents`** — rehydrates `kwatch-incidents` back into the engine
  at startup so a restart resumes exactly where it left off.
