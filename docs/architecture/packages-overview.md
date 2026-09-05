---
sidebar_position: 2
title: Core Packages
description: kwatch core internals — entry point, config, controller, handler, filter pipeline, enricher, event types, and domain model
keywords: [kwatch, kubernetes, architecture, packages, cmd, config, controller, handler, filter, enricher, event, model]
pagination_prev: architecture/overview
pagination_next: architecture/correlation-and-alerting
---

# 🧩 Core packages

This page maps the main Go packages to the job they do. You do not need to know
all of them to run kwatch; use it as a guide when changing the code.

## 1. `cmd/kwatch/main.go` — Entry Point

**Path:** `cmd/kwatch/main.go`

This is the binary entry point. It parses flags, dispatches subcommands, and
otherwise starts the server through `internal/app.Run()`:

| Mode | Invocation | Description |
|------|-----------|-------------|
| **Runtime** | `kwatch` | Load config and run the full controller (`app.Run()`) |
| **Version** | `kwatch --version` | Print the build version and exit |
| **Lint** | `kwatch lint [--strict] [--check]` | Validate config; optionally verify supported provider credentials |
| **Replay** | `kwatch replay [--dry-run] < events.jsonl` | Send or preview JSONL events without a live cluster |

Only one mode runs at a time; the runtime mode is the default.

### Startup sequence (runtime mode)

`internal/app.Run()` is the composition root. It wires everything in order:

1. `config.LoadConfig()` — reads `CONFIG_FILE` (default `/config/config.yaml`), applies defaults, validates, and builds the suppression index
2. `k8s.InitHTTPClient()` — configures proxy and TLS for outbound HTTP
3. `client.Create()` — builds the Kubernetes clientset
4. `startup.HandleStartup()` — cluster ID, state ConfigMaps, liveness stamp
5. `health.NewHealthServer()` — starts the health/metrics HTTP server
6. `alert.AlertManager` — initialized by the startup manager, then silences/templates/max-log-lines applied and delivery started
7. `upgrader.NewUpgrader()` — background daily (24h) update check
8. `state.GetBaseline()` — loads pre-existing problems; legacy baseline migrated
9. `kwcontext.NewChangeTracker()` + `kwcontext.NewResourceGraph()` — the change log and dependency graph
10. `insight.NewEngine()` — cause / impact / what-changed analysis over the graph
11. `correlation.NewEngine()` — the incident lifecycle engine (the only emitter of notifications)
12. `pvc.NewPvcMonitor()`, `heartbeat.NewHeartbeatMonitor()` — periodic watchdogs
13. `handler.NewHandler()` — the event processor
14. `controller.New()` — wires informers and starts workqueues
15. `serve()` — blocks until SIGTERM/SIGINT

### CLI flags

| Flag | Description |
|------|-------------|
| `--version` | Print version and exit |
| `--strict` (lint) | Strict YAML unmarshal (catches typos) |
| `--check` (lint) | Validate config + test credentials for supported providers |

---

## 2. `internal/config/` — Configuration System

**Path:** `internal/config/`

### Role

The central configuration system. Defines the full `Config` struct, applies
defaults, performs semantic validation, and resolves Secret-backed
`${file:/absolute/path}` values. `${VAR}` expansion is limited to
non-sensitive strings. It also builds the suppression index from `silences`
and the legacy `ignore*` fields.

### Key types

