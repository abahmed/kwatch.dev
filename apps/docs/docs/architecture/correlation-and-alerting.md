---
sidebar_position: 3
title: Incident lifecycle & delivery
description: How kwatch settles findings into incidents, explains them by root cause, and delivers one message per cause with at-least-once delivery.
keywords: [kwatch, kubernetes, architecture, incident, delivery, root cause, incident lifecycle, dedup]
pagination_prev: architecture/packages-overview
pagination_next: architecture/infrastructure-packages
---

# 🧠 Incident lifecycle and delivery

## The incident states

```text
 Settling -> Open -> Recovering -> Resolved
                \        |            |
                 \--> Flapping        +-- reopens (same incident) within
                                           the repage window
```

The incident manager is ticked by the pipeline loop. Each tick it moves every
live incident one step and returns the decisions that deserve a message:
`Announce`, `Update` or `Resolve`. The pipeline gathers the facts for the
decision and `notification/compose` writes the text from the decision alone.

- **Settling.** Findings join an incident for a short window so late failures
  are folded in (15 seconds for page-tier incidents, 75 for lower tiers).
- **Announce, update, resolve.** An incident is updated only when something new
  is true, and resolved once, after its pods stay healthy for a hold time
  (three minutes), so flapping does not produce resolve and re-open noise.
- **Noise control.** Basic dedup, settling, merging of symptoms under one root
  cause, and the low-priority digest (one message every 30 minutes) are in
  every edition. Flapping and routine-recurrence recognition, the startup
  summary and downtime changes are <span className="kw-pro">Pro</span>.
- **Reminders.** An incident that stays open gets one "still open" update per
  week; acknowledged incidents stop reminding.

Severity decides how loudly an incident is delivered. Without an override,
kwatch derives the tier itself; overriding it by reason or owner kind
(`severityByReason`, `severityByOwnerKind`) is <span className="kw-pro">Pro</span>. See
[General configuration](/general-configuration#-severity).

## Where root cause comes from

How failure spreads is data, not code. `internal/rootcause/explain/table*.go`
holds the propagation table. Each row says that a cause in some modes, through
one link, explains effects in some modes, with a prior belief:

```text
node-not-ready      node: NotReady  runs-on  pod: NotReady, Evicted ...  0.8
rollout             changed spec    owns     pod: CrashLoop, NotReady    0.7
certificate-expired secret: Cert.Expired uses pod that shows TLS errors  0.8
```

Scorers then add or subtract evidence: temporal order, coverage, healthy
siblings elsewhere, an error that names the candidate, recent change, shared
node or zone, baseline deviation. Every weight is in `weights.go` with the
reason for its value. Each contribution carries a code and its numbers
(`rootcause.ProofCode`), and the incident keeps the cause as a
`rootcause.CauseRecord` with its row and mode: messages are written from
those fields, never from the solver's trace text. Below the confidence floor the cause is stated as
unknown. The solver is a pure function of a snapshot: no clock, no I/O.

When nothing upstream shows a fault, the engine still has four things to
say, in this order of strength:

1. **A probed dependency.** Pods relate to the endpoints outside the cluster
   that their environment names (`postgres://db.example.com:5432/...` becomes
   the `external-endpoint` `db.example.com:5432`; only host and port are
   kept). With `autoDependencies` on, kwatch dials them, and a dependency
   that refuses connections is the cause of the pods that call it.
2. **The same error.** Three or more workloads that began failing within
   thirty minutes with the same normalised error line (times, IDs, addresses
   and numbers replaced; see `docs/incident-lifecycle/examples.md`) share a
   virtual `failure-signature` cause (`shared-failure-signature` row, prior
   0.55). It is the weakest named row, so a probed dependency or any better
   cause wins, and one message says the shared error is the cause.
3. **What the failures share.** Three or more workloads failing within ten
   minutes on one healthy node, where most pods on that node fail, make the
   node a suspect (`shared-node` row, pseudo mode `SharedFactor`). It is
   capped below "likely": nothing is known to be wrong with it. An
   unchanged shared image, ConfigMap, Secret or ServiceAccount is weak
   evidence and is not suspected.
4. **What was checked.** The solver records the upstream objects it reached
   that showed nothing wrong (`Trace.Checked`), and the message says "Its
   node, image and configuration are healthy and unchanged, so nothing
   outside it explains this", followed by the quoted crash output.

Two kinds of finding are not failures. A *symptom* (a Deployment below its
replicas) restates its pods' failures and never leads a message. An
*advisory* finding (`Finding.Advisory`: no readiness probe, no memory
limit, a `latest` tag, a single replica) is configuration advice: it never
opens an incident, is never announced on its own, joins the incident of a real failure of the same
workload, and adds one sentence when the failure shows what the risk cost.

A failure can also travel. Once a cause is chosen, `explain/chain.go`
extends it down the failure chain: postgres OOM-killed, then the API that
calls it not ready, then the Service in front of the API with no endpoints.
A step joins two failing workloads or Services and needs evidence: a pod that
is not ready (or whose error names the Service) and calls a Service with no
ready endpoint, the failing pods behind a Service with no ready endpoint, or a
route that sends traffic to such a Service. The effect must begin after its
cause (strictly for a call), within the causal window, and a healthy step ends
the chain, as does a workload with a change or a failure of its own. A chain
runs at most `ChainMaxHops` (3) steps from what the cause explains directly
and trusts each step `ChainDecay` (0.9) times the one before. It adds derived
coverage (like the summary of a pod), so the failures of every step are one
incident rooted at the first one. The chain is `Cause.Hops` (and
`Trace.Chain`), and the message ends with "Chain: postgres (10:00) → api
(10:01) → service api (10:01)."

A cause can also arrive too late. Once an incident has been announced, a
cause that began more than ten minutes afterwards (`Cause.Began`) does not
take it over: people were told about something that cause cannot have
caused, so the incident keeps its root and the new cause explains only the
new failures.

The root-cause headline is part of the Community edition. Full proof, shared-factor
suspects, who changed what, impact and log excerpts are <span className="kw-pro">Pro</span>.

## Delivery

The delivery manager queues each message per provider, retries only failures
that can succeed (timeouts, 5xx, rate limits), honours `Retry-After`, paces
sends against an hourly budget per provider, and uses a fallback provider when
configured. A provider that panics counts as a failed attempt rather than
taking kwatch down.

- **One provider on Community.** Community sends to one provider, chosen with
  `app.communityProvider`; Pro sends to all configured providers and adds
  routing by namespace, severity, reason and owner, threads that update one
  message per incident where the provider supports it, and text templates.
- **At least once.** A queued delivery is written to a persisted outbox
  and removed when the provider (or its fallback) accepted it or it was
  dead-lettered. After a restart the next session re-queues what is left. A
  send interrupted mid-request may repeat. If the state lock is lost, nothing
  more is sent.
- **Pages are never folded** into the overflow digest, and resolves and pages
  go ahead of routine messages in a provider's queue.

See the [provider reference](/channels/providers) and
[General configuration](/general-configuration#-delivery-behaviour).
