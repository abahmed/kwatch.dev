---
sidebar_position: 10
title: Rollout Monitor
description: configure kwatch to detect Kubernetes Deployments stuck during rollout or past their progress deadline
keywords: [kwatch, kubernetes, configuration, monitor, rollout, deployment]
pagination_next: null
pagination_prev: null
---

# 🚀 Rollout monitor

A **rollout** is Kubernetes replacing old Pods with new ones after a change.
This monitor alerts when a Deployment gets stuck instead of finishing.

Watches for deployments that get stuck during rollout (ProgressDeadlineExceeded).

| Parameter | What it does |
|:---|---|
| `rolloutMonitor.enabled` | ✅ Watch for stuck deployments (default: true) |

### Configuration fragment

Add this fragment through `kwatch.sh`'s **Configure settings** flow, or merge it
into the configuration file used by your existing supported installation:

```yaml
rolloutMonitor:
  enabled: true
```
