---
sidebar_position: 13
title: DingTalk
description: Send Kubernetes crash alerts to DingTalk — configure webhook and security tokens for kwatch
keywords: [kwatch, dingtalk, kubernetes crash alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# DingTalk

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.dingtalk.accessToken` | 🔑 Access token | Yes |
| `alert.dingtalk.secret` | 🔐 Signing secret | No |
| `alert.dingtalk.title` | ✏️ Custom title | No |

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
    alert:
      dingtalk:
        accessToken: "YOUR_ACCESS_TOKEN"
        secret: "YOUR_SECRET"
        title: "optional customized title"
```

### Routing

```yaml
alert:
  dingtalk:
    accessToken: "YOUR_ACCESS_TOKEN"
    secret: "YOUR_SECRET"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  dingtalk:
    accessToken: "YOUR_ACCESS_TOKEN"
    secret: "YOUR_SECRET"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  dingtalk:
    accessToken: "YOUR_ACCESS_TOKEN"
    secret: "YOUR_SECRET"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  dingtalk:
    accessToken: "YOUR_ACCESS_TOKEN"
    secret: "YOUR_SECRET"
    compact: true
```