---
sidebar_position: 10
title: Rollout Monitor
description: rollout monitor configuration for stuck deployments
keywords: [kwatch, kubernetes, configuration, monitor, rollout, deployment]
pagination_next: null
pagination_prev: null
---

# 🚀 Rollout Monitor

Watches for deployments that get stuck during rollout (ProgressDeadlineExceeded).

| Parameter | What it does |
|:---|---|
| `rolloutMonitor.enabled` | ✅ Watch for stuck deployments (default: true) |

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
    rolloutMonitor:
      enabled: true
```
