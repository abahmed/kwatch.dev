---
sidebar_position: 12
title: Failed Kubernetes Job alerts
description: Detect failed or suspended Kubernetes Jobs with kwatch and follow a short triage path through Job conditions, Pods, Events, and logs.
keywords: [kwatch, Kubernetes Job monitoring, failed Job alerts, suspended Job]
---

# Failed Kubernetes Job alerts

:::info Pro
This feature is part of kwatch Pro, which is free during early access. See [Community vs Pro](/editions).
:::

A Job runs work until it succeeds or reaches its failure condition. kwatch
watches Jobs that fail or become suspended, helping the team distinguish a
workload error from an intentional pause.

## What kwatch detects

kwatch reports Jobs that fail or become suspended. There is no on/off switch for this detector: kwatch always watches every supported resource. To silence a known, intentional case use `silences` or a maintenance annotation (see [General configuration](/general-configuration)).

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

## Related

For recurring work, see the [CronJob monitor](/cronjob-monitor-configuration).
