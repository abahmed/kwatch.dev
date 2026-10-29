---
sidebar_position: 9
title: "What kwatch checks for you: automatic Kubernetes evidence"
sidebar_label: What kwatch checks for you
description: The read-only checks kwatch Pro runs for each incident, how it correlates them, and the settings and API fields that control them.
keywords: [kwatch Pro, auto-evidence, kubectl checks, root cause evidence, investigation.logs, rbac.readyz, rbac.metricsApi]
---

# 🔎 What kwatch checks for you <span className="kw-pro">Pro</span>

:::info Pro
Automatic evidence is part of kwatch Pro, which is free during early access.
Community is unchanged. Install and manage licenses with the
[installer](/installation).
:::

When something breaks, kwatch runs the read-only checks you would run with
`kubectl` yourself and shows the result. Only commands that change the cluster
stay as commands for you to run. A Pro message therefore carries the confirmed
cause, the proof, a log quote and the fix commands. The full picture is in the
Evidence tab of the [dashboard](/dashboard).

kwatch is source available under ELv2. Every check only reads. Secret and
ConfigMap values are never shown, stored or sent; only key names appear.
Credentials are hidden in log lines.

## What kwatch checks, by scenario

| Scenario | Checks |
| --- | --- |
| Crash loop or failing container | Pod state, previous and current logs, events, probes |
| Out of memory | Pod state, previous logs, current usage, node |
| Image will not pull | Image, pull secrets, events |
| Pending pod | Pod state, events, node, PVC, quota |
| Missing Secret or ConfigMap key | Secret and ConfigMap key names (never values), pod state |
| Service or Ingress not answering | Ingress, Service, endpoints, backing pods |
| Admission webhook rejects a change | Webhooks that touch the object, events |
| Bad rollout | Rollout status, the diff against the last healthy revision |
| Expiring or invalid certificate | Certificates |
| Autoscaling or Job stuck | HPA, Job, quota |
| Node or control plane trouble | Node, pods on the node, control plane `/readyz` |

## How kwatch correlates

- **Log signature to cluster object.** A line such as a refused connection is
  matched to the Service, Secret or volume it points at.
- **Nearest prior change.** The closest earlier change to that object.
- **Spread.** How many pods and nodes show the same failure.
- **Rollout diff.** What differs from the last healthy revision.

When the evidence proves the cause, the message says it is confirmed and why.

## Settings

| Setting | Default | What it does |
| --- | --- | --- |
| `investigation.logs` (Helm `config.investigation.logs`) | `true` | Reads container logs for evidence. Set `false` to read none; the dashboard shows the Logs section as turned off. |
| `rbac.readyz` (Helm) | `true` | Grants `get` on the API server's `/readyz`, for the control plane check. |
| `rbac.metricsApi` (Helm) | `true` | Grants `get` on pods in the metrics API, for current usage. When off, usage falls back to kubelet stats. |

```yaml
# Helm values
rbac:
  readyz: true
  metricsApi: true
config:
  investigation:
    logs: true
```

The Secret and certificate checks use `watch.secrets: true`, which is the
default.

When a read is not allowed, the dashboard says which value to set and shows
every other check.

## Dashboard API <span className="kw-pro">Pro</span>

`GET /api/incidents/{id}` (see [Dashboard API](/dashboard-api)) adds:

| Field | Contents |
| --- | --- |
| `evidence` | One section per check: `check`, `title`, `status` (`ok`, `denied`, `timeout`, `absent`), optional `reason` (`rbac`, `off`), `subject`, `run` (`previous` or `current` for logs), `facts`, `lines` and `matched` (indexes of the lines carrying the failure's signature) |
| `correlation` | `confirmed` (why the cause is proven, when it is) and `facts` labelled `Signature`, `Matches`, `Change`, `Spread` and `Before and after` |

Both fields are absent in Community.

## Audit log <span className="kw-pro">Pro</span>

Each audit entry adds `evidence`, a list of `check:status` strings for the
checks that ran, and `readSteps`, the number of read-only commands kwatch ran
for you instead of listing them.