```go
type Config struct {
    App                          App      // cluster name, proxy, TLS, logging
    Upgrader                     Upgrader // update-check toggle
    ContainerRestartThreshold    int      // restarts while Running → incident
    PvcMonitor                   PvcMonitor
    HeartbeatMonitor             HeartbeatMonitor
    NodeMonitor                  NodeMonitor
    HealthCheck                  HealthCheck // health/metrics server
    Correlation                  Correlation // incident lifecycle
    ReportStartupBaseline        bool
    MaxRecentLogLines            int64
    IgnoreFailedGracefulShutdown bool
    Namespaces                   []string // ! prefix = exclude
    Reasons                      []string // ! prefix = exclude
    IgnoreContainerNames         []string
    IgnorePodNames               []string // regexp patterns
    IgnoreLogPatterns            []string
    IgnoreContainerMessages      []string
    IgnoreDisruptionTerminations *bool
    NamespaceSelector            string
    IncludeEvents                *bool
    IncludeLogs                  *bool
    Alert                        map[string]map[string]interface{} // providers
    SeverityByOwnerKind          map[string]string
    SeverityByReason             map[string]string
    ScheduleMonitor              ScheduleMonitor
    OomMonitor                   OomMonitor
    PendingPodMonitor            PendingPodMonitor
    NotReadyMonitor              NotReadyMonitor
    RolloutMonitor               RolloutMonitor
    JobMonitor                   JobMonitor
    StatefulSetMonitor           StatefulSetMonitor
    PdbMonitor                   PdbMonitor
    NodeResourceMonitor          NodeResourceMonitor
    DaemonSetMonitor             DaemonSetMonitor
    CronJobMonitor               CronJobMonitor
    ClusterAutoscalerMonitor     ClusterAutoscalerMonitor
    HpaMonitor                   HpaMonitor
    TlsMonitor                   TlsMonitor
    ServiceMonitor               ServiceMonitor
    AdmissionWebhookMonitor      AdmissionWebhookMonitor
    ControlPlaneMonitor          ControlPlaneMonitor
    IngressMonitor               IngressMonitor
    NetworkPolicyMonitor         NetworkPolicyMonitor
    Silences                     []SilenceRule
    Workers                      int
    Inhibition                   Inhibition
    SmartGrouping                SmartGrouping
    CrdConfig                    CrdConfig
    Templates                    map[string]string
    Runbooks                     map[string]string
    AuditLog                     AuditLogConfig

    // Internal fields (populated at load time):
    AllowedNamespaces   []string
    ForbiddenNamespaces []string
    AllowedReasons      []string
    ForbiddenReasons    []string
    IgnorePodNamePatterns []*regexp.Regexp
    Suppression         SuppressionIndex
    WatchStartTime      time.Time
}
```

Every monitor (`nodeMonitor`, `oomMonitor`, `pendingPodMonitor`,
`rolloutMonitor`, `hpaMonitor`, `tlsMonitor`, and the rest) shares the pattern:
an `Enabled` bool plus the monitor's own timing/threshold fields.

### Key sub-structs

| Struct | Fields | Purpose |
|--------|--------|---------|
| `App` | `proxyURL`, `clusterName`, `disableStartupMessage`, `logFormatter`, `insecureSkipTLSVerify`, `caBundlePath` | Application-level settings |
| `Correlation` | `window`, `lifecycleInterval`, `resolveHoldDown`, `cooldownMinutes`, `maxBaseline`, `escalation`, `renotify` | Incident lifecycle and dedup |
| `EscalationConfig` | `enabled`, `tiers` (default `[3, 10]`) | Restart-count severity escalation |
| `RenotifyConfig` | `intervalBySeverity`, `maxPerIncident` (default 3) | Periodic re-alerting for long-lived incidents |
| `SmartGrouping` | `windowSeconds` (default 60), `namespaceFanOutThreshold` (default 3) | Coalescing same-reason incidents into one notification |
| `Inhibition` | `nodeSuppressesPods` (default true) | Pod alerts suppressed while their node is down |
| `HealthCheck` | `enabled`, `port` (default 8060), `pprof`, `diagnostics`, `diagnosticsToken` | Health server |
| `AuditLogConfig` | `enabled`, `output` (`stdout` or file path) | Structured JSON audit log |
| `SilenceRule` | `namespaces`, `reasons`, `podNamePatterns`, `logPatterns`, `nodeReasons`, ... | Alert suppression rules |
| `AlertRoute` | `namespaces`, `severities`, `reasons` | Per-provider routing filters |

