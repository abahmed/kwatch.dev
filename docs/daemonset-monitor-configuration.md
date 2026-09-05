---
sidebar_position: 11
title: DaemonSet Monitor
description: configure kwatch to detect unavailable DaemonSet Pods and Kubernetes node or scheduling failures
keywords: [kwatch, kubernetes, configuration, monitor, daemonset]
pagination_next: null
pagination_prev: null
---

# 📡 DaemonSet monitor

A **DaemonSet** keeps one Pod on each matching node. This monitor tells you
when one or more of those Pods cannot run.

Watches for DaemonSets that have unavailable pods.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `daemonSetMonitor.enabled` | `bool` | `true` | Watch for unavailable DaemonSet pods. |
| `daemonSetMonitor.sustainedMinutes` | `int` | `5` | Debounce before alerting (avoids noise from rolling updates and brief node blips). |

### Configuration fragment

Add this fragment through `kwatch.sh`'s **Configure settings** flow, or merge it
into the configuration file used by your existing supported installation:

```yaml
daemonSetMonitor:
  enabled: true
  sustainedMinutes: 5
```
