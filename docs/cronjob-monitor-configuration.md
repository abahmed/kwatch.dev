---
sidebar_position: 13
title: CronJob Monitor
description: CronJob monitor configuration for suspended jobs or missed schedules
keywords: [kwatch, kubernetes, configuration, monitor, cronjob]
pagination_next: null
pagination_prev: null
---

# ⏰ CronJob Monitor

Watches for suspended CronJobs or CronJobs that haven't been scheduled in 24 hours.

| Parameter | What it does |
|:---|---|
| `cronJobMonitor.enabled` | ✅ Watch for suspended CronJobs or missed schedules (default: true) |

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
    cronJobMonitor:
      enabled: true
```