`config.KnownProviders` is the canonical set of provider names (56). Both
`alert.Init` and config validation reference it, so a typo is caught before a
provider is silently skipped.

### Loading flow

1. `LoadConfig()` reads YAML from `CONFIG_FILE`
2. Rejects plain credentials and non-absolute secret references
3. Expands `${VAR}` for non-sensitive strings and resolves `${file:/path}`
4. Merges defaults
5. Runs semantic validation
6. Builds the suppression index from `Silences` plus the deprecated `ignore*`
   fields (folded into synthetic `SilenceRule`s)
7. The `*Config` is passed to every component

There is no storm-digest or LLM configuration: kwatch ships exactly one kind
of notification pipeline.

---

## 3. `internal/controller/` — Informer Controller

**Path:** `internal/controller/`

### Role

Wires informers with shared indexers and rate-limited workqueues. Every watched
kind is boiled down to one abstraction: a `resourcePipeline` (`pipeline.go`)
bundles a named rate-limiting queue, informer sync state, a sync function, and
a `startWorkers` flag that gates both worker startup and baseline seeding.

### Key types

```go
type Controller struct {
    // one pipeline per watched resource kind
    pipelines map[string]*resourcePipeline
    graph     *graphcontext.ResourceGraph
    tracker   *graphcontext.ChangeTracker
    handler   *handler.Handler
    ...
}
```

`New()` constructs all pipelines; per-kind wiring lives in small `wire*`
functions in `wiring.go` that attach listers/informers via:

- `watch(pipeline, informers...)` — registers `HasSynced` + event handler and starts workers
- `listen(pipeline, informers...)` — attaches handlers only

Sync dispatch functions in `sync.go` share one signature:
`func (c *Controller) syncX(_ context.Context, key string) error`. Event
handlers come from `enqueue.go`: `recordChange` /
`changeRecordingHandler` feed the change tracker, and a graph-aware pod
handler keeps the dependency graph fresh. Graph edges are declared in
`graph_resources.go`.

### Watched resources

| Informer | Monitors it enables |
|----------|---------------------|
| Pod | Core pod monitoring (restarts, OOM, CrashLoop, unschedulable, not-ready, ...) |
| Event | Pod event enrichment, cluster-autoscaler events |
| Node | `nodeMonitor`, `nodeResourceMonitor` |
| Deployment | `rolloutMonitor` |
| StatefulSet | `statefulSetMonitor` |
| DaemonSet | `daemonSetMonitor` |
| Job | `jobMonitor` |
| CronJob | `cronJobMonitor` |
| HPA | `hpaMonitor` |
| PDB | `pdbMonitor` |
| Secret | `tlsMonitor` (certificate expiry sweeps) |
| Service | `serviceMonitor` |
| Ingress | `ingressMonitor` |
| NetworkPolicy | `networkPolicyMonitor` |
| Mutating/Validating Webhook | `admissionWebhookMonitor` |

### Startup baseline

Starting a worker seeds baseline entries for problems that already exist, so a
restart doesn't re-announce everything already broken. Baseline snapshots are
persisted to the `kwatch-baseline` ConfigMap.

---

## 4. `internal/handler/` — Event Handler

**Path:** `internal/handler/`

### Role

Turns raw Kubernetes objects into candidate incidents (filters + hints). One
interface is implemented once; the controller's sync functions call into it.

