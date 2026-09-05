---
sidebar_position: 12
title: Job Monitor
description: configure kwatch to detect failed, suspended, or overdue Kubernetes Jobs
keywords: [kwatch, kubernetes, configuration, monitor, job]
pagination_next: null
pagination_prev: null
---

# 🧑‍💼 Job monitor

A **Job** runs work until it succeeds. This monitor alerts when a Job fails or
becomes suspended instead of completing normally.

Watches for Jobs that fail or become suspended.

| Parameter | What it does |
|:---|---|
| `jobMonitor.enabled` | ✅ Watch for failed/suspended Jobs (default: true) |

### Configuration fragment

Add this fragment through `kwatch.sh`'s **Configure settings** flow, or merge it
into the configuration file used by your existing supported installation:

```yaml
jobMonitor:
  enabled: true
```
