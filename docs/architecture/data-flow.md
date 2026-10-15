---
sidebar_position: 5
title: Data Flow
description: End-to-end trace of a bad rollout through kwatch - from the changed Deployment and crashing pod to the single message that names the cause.
keywords: [kwatch, kubernetes, architecture, data flow, pod crash, root cause, incident, delivery]
pagination_prev: architecture/infrastructure-packages
pagination_next: architecture/design-decisions
---

# 🔀 Data flow

This page follows one failure through the pipeline described in the
[overview](/docs/architecture/overview). Some steps use Pro capabilities
(who changed what, log excerpts, impact); the Community edition sends the
root-cause headline without them.

## One incident, from crash to message

A bad release of `api` in namespace `shop` makes its pods crash. This is
the `bad-rollout` scenario in `internal/scenarios`.

1. **A change is recorded.** Someone sets a new image on the Deployment. The
   Deployment schema in `inventory/kube` diffs the two versions, sees that
   `spec.template` changed, and the model keeps a `Change` with the actor and
   revision. A status-only update would record nothing.
2. **The pod crashes.** The pod informer delivers the new pod. `PodSchema`
   turns it into an observation with the container's restart count and waiting
   reason. The source calls `Engine.Submit`.
3. **The loop applies it.** `Engine.drain` folds the observation into the
   `Model` and returns the touched objects.
4. **A detector sets health.** `detection.Registry.Evaluate` runs the
   detectors for the container. `detectors.Container` returns a finding with
   reason `CrashLoopBackOff`, severity critical and evidence (the last
   error). `Classify` fills in health `failing` and mode `CrashLoop`. The `Tracker` compares it with the last result and
   reports a raised transition.
5. **Root cause is solved once.** `explain.Explain` groups the failing objects
   into connected areas. For each area it walks links upstream from every
   failure (container, pod, ReplicaSet, Deployment, node), keeps only
   candidates that are unhealthy or changed inside the causal window, and
   scores them. The Deployment changed just before the first crash, only
   new-revision pods fail, and old pods on the same node are fine. The
   `rollout` row of the propagation table matches, evidence adds up, and set
   cover picks the Deployment as the one cause. The node is not blamed.
6. **The incident manager decides.** `incident.Manager.Apply` attaches the
   findings to an incident rooted at the Deployment. Its tier is page. The
   incident settles for 15 seconds (75 for lower tiers, and for a burst of
   three or more incidents settling at once) so late failures join
   it, then `Tick` returns an announce decision.
7. **Investigation joins in.** When the incident opened, a worker read a short
   log excerpt, redacted. If it arrives within a short wait it is attached;
   otherwise the message goes without it.
8. **The note is written.** `compose.Writer` turns the facts into sentences:
   what broke and why, who changed what, the one or two facts that prove it,
   who is affected, and one `kubectl` suggestion. A read-only suggestion
   stands as it is; one that changes the cluster, such as a rollback, is
   marked "(changes the cluster)". The result is one
   `notification.Message`.
9. **Delivery sends it.** The sink in `internal/app` records an audit entry
   and calls `NotifyIncident`. The delivery manager queues the message per
   provider, retries and paces it, and the provider adapter renders it.

When the Deployment's pods stay healthy for the hold time (three minutes), the
manager resolves the incident and the writer says who fixed it, for example
that someone rolled back.

```text
🟠 api in shop (prod-eu-1): rollout 14 restarted 4 times in its first 2
minutes; rollout 13 did not restart. The previous image was
registry.example.com/api:2.2. Its dependents failed soon after it
changed. Rolling back fixes it (changes the cluster): kubectl rollout
undo deployment/api -n shop --to-revision=13
```

For the stages after the decision, see
[Incident lifecycle and delivery](/docs/architecture/correlation-and-alerting).
