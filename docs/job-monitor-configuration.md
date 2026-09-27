---
sidebar_position: 12
title: Failed Kubernetes Job alerts
description: Detect failed or suspended Kubernetes Jobs with kwatch and follow a short triage path through Job conditions, Pods, Events, and logs.
keywords: [kwatch, Kubernetes Job monitoring, failed Job alerts, suspended Job]
---

# Failed Kubernetes Job alerts

A Job runs work until it succeeds or reaches its failure condition. kwatch
watches Jobs that fail or become suspended, helping the team distinguish a
workload error from an intentional pause.

## What kwatch detects

| Setting | Default | Purpose |
| --- | --- | --- |
| `jobMonitor.enabled` | `true` | Watch failed or suspended Jobs. |

An intentional suspension may not require action. Check who changed the Job
and whether the pause is part of a planned operation before responding.

## Investigate a failed Job

```bash
kubectl describe job <name> -n <namespace>
kubectl get pods -n <namespace>
```

Look at Job conditions and the Pods it created. Inspect the failing Pod's
Events and logs to understand whether the problem is in the task, its image,
configuration, or a cluster dependency. If the Job is suspended, confirm the
expected schedule and owner.

## Configure the monitor

Use the [interactive manager](/docs/installation) to change settings. The
equivalent configuration fragment is:

```yaml
jobMonitor:
  enabled: true
```

Run `kwatch lint` after a change. For recurring work, see the
[CronJob monitor](/docs/cronjob-monitor-configuration).
