---
sidebar_position: 5
title: Data Flow
description: End-to-end trace of a pod crash through kwatch — from informer detection to Slack notification, with code references
keywords: [kwatch, kubernetes, architecture, data flow, pod crash, alert pipeline, filter pipeline, correlation, insight]
pagination_prev: architecture/infrastructure-packages
pagination_next: architecture/design-decisions
---

# Data Flow — A Pod Crashes

This page traces a single pod crash through every stage of kwatch, from
Kubernetes API watch to a chat message. Each step references the real
package and function involved.

---

## Phase 1: Detection (Informer → Workqueue)

```
Pod transitions to CrashLoopBackOff
       │
       ▼
Pod informer (SharedInformer) receives ADD/UPDATE event
       │
       ▼
Event handler registered by controller.New() fires
       │
       ▼
enqueue.go: changeRecordingHandler / graph-aware pod handler update
the change tracker + dependency graph, then enqueue namespace/key
       │
       ▼
The pod's resourcePipeline workqueue receives "namespace/name"
```

The controller builds one `resourcePipeline` per watched kind
(`internal/controller/pipeline.go`): a named rate-limited workqueue, informer
sync state, a sync function, and a `startWorkers` gate. Each queue is
independent — a slow deployment reconcile can't block a pod crash. Sync
dispatch functions (`sync.go`) share one signature
`func (c *Controller) syncX(_ context.Context, key string) error`.

Handlers also feed the two side structures the diagnostic engine needs:

- `recordChange` → `context.ChangeTracker`, so "what changed recently" has data;
- the graph-aware pod handler → `context.ResourceGraph`, so cause/impact
  analysis can walk the cluster's family tree.

---

## Phase 2: Filter Pipeline (Handler → Filter)

```
Worker goroutine picks up key from the pod queue
       │
       ▼
handler.ProcessPod() is called with the object
       │
       ▼
Builds filter.Context:
  • Sources   — client, config, listers, injected Now clock (read-only)
  • Pod/EvType/Owner/Events — the object under evaluation
  • Findings  — scratch area for detector conclusions
       │
       ▼
Detector chain (any returns StatusSkip → pod dropped)
       │
       ▼ (StatusContinue / StatusAlert)
Per-container evaluation (remaining detectors)
       │
       ▼
Enricher chain (fetch events, resolve owner, collect logs, check killing)
       │
       ▼
handler builds an event.Signal and calls correlation.Engine.Process()
```

The handler is the only place pod evaluation happens. Detectors write
`Findings` (`PodHasIssues`, `ContainerHasIssues`, `PodReason`, and so on);
enrichers fill in the incident's evidence and hint. Time-based decisions read
the injected `Sources.Now` clock rather than the wall clock.

Key filters for a CrashLoopBackOff → OOM story:

- `pod_status_filter.go` — pod-level issues first;
- `container_state_filter.go`, `container_reasons_filter.go` — the container
  is `terminated` with reason `OOMKilled`;
- `container_restarts_filter.go` — the container is restarting (restart
  count increased since `LastState`);
- `noise_filter.go` — skips banal reasons (`Normal`, `Scheduled`,
  `Pulled`, `Pulling`); `OOMKilled` is not among them, so it passes;
- `container_killing_filter.go`, `container_logs_filter.go`,
  `pod_events_filter.go`, `pod_owners_filter.go` — enrichment.

---

## Phase 3: Correlation Engine (State & Dedup)

```
correlation.Engine.Process(ev, owner, containerState)
       │
       ▼
processLocked — every path through the same five stages:
       1) baseline      was it already broken at startup?      → quiet
       2) attribution   symptom of node / shared-dep / owner?  → counted, silent
       3) cooldown      resolved a moment ago?                 → silent revival
       4) identity      which incident is this?                → dedup / fold / escalate
       5) announcement  speak now?                             → group or edge
       │
       ▼
emit() → LifecycleHook(inc, action)
       │
       ▼
app.lifecycleHook: audit once → insight diagnosis → AlertManager.NotifyIncident()
```

### Dedup key

Incidents are keyed by `namespace:owner:reason:container`
(`key.go` `BuildKey`). Crash-looping reasons fold into one canonical key once
restarts pass the threshold, so the incident's identity is stable across the
container's momentary states. Image-pull failures with global scope (rate
limits, registry timeouts, DNS, TLS) use a cluster-wide key.

### Edge-triggered notification

```go
// internal/correlation/engine.go
func notifSig(inc *model.Incident) string {
    st := "firing"
    if inc.State == model.StateResolved {
        st = "resolved"
    }
    return st + "|" + string(inc.Severity)
}
```

The signature `"firing|critical"` is compared against the incident's
`NotifiedSig`. If unchanged, the action is `ActionSkip` — no duplicate alert
on every poll. First sighting gives `ActionCreate`; later changes give
`ActionUpdate`; the transition to resolved gives `ActionResolved`.

### Severity resolution

The `DefaultEnricher` (wired in `internal/app` from `severityByReason` /
`severityByOwnerKind`) resolves severity in order:

1. **By reason** — from `severityByReason` (defaults: `Evicted`,
   `ImagePullBackOff` → `medium`);
2. **By owner kind** — from `severityByOwnerKind` (default:
   `StatefulSet` → `high`);
3. **Default** — `normal`.

Severity is monotonic: once raised (including by escalation tiers), it never
downgrades until the incident resolves.

### Escalation check

