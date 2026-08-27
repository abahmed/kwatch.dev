---
sidebar_position: 12
title: Job Monitor
description: Job monitor configuration for failed or suspended jobs
keywords: [kwatch, kubernetes, configuration, monitor, job]
pagination_next: null
pagination_prev: null
---

# 🧑‍💼 Job Monitor

Watches for Jobs that fail or become suspended.

| Parameter | What it does |
|:---|---|
| `jobMonitor.enabled` | ✅ Watch for failed/suspended Jobs (default: true) |

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
    jobMonitor:
      enabled: true
```
