---
sidebar_position: 2
title: Core Packages
description: kwatch core internals — entry point, config, controller, monitor families, incident lifecycle, delivery, and domain model
keywords: [kwatch, kubernetes, architecture, packages, cmd, config, controller, monitor, incident, delivery, model]
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

`internal/app.Run()` is the composition root. It wires everything in phases:

1. Load and validate the external YAML configuration.
2. Compile one immutable `config.RuntimeConfig` snapshot after defaults and
   CRD overlays.
3. Build the application-owned Kubernetes, dynamic, discovery, REST, HTTP,
   DNS, kubelet, and clock dependencies.
4. Open the health listener and initialize delivery, persistence, and startup
   state without starting active monitoring.
5. Acquire the Kubernetes Lease. Standby replicas keep only election and
   health serving active.
6. Restore persisted incident, group, baseline, engine, thread, PVC, and
   migration state before active processing begins.
7. Construct the graph, insight engine, incident engine, monitor families, and
   typed source bundles.
8. Start the controller, wait for required informer synchronization, then
   start optional monitors and integrations through the application supervisor.
9. Serve until cancellation, leadership loss, or a required component failure.

The application owns component ordering, cancellation, completion, failure
reporting, and bounded shutdown. Health owns only its HTTP listener; delivery
owns provider-generation internals but not top-level application shutdown.

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
and the legacy `ignore*` fields. After overlays and validation, the application
compiles one immutable `RuntimeConfig` snapshot. Production components receive
grouped runtime views rather than reparsing the YAML-shaped `Config`.

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
| `SilenceRule` | `namespaces`, `reasons`, `podNamePatterns`, `logPatterns`, `containerMessages`, `eventMessages`, `nodeReasons`, ... | Alert suppression rules |
| `AlertRoute` | `namespaces`, `severities`, `reasons` | Per-provider routing filters |

`config.IsKnownProvider` and `config.KnownProviderNames` expose the canonical
provider registry without allowing callers to mutate it. Delivery and config
validation share that registry, so a typo is caught before a provider is
silently skipped.

### Loading flow

1. `LoadConfig()` reads YAML from `CONFIG_FILE`
2. Rejects plain credentials and non-absolute secret references
3. Expands `${VAR}` for non-sensitive strings and resolves `${file:/path}`
4. Merges defaults
5. Runs semantic validation
6. Builds the suppression index from `Silences` plus the deprecated `ignore*`
   fields (folded into synthetic `SilenceRule`s)
7. The immutable `RuntimeConfig` snapshot is passed through grouped views to
   runtime components

Raw `config.Config` is kept at the external-schema boundary. Production
components do not retain it or reparse YAML-shaped maps. Raw configuration is
limited to loading, decoding, overlays, migrations, command boundaries, and
explicit compatibility code.

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
    runtimes  controller.RuntimeSet // narrow family capabilities
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

## 4. `internal/monitor/` — Monitor Families

**Paths:** `internal/monitor/pod/`, `internal/monitor/pod/policy/`,
`internal/monitor/pod/enrichment/`, `internal/monitor/workload/`,
`internal/monitor/node/`, `internal/monitor/network/`,
`internal/monitor/security/`

Monitor families own detection policy for a cohesive domain. The Pod family is
the reference implementation:

- `monitor/pod/policy` contains deterministic, clock-injected Pod and
  container decisions. It has no listers, Kubernetes clients, event sources,
  logs, delivery, or persistence.
- `monitor/pod` owns detector ordering and the boundary between policy and
  enrichment.
- `monitor/pod/enrichment` owns event, owner, log, and API-backed suppression
  enrichment. It receives explicit read-only sources.
Each family produces observations for the incident engine. It does not build
incident keys, notify providers, or write persisted state. The controller
dispatches through `controller.RuntimeSet`; there is no broad handler façade
in the production detection path.

## 5. `internal/controller.RuntimeSet` — Family Wiring Boundary

**Path:** `internal/controller/runtime.go`

### Role

Connects controller-owned informer sources to the matching monitor family.
The controller owns queues, listers, synchronization, and resource keys; each
family runtime owns detection and observation construction. There is no broad
handler contract in the production path.

```go
type RuntimeSet struct {
    IncidentSources IncidentSourceConfig
    Pod             PodRuntime
    Workload        WorkloadRuntime
    Node            NodeRuntime
    Network         NetworkRuntime
    Security        SecurityRuntime
    Cluster         ClusterRuntime
    Integration     IntegrationRuntime
}
```

Each bundle exposes only the processor and source configuration needed by its
family. The application constructs the bundles explicitly, while the
controller supplies synchronized sources through each family’s one-time
`ConfigureSources` operation. Missing sources skip detection and are
reported through health diagnostics; they never create synthetic incidents.
Families send observations to the incident sink; they never notify providers
or write persistence directly.

---

## 6. `internal/monitor/pod/enrichment/` — Pod Evidence Enrichment

**Path:** `internal/monitor/pod/enrichment/`

### Role

The package adds Kubernetes-backed evidence after deterministic policy has
identified a possible problem. Data flows through an explicit enrichment
context:

- **Sources** — read-only enrichment lookups (client, listers, event index,
  log cache, and injected clock). Enrichers never write Sources.
- **Object** — Pod, owner, and loaded Events.
- **Findings** — policy conclusions copied from `pod/policy`.

```go
type Enricher interface {
    Enrich(ctx *Context) (shouldSkip bool)
}
```

The Pod family packages are the canonical implementation. New code should
import `monitor/pod/policy` for deterministic rules and
`monitor/pod/enrichment` for Kubernetes-backed evidence.

### The enrichers

| File | Type | Purpose |
|------|------|---------|
| `monitor/pod/policy` | Detector rules | Pure Pod/container policy decisions |
| `enrichment/pod_events.go` | Enricher | Uses indexed or cached Pod events |
| `enrichment/pod_owners.go` | Enricher | Resolves owner through shared listers |
| `enrichment/container_killing.go` | Enricher | Detects graceful-shutdown failures |
| `enrichment/container_logs.go` | Enricher | Fetches bounded container logs |

Policy writes only policy `Findings`; enrichers fill in logs, events, and
owner. Time-based decisions read the injected clock, never
`time.Now()` directly, so "unready for 5 minutes" is testable without waiting
5 minutes.

---

## 7. `internal/enricher/` — Severity & Hints

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

Defines `event.Event` (the provider-facing notification payload), observation
conversion helpers, formatters, and the HTTP-status classification every
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

`model.Observation` is the structured source a monitor builds. The incident
engine converts it to `event.Event` in one place, preserving kind, namespace,
owner, resource, reason, node, container, evidence, facts, labels, and the
optional pre-built `ContainerState`.

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
