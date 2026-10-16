---
sidebar_position: 10
title: Stuck Deployment rollout alerts
description: Detect Kubernetes Deployments whose rollout has exceeded its progress deadline, then inspect the failing Pods and rollout conditions with kwatch.
keywords: [kwatch, Kubernetes Deployment monitoring, stuck rollout, ProgressDeadlineExceeded]
---

# Stuck Deployment rollout alerts

:::info Pro
This feature is part of kwatch Pro, which is free during early access. See [Community vs Pro](/docs/editions).
:::

A Deployment rollout replaces old Pods with new ones. If the new Pods cannot
become available, Kubernetes may report `ProgressDeadlineExceeded`. kwatch
watches that signal so the team can investigate the stalled rollout.

## What kwatch detects

The rollout detector is part of kwatch Pro. It reports a Deployment that has
exceeded its progress deadline. The alert points to the affected workload;
the exact cause still depends on the new Pods and their Events.

There is no on/off switch for this detector: kwatch always watches every supported resource. To silence a known, intentional case use `silences` or a maintenance annotation (see [General configuration](/docs/general-configuration)).

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

## Related

See the [Kubernetes coverage guide](/docs/kubernetes-coverage) for related workload signals.