```go
type Handler interface {
    ProcessPod(ctx, key, deleted) error
    ProcessNode(key, deleted) error
    ProcessDeployment(key, deleted) error
    ProcessJob(key, deleted) error
    ProcessDaemonSet(key, deleted) error
    ProcessCronJob(key, deleted) error
    ProcessStatefulSet(key, deleted) error
    ProcessPdb(key, deleted) error
    ProcessHorizontalPodAutoscaler(key, deleted) error
    ProcessMutatingWebhookConfiguration(key, deleted) error
    ProcessValidatingWebhookConfiguration(key, deleted) error
    ProcessService(key, deleted) error
    ProcessNetworkPolicy(key, deleted) error
    ProcessIngress(key, deleted) error
    ProcessControlPlanePod(pod) error
    ProcessNodeResourceOvercommit(...)
    ProcessClusterAutoscalerEvent(ev *corev1.Event)
    SetListers(Listers)
}
```

The handler gets all its informer-backed lookups in one `handler.Listers`
value via `SetListers`, installed after all informers are wired. A nil lister
means "that monitor is off". When a pod evaluation finishes the filter
pipeline, the handler builds an `event.Signal`/`event.Event` and hands it to
`correlation.Engine.Process` — it never notifies on its own.

---

## 5. `internal/filter/` — Filter Pipeline

**Path:** `internal/filter/`

### Role

Provides the detector and enricher interfaces the handler uses to evaluate a
pod. Data flows through a `filter.Context`, which is composed of three parts:

- **Sources** — read-only lookups the handler sets once (client, config,
  listers, an injected `Now` clock). A filter never writes Sources.
- the **object under evaluation** (Pod, EvType, Owner, Events);
- **Findings** — what the detectors concluded.

```go
type Status int

const (
    StatusSkip     Status = iota // stop evaluating this pod
    StatusAlert                  // this pod needs an alert
    StatusContinue               // keep checking
)

type Detector interface {
    Detect(ctx *Context) Status
}

type Enricher interface {
    Enrich(ctx *Context) (shouldSkip bool)
}
```

### The filters

| File | Type | Purpose |
|------|------|---------|
| `namespace_filter.go` | Detector | Skips forbidden namespaces |
| `pod_name_filter.go` | Detector | Skips ignored pod-names (regexp) |
| `pod_status_filter.go` | Detector | Detects pod-level issues (Unschedulable, etc.) |
| `pending_pod_filter.go` | Detector | Detects pods stuck in Pending beyond threshold |
| `not_ready_filter.go` | Detector | Detects sustained not-ready pods |
| `disruption_filter.go` | Detector | Suppresses evictions/drains when `ignoreDisruptionTerminations` |
| `container_name_filter.go` | Detector | Skips ignored container names |
| `container_restarts_filter.go` | Detector | Detects restarts exceeding threshold |
| `container_state_filter.go` | Detector | Detects waiting/terminated container states |
| `container_reasons_filter.go` | Detector | Extracts a reason, dedups by last known state |
| `noise_filter.go` | Detector | Suppresses transient reasons (`Started`, `Created`, ...) |
| `container_message_filter.go` | Detector | Checks container status messages for patterns |
| `pod_events_filter.go` | Enricher | Fetches pod events from the informer cache |
| `pod_owners_filter.go` | Enricher | Resolves owner (Deployment/StatefulSet/DaemonSet) |
| `container_killing_filter.go` | Enricher | Detects graceful-shutdown failures |
| `container_logs_filter.go` | Enricher | Fetches container logs from the K8s API |

Detectors write `Findings`; enrichers fill in logs, events, owner, and hint.
Time-based decisions read the injected clock (`Sources.Now`), never
`time.Now()` directly, so "unready for 5 minutes" is testable without waiting
5 minutes.

---

## 6. `internal/enricher/` — Severity & Hints

**Path:** `internal/enricher/`

### Role

Resolves incident severity and builds diagnostic hints. The
`DefaultEnricher` derives severity from the incident reason and the owner
kind:

```go
type Enricher interface {
    Enrich(ev *event.Event, inc *model.Incident)
}

var defaultSeverityByOwnerKind = map[string]string{"StatefulSet": "high"}
var defaultSeverityByReason = map[string]string{
    "Evicted":          "medium",
    "ImagePullBackOff": "medium",
}
```

