---
sidebar_position: 11
title: DaemonSet Monitor
description: DaemonSet monitor configuration for unavailable pods
keywords: [kwatch, kubernetes, configuration, monitor, daemonset]
pagination_next: null
pagination_prev: null
---

# 📡 DaemonSet Monitor

Watches for DaemonSets that have unavailable pods.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `daemonSetMonitor.enabled` | `bool` | `true` | Watch for unavailable DaemonSet pods. |
| `daemonSetMonitor.sustainedMinutes` | `int` | `5` | Debounce before alerting (avoids noise from rolling updates and brief node blips). |

### Example

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kwatch
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kwatch
  namespace: kwatch
data:
  config.yaml: |
    daemonSetMonitor:
      enabled: true
      sustainedMinutes: 5
```
