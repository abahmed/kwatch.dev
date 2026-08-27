---
sidebar_position: 3
title: Correlation & Alerting
description: kwatch correlation engine, alert manager, and insight engine — incident lifecycle, dedup, escalation, smart grouping, delivery, and cause/impact analysis
keywords: [kwatch, kubernetes, architecture, correlation, alert, insight, incident lifecycle, dedup, escalation]
pagination_prev: architecture/packages-overview
pagination_next: architecture/infrastructure-packages
---

# Correlation & Alerting

## 9. `internal/correlation/` — Correlation Engine

**Path:** `internal/correlation/`

### Role

The brain of kwatch. It runs every observed event through a fixed five-stage
decision pipeline — baseline, attribution, cooldown, identity, announcement —
and manages the incident lifecycle (CREATE / UPDATE / RESOLVE / SKIP).
It is also the **only** emitter of notifications: every decision — a live
event, a resolve, a group flush, a re-notification, a mass failure — leaves
through `emit.go` and the `LifecycleHook`, so audit, diagnosis and delivery
cannot diverge between paths.

### Key types

```go
type Engine struct {
    state              map[model.IncidentKey]*model.Incident
    namespaceIndex     map[string]map[model.IncidentKey]*model.Incident
    config             Config
    baseline           map[string]map[string]int64 // startup baseline
    activeNodeIncidents map[string]bool
    groupBuffers       map[string]*pendingGroup
    groupResolveTrackers map[string]*groupResolveTracker
    massFailures       map[model.IncidentKey]*model.Incident
    ...
}

type Config struct {
    Window                     time.Duration
    LifecycleInterval          time.Duration
    Enricher                   enricher.Enricher
    LifecycleHook              func(*model.Incident, model.IncidentAction)
    MassFailureHook            func()
    BaselineTTL                time.Duration
    Baseline                   map[string]map[string]int64
    EscalationEnabled          bool
    EscalationTiers            []int
    InhibitNodeSuppressesPods  bool
    MaxBaseline                int
    RenotifyIntervalBySeverity map[string]time.Duration
    RenotifyMaxPerIncident     int
    ResolveHoldDown            time.Duration
    Runbooks                   map[string]string
    SmartGroupingWindow        time.Duration
    NamespaceFanOutThreshold   int
    DependenciesOf             func(*model.Incident) []string
}
```

### The five decision stages

Every event — a crashing container, a node condition, a stuck rollout — walks
the same stages in `processLocked`, in this order. Each stage can end the
story:

| # | Stage | Question | If yes |
|:--|:--|:--|:--|
| 1 | **Baseline** | Was this already broken when kwatch started? | Stay quiet; it is not news. |
| 2 | **Attribution** | Is this a *symptom* of something already known? | Record it against the cause — count it, list it — and let the cause's alert speak for it. |
| 3 | **Cooldown** | Did this exact problem resolve a few minutes ago? | Revive silently; no "resolved → crash → resolved" ping-pong. |
| 4 | **Identity** | Which incident is this? | Update the existing one (or fold a crash loop into its canonical key) instead of opening a new one. |
| 5 | **Announcement** | Should it speak now? | Buffer it for its group, or send on the edge — only when something observable changed. |

