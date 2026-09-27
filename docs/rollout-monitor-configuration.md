---
sidebar_position: 10
title: Stuck Deployment rollout alerts
description: Detect Kubernetes Deployments whose rollout has exceeded its progress deadline, then inspect the failing Pods and rollout conditions with kwatch.
keywords: [kwatch, Kubernetes Deployment monitoring, stuck rollout, ProgressDeadlineExceeded]
---

# Stuck Deployment rollout alerts

A Deployment rollout replaces old Pods with new ones. If the new Pods cannot
become available, Kubernetes may report `ProgressDeadlineExceeded`. kwatch
watches that signal so the team can investigate the stalled rollout.

## What kwatch detects

The rollout monitor is enabled by default. It reports a Deployment that has
exceeded its progress deadline. The alert points to the affected workload;
the exact cause still depends on the new Pods and their Events.

| Setting | Default | Purpose |
| --- | --- | --- |
| `rolloutMonitor.enabled` | `true` | Watch for stuck Deployment rollouts. |

## Investigate a stuck rollout

Start with the Deployment and its rollout status:

```bash
kubectl rollout status deployment/<name> -n <namespace>
kubectl describe deployment <name> -n <namespace>
kubectl get pods -n <namespace>
```

Check the Deployment conditions and the new Pods. Image pull failures,
scheduling problems, container crashes, and readiness failures lead to
different fixes. Inspect a failing Pod with `kubectl describe pod` and its
recent logs before changing the rollout.

## Configure or disable the monitor

Use the interactive [kwatch manager](/docs/installation) to change monitor
settings. This is the equivalent configuration fragment:

```yaml
rolloutMonitor:
  enabled: true
```

After changing settings, run `kwatch lint` and let the manager verify the
workload. See the [Kubernetes coverage guide](/docs/kubernetes-coverage)
for related workload signals.
