---
sidebar_position: 13
title: DingTalk
description: Send clear Kubernetes incident alerts to DingTalk — configure webhook and security tokens for kwatch
keywords: [kwatch, dingtalk, kubernetes incident alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 🔔 DingTalk

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
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  dingtalk-access-token: "replace-me"
  dingtalk-secret: "replace-me"
  config.yaml: |
    alert:
      dingtalk:
        accessToken: "${file:/config/dingtalk-access-token}"
        secret: "${file:/config/dingtalk-secret}"
        title: "optional customized title"
```

### Routing

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  dingtalk:
    accessToken: "${file:/config/dingtalk-access-token}"
    secret: "${file:/config/dingtalk-secret}"
    compact: true
```