Attribution runs *before* the cooldown check on purpose, and recognises three
kinds of cause, broadest first: a **node condition** (the pod's node is
NotReady or under pressure), a **shared dependency** (a mass failure already
covers the ConfigMap/Secret/node this resource depends on), and the **owning
workload** (the pod's own Deployment or Job already has an incident).

### Dedup keys

Incidents are keyed by `namespace:owner:reason:container`, normalized so a
crash-looping container reports one canonical key regardless of its momentary
state (`Error`, `OOMKilled` and `CrashLoopBackOff` all fold into the loop's
key once the restart count passes the threshold). Image-pull failures caused
by rate limits, registry timeouts, DNS or TLS use a *global* key so the same
underlying issue maps to a single incident even across namespaces.

### Edge-triggered notification

`notifSig` renders `firing|<severity>` or `resolved|<severity>`. A
notification is only sent when that signature changes, which prevents
duplicate alerts on every poll while an incident is active.

### Incident lifecycle

- **CREATE** — first sighting of a problem; kwatch notifies.
- **UPDATE** — the same problem recurs; the incident's evidence is refreshed
  and, in most cases, kwatch stays quiet.
- **RESOLVE** — the problem stops; kwatch waits the resolve hold-down
  (`correlation.resolveHoldDown`, default 5 minutes) for brief blips to clear
  themselves, then sends "resolved".
- **SKIP** — anything not yet worth announcing (already reported, cooling
  down, silenced, buffered in a group).

Two behaviors keep this honest:

- **Cooldown after resolve.** When an incident resolves, kwatch arms a
  cooldown (`cooldownMinutes`, default 10). If the identical problem
  reappears inside it, it is revived silently.
- **Escalation.** Repeated restarts climb tiers (default `[3, 10]`); each
  crossing re-notifies with a higher severity.
- **Re-notify.** Long-lived incidents can be nudged again on a timer
  (`renotify.intervalBySeverity`), up to `maxPerIncident` times (default 3).
- **Node inhibition.** When `inhibition.nodeSuppressesPods` is true (default),
  pod incidents on a node with an active node incident are suppressed and
  counted against the node alert; suppression lifts the moment the node
  recovers.

### Mass-failure detection

On every lifecycle tick, `MassFailureHook` calls
`insight.ScanMassFailures`: it scans all active incidents for a shared
dependency (node, ConfigMap, Secret, PVC) and fires a mass-failure alert when
**30% or more** of the dependents that share it are failing (with a minimum of
3). Mass failures are treated like any incident — root cause explained,
auto-resolved when the underlying incidents clear — and symptoms covered by
them stay silent via attribution.

### Smart grouping

Some failures are one failure wearing many masks. Events that arrive inside
the grouping window (`smartGrouping.windowSeconds`, default 60) and share a
root dimension are buffered and flushed as a **single notification**. When
more than a namespace fan-out threshold of owners fail the same way in one
namespace, their groups collapse into one namespace-level notification.
Groups re-notify on a stable key after a cooldown of `4×` the grouping window
(clamped 5–30 minutes), batch-resolve when every member recovers, and fold
more than ~1,000 members into an overflow counter.

### Key functions

| Function | Purpose |
|----------|---------|
| `NewEngine(cfg)` | Creates the engine |
| `Process(ev, owner, cs)` | Runs one observed event through the five stages and announces whatever it decides |
| `RestoreIncidents(map)` | Rehydrates persisted incidents from the `kwatch-incidents` ConfigMap |
| `Snapshot()` / `SnapshotAll()` | Incident views for `/incidents` |
| `ActiveCount()` | Number of currently active incidents |
| `AddMassFailure` / `RemoveMassFailure` | Track synthetic shared-dependency incidents |

Every decision is written to the audit log once per incident (not once per
poll) — the skip reasons `baseline`, `node_inhibition`, `mass_failure`,
`cascading_suppression`, and `cooldown` are stable strings people grep for.

---

## 10. `internal/alert/` — Alert Manager

**Path:** `internal/alert/`

### Role

Dispatches incidents to configured providers. One `AlertManager`
(`manager.go`) owns per-provider entries — each with its own routes, retry
config, fallback, templates, byte limit, and buffered channel — plus the
silence index and the dead-letter queue. Delivery plumbing lives in
`delivery.go` (`deliverOne`, `fanOut`, `sendWithRetry`), routing in
`routing.go`, and the reject-classification that every HTTP provider shares
in `alert/util`.

```go
type AlertManager struct {
    entries     []providerEntry // one per configured provider
    silences    []silenceMatcher
    templates   map[string]*template.Template
    maxLogLines int
    clusterName string
    dlqRing     [100]DeadLetterEntry // ring buffer
    ...
}

type Provider interface {
    Name() string
    SendEvent(*event.Event) error
    SendMessage(string) error
}
```

### Delivery architecture

```
LifecycleHook fires (incident + action)
        │
        ▼
AlertManager.NotifyIncident(inc, action, insight)
        │
        ▼
Silence check ──── match? → DROP (not even logged as a delivery)
        │ no match
        ▼
fanOut: clone incident → one deliverJob per provider channel (cap 256)
        │ non-blocking
        ▼
Channel saturated? ──→ drop the arriving job + record dead-letter
        │ delivered
        ▼
Provider worker: deliverOne
        │
        ├── routes match? ── no match → SKIP this provider
        ├── build message (ReportBuilder + per-provider renderer) → truncate
        ├── sendWithRetry:
        │     • 2xx        → success
        │     • 429        → ratelimit.Error, honour Retry-After (header or body)
        │     • other 4xx  → permanent, dead-letter immediately
        │     • 5xx / transport → retried with backoff
        └── all attempts failed?
            ├── fallback configured? → try the fallback provider
            └── else → add to the dead-letter queue /deadletters
```

### Provider interface variants

| Interface | Description |
|-----------|-------------|
| `Provider` | Base interface (Name, SendEvent, SendMessage) |
| `ThreadProvider` | Sends a full `*model.Incident` + action (threaded conversations) |
| `InsightThreadProvider` | Like `ThreadProvider` but also receives the `*insight.Insight` diagnosis |
| `EventDeliveryProvider` | Marker for providers that use `SendEvent` |
| `VerifiableProvider` | Supports credential verification (`kwatch lint --check`) |

### All 56 providers

Each lives in its own subpackage under `internal/alert/` and sends through the
shared `alert/util.Send` helper — the linter forbids raw `net/http` in
providers, so status handling stays uniform.

`slack`, `discord`, `teams`, `telegram`, `email`, `pagerduty`, `opsgenie`,
`matrix`, `dingtalk`, `feishu`, `googlechat`, `rocketchat`, `mattermost`,
`zenduty`, `webhook`, `gotify`, `ntfy`, `pushover`, `webex`, `github`,
`gitlab`, `gitea`, `zapier`, `n8n`, `ifttt`, `teamsworkflow`, `zulip`,
`homeassistant`, `splunk`, `datadog`, `newrelic`, `clickup`, `ilert`,
`incidentio`, `squadcast`, `signl4`, `twilio`, `vonage`, `plivo`,
`messagebird`, `signal`, `sendgrid`, `ses`, `sns`, `jira`, `wecom`,
`splunkoncall`, `mailgun`, `resend`, `goalert`, `alerta`, `threema`, `flock`,
`pushbullet`, `sensugo`, `line`.

### Routing

Each provider can have `routes` filtering on `namespaces`, `severities`, and
`reasons` (config `AlertRoute`). If no route matches, that provider is skipped
for the incident — evaluated before message building so filtered incidents
never pay for rendering.

### Retry classification

The single shared classification (in `alert/util/http.go` and
`internal/event`):

- **2xx** → success.
- **429** → a `ratelimit.Error`; the retry loop honours `Retry-After` from the
  header (or from the response body, for APIs like Telegram that put it
  there).
- **Other 4xx** → a `PermanentError`: a bad payload will not get better on
  retry, so it dead-letters immediately instead of delaying the alerts queued
  behind it.
- **5xx / transport errors** → retried with backoff.

### Dead-letter queue and saturation

`dlqRing` is a ring buffer of the last 100 failed deliveries, readable over
the health endpoint `/deadletters` (requires `healthCheck.diagnostics: true`).
When a provider's channel is saturated during a storm, kwatch drops the
*arriving* job — keeping the earlier, root-cause notifications that are
already queued — and records it as a dead-letter with
`notifications_dropped`.

---

## 11. `internal/insight/` — Cause/Impact/What-Changed

**Path:** `internal/insight/`

### Role

kwatch has no external analysis dependency — no sidecar, no LLM. The
"detective" work is done in-process by the insight engine over the dependency
graph built by the controller. For each announced incident it answers three
questions and the answers travel with the notification as the 🧠 Diagnosis
block:

```go
type Insight struct {
    Cause         string            // likely cause
    Impact        string            // blast radius
    Pattern       string            // recognised failure pattern
    AffectedCount int
    RecentChanges []context.Change // what changed just before
}

func (e *Engine) Analyze(inc *model.Incident) *Insight
```

- **`cause.go`** — walks the incident's tree first: is the node unhealthy, is
  the owning workload failing, did a referenced ConfigMap/Secret/PVC change?
  If nothing obvious, walk the dependency chain *backward* to the deepest root
  (node, PV, storage class, ConfigMap, Secret, service account) and blame
  that.
- **`impact.go`** — walks *downstream* and counts what else would break:
  pods on the node, services and ingresses pointing at the failing workload,
  pods referencing the same PVC.
- **`changes.go`** — checks the `context.ChangeTracker` for updates to the
  same resource in the recent window ("Deployment updated 3m before this
  incident — likely a rollout").
- **`patterns.go`** — recognises repeated failure signatures (repeating OOM /
  memory leak, probe failures, image-pull scopes) and implements mass-failure
  detection: `ScanMassFailures` fires a shared-dependency alert when 30%+ of
  its dependents (min 3) are failing, with the threshold recomputed from the
  live graph.

The diagnosis is requested for CREATE/UPDATE paths only — a resolve carries
nothing left to explain, and a mass failure *is* the diagnosis.