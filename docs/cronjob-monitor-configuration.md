---
sidebar_position: 13
title: Missed CronJob schedule alerts
description: Detect suspended Kubernetes CronJobs and CronJobs without a scheduled run in 24 hours, then inspect schedule and Job history with kwatch.
keywords: [kwatch, Kubernetes CronJob monitoring, missed schedule, suspended CronJob]
---

# Missed CronJob schedule alerts

A CronJob creates Jobs on a schedule. kwatch watches for suspended CronJobs
and CronJobs that have not scheduled a run in 24 hours. This helps teams find
paused or missed recurring work.

## What kwatch detects

| Setting | Default | Purpose |
| --- | --- | --- |
| `cronJobMonitor.enabled` | `true` | Watch suspension and missed schedules. |

A CronJob that intentionally runs less often than daily may need a different
operational check. Review its schedule before treating a 24-hour gap as a
failure.

## Investigate a missed run

```bash
kubectl get cronjob <name> -n <namespace>
kubectl describe cronjob <name> -n <namespace>
kubectl get jobs -n <namespace>
```

Check the schedule, suspension flag, last scheduled time, and recent Jobs.
If a Job was created but failed, follow the [Job monitor guide](/docs/job-monitor-configuration)
and inspect the Job's Pods.

## Configure the monitor

Use the [interactive manager](/docs/installation) to change settings. The
equivalent configuration fragment is:

```yaml
cronJobMonitor:
  enabled: true
```

Run `kwatch lint` after a change.
