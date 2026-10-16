---
sidebar_position: 11
title: DaemonSet availability alerts
description: Monitor unavailable Kubernetes DaemonSet Pods with kwatch, understand the sustained detection window, and investigate node or scheduling failures.
keywords: [kwatch, Kubernetes DaemonSet monitoring, unavailable Pods, node alerts]
---

# DaemonSet availability alerts

:::info Pro
This feature is part of kwatch Pro, which is free during early access. See [Community vs Pro](/docs/editions).
:::

A DaemonSet runs a Pod on each matching node. When a Pod is unavailable, a
node, scheduling, image, or application problem may be preventing the
DaemonSet from doing its job. kwatch alerts after the condition has lasted
long enough to avoid brief rollout noise.

## What kwatch detects

kwatch reports a DaemonSet Pod that stays unavailable. There is no on/off switch for this detector: kwatch always watches every supported resource. To silence a known, intentional case use `silences` or a maintenance annotation (see [General configuration](/docs/general-configuration)).

The sustained window avoids notifications for short rolling updates or
temporary node changes.

## Investigate the missing Pod

```bash
kubectl describe daemonset <name> -n <namespace>
kubectl get pods -n <namespace> -o wide
kubectl get nodes
```

Compare desired and available Pods, then inspect the affected node and Pod
Events. If a node is NotReady, investigate the node first. If only one
DaemonSet Pod fails, check its image, scheduling constraints, and logs.

## Related

See [node and workload coverage](/docs/kubernetes-coverage) for related signals.
