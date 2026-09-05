---
sidebar_position: 13
title: CronJob Monitor
description: configure kwatch to detect suspended CronJobs, missed schedules, and delayed Kubernetes batch work
keywords: [kwatch, kubernetes, configuration, monitor, cronjob]
pagination_next: null
pagination_prev: null
---

# ⏰ CronJob monitor

Use this monitor when scheduled work must run on time. A **CronJob** creates
Jobs on a schedule; kwatch alerts when it is suspended or has not scheduled a
run for 24 hours.

Watches for suspended CronJobs or CronJobs that haven't been scheduled in 24 hours.

| Parameter | What it does |
|:---|---|
| `cronJobMonitor.enabled` | ✅ Watch for suspended CronJobs or missed schedules (default: true) |

### Configuration fragment

Add this fragment through `kwatch.sh`'s **Configure settings** flow, or merge it
into the configuration file used by your existing supported installation:

```yaml
cronJobMonitor:
  enabled: true
```
