---
sidebar_position: 14
title: HPA Monitor
description: configure kwatch to detect Kubernetes HPAs stuck at maximum replicas or unable to scale
keywords: [kwatch, kubernetes, configuration, monitor, hpa, autoscaling, horizontalpodautoscaler]
pagination_next: null
pagination_prev: null
---

# 📈 HPA monitor

An **HPA** (Horizontal Pod Autoscaler) changes the number of Pods when load
changes. This monitor alerts only when scaling is failing and the HPA stays at
its maximum for a sustained period.

Watches for HorizontalPodAutoscalers that are stuck at max replicas for a
sustained period with scaling errors.

## How detection works

1. kwatch lists all HPAs in watched namespaces
2. Checks if `status.currentReplicas ≥ spec.maxReplicas` (at max capacity)
3. Checks if scaling is blocked or failing (e.g. resource metrics unavailable)
4. Only alerts if the condition persists beyond `sustainedMinutes`
5. Resolves when the HPA scales down or scaling errors clear

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `hpaMonitor.enabled` | `bool` | `true` | Enable HPA monitoring. |
| `hpaMonitor.sustainedMinutes` | `int` | `20` | Minutes the HPA must be at max replicas before alerting. |

## Configuration fragment

Add this fragment through `kwatch.sh`'s **Configure settings** flow, or merge it
into the configuration file used by your existing supported installation:

```yaml
hpaMonitor:
  enabled: true
  sustainedMinutes: 20
```

## What triggers an alert

- HPA at `maxReplicas` with scaling failures (resource metrics unavailable,
  timeout, etc.)
- Sustained for `sustainedMinutes` (default 20 min) — avoids noise from
  temporary spikes

## What does NOT trigger an alert

- HPA at `maxReplicas` with no scaling errors (normal — you've reached your
  max, that's expected)
- HPA scaling up successfully (kwatch only alerts on failures)
