---
sidebar_position: 14
title: FeiShu
description: Route Kubernetes crash alerts to FeiShu (Lark) — configure webhook URL for kwatch notifications
keywords: [kwatch, feishu, lark, kubernetes crash alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# FeiShu (Lark)

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.feishu.webhook` | 🔗 Webhook URL | Yes |
| `alert.feishu.title` | ✏️ Custom title | No |

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
      feishu:
        webhook: WEBHOOK_URL
        title: "optional customized title"
```

### Routing

```yaml
alert:
  feishu:
    webhook: WEBHOOK_URL
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  feishu:
    webhook: WEBHOOK_URL
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  feishu:
    webhook: WEBHOOK_URL
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  feishu:
    webhook: WEBHOOK_URL
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/feishu.png" max-height="700px" alt="FeiShu notification screenshot" />
</p>