Both maps are overridable via `severityByOwnerKind` / `severityByReason`
config. Reason beats owner kind; severity resolution is *monotonic* — once
raised, an incident's severity never downgrades until it resolves.

Hints live in `hints.go`: a `defaultHints` map per reason ("Memory pressure —
consider increasing memory limits") and an `exitCodeHints` map (137 → SIGKILL,
143 → SIGTERM, ...). When a hint is missing, the enricher falls back to the
reason map, and `signatures.go` adds pattern-based hints for common log
signatures (repeating OOM, probe failures, image pull errors).

---

## 7. `internal/event/` — Event Types & Formatting

**Path:** `internal/event/`

### Role

Defines `event.Event` (the notification payload), `event.Signal` (the internal
incident source), formatters, and the HTTP-status classification every
provider shares.

### Key types

```go
type Event struct {
    Resource      string // "pod", "node", "pvc"
    PodName       string
    ContainerName string
    Image         string
    Message       string
    Namespace     string
    NodeName      string
    Reason        string
    Events        string // K8s event text
    Logs          string // container logs
    Labels        map[string]string
    OwnerKind     string
    RestartCount  int
    Facts         model.Facts // structured details behind Hint
    Hint          string      // precomputed, or auto-generated from Reason
    Severity      model.Severity
    IncludeEvents bool
    IncludeLogs   bool
    Action        string // "create", "update", "resolved"; "" = legacy path
    DedupKey      string // stable per-incident key
}
```

`event.Signal` (in `signal.go`) is the structured incident source the handler
builds and the correlation engine consumes: kind, namespace, owner, resource,
reason, node, container, image, restart count, severity, logs/events, pod
name, hint, facts, labels, and an optional pre-built `ContainerState`.

### Formatters

| Function | Output |
|----------|--------|
| `FormatMarkdown(clusterName, text, delimiter)` | Rich markdown with sections |
| `FormatHtml(clusterName, text)` | HTML body (email) |
| `FormatText(clusterName, text)` | Plain text |

### Retry classification

`event` also carries the error taxonomy used by delivery:

- `RetryAfterError` — a 429 with a `Retry-After` duration
- `PermanentError` / `event.Permanent(err)` — a failure retrying cannot fix
- `IsPermanentHTTPStatus` — 4xx is permanent except 408 and 429

---

## 8. `internal/model/` — Core Domain Types

**Path:** `internal/model/incident.go`

### Role

Defines the core domain types: `Incident`, `IncidentView`, `ContainerState`,
`Facts`, `PersistedIncident`, and the action/state enums.

### The Incident

`Incident` is five embedded parts, each with a single writer:

```go
type Incident struct {
    Subject      // what it is about (set at creation)
    Status       // what is happening now (refresh path)
    Evidence     // why — hint, facts, logs, events, runbook
    Attribution  // how it relates to other incidents (attribution stage)
    Delivery     // notification bookkeeping (engine's edge detection only)
}
```

Embedded, so promoted reads work as you'd expect (`inc.Reason`,
`inc.Count`); only composite literals name the part.

### Incident state machine

```
                ┌──────────┐
                │  Active   │ ◄────── new event
                └────┬─────┘
                     │ condition clears + hold-down expires
                     ▼
             ┌───────────────┐
             │ PendingResolve │
             └───────┬───────┘
                     │ no recurrence
                     ▼
              ┌──────────┐
              │ Resolved  │
              └──────────┘
```

### Incident actions

| Action | When emitted |
|--------|-------------|
| `ActionCreate` | First time an incident is seen |
| `ActionUpdate` | Same incident, new event (count/severity/evidence refresh) |
| `ActionSkip` | No observable change (edge-trigger suppressed) |
| `ActionResolved` | Incident transitioned to resolved |

`IncidentView` is the read-only shape served over `/incidents`;
`PersistedIncident` is the flat on-disk format stored in the
`kwatch-incidents` ConfigMap (its shape must not change).
