---
sidebar_position: 13
title: Missed CronJob schedule alerts
description: Detect suspended Kubernetes CronJobs and CronJobs with missed schedules, then inspect schedule and Job history with kwatch.
keywords: [kwatch, Kubernetes CronJob monitoring, missed schedule, suspended CronJob]
---

# Missed CronJob schedule alerts

:::info Pro
This feature is part of kwatch Pro, which is free during early access. See [Community vs Pro](/editions).
:::

A CronJob creates Jobs on a schedule. kwatch watches for suspended CronJobs
and CronJobs that have not scheduled a run as expected. This helps teams find
paused or missed recurring work.

## What kwatch detects

kwatch reports suspended CronJobs and missed or repeatedly failing schedules. There is no on/off switch for this detector: kwatch always watches every supported resource. To silence a known, intentional case use `silences` or a maintenance annotation (see [General configuration](/general-configuration)).

A CronJob that intentionally runs less often than daily may need a different
operational check. Review its schedule before treating a gap between runs as a
failure.

## Investigate a missed run

```bash
kubectl get cronjob <name> -n <namespace>
kubectl describe cronjob <name> -n <namespace>
kubectl get jobs -n <namespace>
```

Check the schedule, suspension flag, last scheduled time, and recent Jobs.
If a Job was created but failed, follow the [Job monitor guide](/job-monitor-configuration)
and inspect the Job's Pods.

## Related

- [Kubernetes failure coverage](/kubernetes-coverage): every detector and its edition
- [General configuration](/general-configuration) and the [generated configuration reference](/reference/generated/configuration)
- [Community vs Pro](/editions)
- [Troubleshoot missing or delayed alerts](/operations/troubleshooting)