```go
// Default tiers: [3, 10]. Crossing the first raises severity to "high",
// crossing the second to "critical".
if cur >= e.config.EscalationTiers[i] {
    ev.Severity = severityForTier(i, inc.Severity)
}
```

7 restarts cross tier 0 (≥3), so severity escalates to `high`.

### Node inhibition

When `inhibition.nodeSuppressesPods` is enabled and the pod's node has an
active node-level incident, the pod is attributed to the node's alert — it is
counted and listed, but not announced itself.

### Smart grouping

If the event should speak but arrives inside the grouping window, it is
buffered (`grouping.go`, `group_flush.go`). The window closes → one `ActionUpdate`
notification summarizing the whole group on a stable group key, throttled by a
`4×`-window cooldown. If the OOM story was one pod, it is announced at the edge
immediately.

---

## Phase 4: Insight (Cause / Impact / What-Changed)

The old "AI analysis" step never existed. In-process analysis replaces it:

```
LifecycleHook fires (action != skip)
       │
       ▼
app.lifecycleHook: opts.diagnose(inc, action)
       │   (no diagnosis for resolves or mass failures)
       ▼
insight.Engine.Analyze(inc) — walks the dependency graph
       │
       ├── cause.go     "node worker-2 may be unhealthy"
       │                 "owning Deployment orders-api is unhealthy"
       │                 "referenced ConfigMap may have changed"
       │                (else: walk backward to the deepest root)
       ├── impact.go    "5 pods, affecting 2 services"  (walk downstream)
       ├── changes.go   "Deployment dev/api updated 3m ago" (ChangeTracker)
       └── patterns.go  recognised signatures (repeating OOM, probes, image pulls)
       │
       ▼
Result travels with the notification as the 🧠 Diagnosis block
```

There is no external model, no sidecar container, and no enrichment channel —
kwatch analyzes the incident with the graph it already maintains. If
diagnoses come back empty on a large cluster, check `kwatch_graph_nodes` and
`kwatch_graph_edges` on `/metrics`: an empty graph explains nothing.

---

## Phase 5: Alert Dispatch (NotifyIncident → Provider)

```
AlertManager.NotifyIncident(inc, action, insight)
       │
       ▼
Silence check ──── match? → DROP (silence.go, compiled silence index)
       │ no match
       ▼
fanOut: clone incident → one deliverJob per configured provider channel
       │ non-blocking
       ▼
Channel saturated? ──→ drop the arriving job, record dead-letter
       │ delivered (channel cap 256)
       ▼
Provider worker: deliverOne (delivery.go)
       ├── routes match? (routing.go) ── no match → Skip provider
       ├── buildMessage → ReportBuilder + provider renderer
       ├── truncate to provider byte limit
       ├── Send with retry classification (alert/util.Send):
       │     • 2xx        → success
       │     • 429        → ratelimit.Error; honour Retry-After (header or body)
       │     • other 4xx  → PermanentError → dead-letter immediately
       │     • 5xx / transport → retried with backoff
       └── all attempts failed?
           ├── fallback configured? → try the fallback provider
           └── else → dead-letter queue (ring buffer of 100, /deadletters)
```

Only retryable failures are retried. A malformed 4xx payload dead-letters
immediately instead of delaying the alerts queued behind it. Provider
delivery is through the shared `alert/util.Send` helper; the linter forbids
raw `net/http` inside providers.

### What the message looks like

Every notification is built from one provider-agnostic `Report` and rendered
top-down:

```
🟠 Pod not ready — dev/api · Deployment · ContainersNotReady · high
pod stopped being ready 2m ago

🧠 Diagnosis
• Why: node ip-10-0-81-7 may be unhealthy (node_failure)
• Impact: affects service api
• Changed recently: deployment dev/api updated 3m ago

💡 check readiness probe and recent logs
  pod api-584ddc9849-gjwjp · image api:1.2.0 · node ip-10-0-81-7 · 2m · dev

🔍 Events — from api-584ddc9849-gjwjp
  Aug 25 23:52:21  FailedScheduling  0/5 nodes are available …
```

Report sections (`internal/message/report.go`) are populated selectively:
headline, current state, diagnosis (hint + cause + impact + pattern), evidence
(logs/events), recent changes, and type-specific sections (OOM timeline,
probe endpoint, image-pull, scheduling delay). Renderers
(`slack_renderer.go`, `discord_renderer.go`, `plaintext_renderer.go`,
`text_renderer.go`) drop what they don't understand.

---

## Phase 6: Delivery & User Notification

```
Provider accepts the payload (HTTP 2xx)
       │
       ▼
Retry loop exits, breaker state resets
       │
       ▼
User sees the notification in #kwatch-alerts
```

The entire flow — from pod crash to chat message — completes in well under a
second in normal operation. There is no AI stage and no sidecar round-trip:
the diagnostic block is computed locally from the in-memory dependency graph.

---

## Summary: End-to-End in 8 Steps

| # | Phase | Package |
|---|-------|---------|
| 1 | Informer detects pod change, enqueues key | `internal/controller` |
| 2 | Filter pipeline evaluates the pod | `internal/handler` + `internal/filter` |
| 3 | Correlation engine dedups and decides (five stages) | `internal/correlation` |
| 4 | Severity resolved, escalation applied | `internal/correlation` + `internal/enricher` |
| 5 | Insight diagnoses cause / impact / what-changed | `internal/insight` |
| 6 | Alert manager formats the report | `internal/alert` + `internal/message` |
| 7 | Provider retry / dispatch | `internal/alert/*` (via `alert/util.Send`) |
| 8 | User receives notification | the configured provider |