---
sidebar_position: 5
title: Health Check Configuration
description: health check configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, health, check]
pagination_next: null
pagination_prev: null
---

# Health Check Configuration

| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `healthCheck.enabled`    | If set to true, enables health check endpoints | false | false |
| `healthCheck.port`       | Port for health check endpoints | false | 8060 |

**Endpoints:**
- `GET /healthz` - Returns "OK" (text/plain)
- `GET /health` - Returns `{"status": "ok"}` (application/json)

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
    healthCheck:
        enabled: true
        port: 8060
```
