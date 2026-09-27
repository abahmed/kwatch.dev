---
sidebar_position: 11
title: DaemonSet availability alerts
description: Monitor unavailable Kubernetes DaemonSet Pods with kwatch, understand the sustained detection window, and investigate node or scheduling failures.
keywords: [kwatch, Kubernetes DaemonSet monitoring, unavailable Pods, node alerts]
---

# DaemonSet availability alerts

A DaemonSet runs a Pod on each matching node. When a Pod is unavailable, a
node, scheduling, image, or application problem may be preventing the
DaemonSet from doing its job. kwatch alerts after the condition has lasted
long enough to avoid brief rollout noise.

## What kwatch detects

| Setting | Default | Purpose |
| --- | --- | --- |
| `daemonSetMonitor.enabled` | `true` | Watch unavailable DaemonSet Pods. |
| `daemonSetMonitor.sustainedMinutes` | `5` | Wait before alerting on an unavailable Pod. |

The sustained window helps avoid notifications for short rolling updates or
temporary node changes. Increasing it delays real alerts too.

## Investigate the missing Pod

```bash
kubectl describe daemonset <name> -n <namespace>
kubectl get pods -n <namespace> -o wide
kubectl get nodes
```

Compare desired and available Pods, then inspect the affected node and Pod
Events. If a node is NotReady, investigate the node first. If only one
DaemonSet Pod fails, check its image, scheduling constraints, and logs.

## Configure the monitor

Use the [interactive manager](/docs/installation) to change settings. The
equivalent configuration fragment is:

```yaml
daemonSetMonitor:
  enabled: true
  sustainedMinutes: 5
```

Run `kwatch lint` after a change. See [node and workload coverage](/docs/kubernetes-coverage)
for related signals.
