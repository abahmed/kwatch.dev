---
sidebar_position: 14
title: FeiShu
description: Route clear Kubernetes incident alerts to FeiShu (Lark) — configure webhook URL for kwatch
keywords: [kwatch, feishu, lark, kubernetes incident alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 🐦 FeiShu (Lark)

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
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  feishu-webhook: "replace-me"
  config.yaml: |
    alert:
      feishu:
        webhook: "${file:/config/feishu-webhook}"
        title: "optional customized title"
```

### Routing

```yaml
alert:
  feishu:
    webhook: "${file:/config/feishu-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  feishu:
    webhook: "${file:/config/feishu-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  feishu:
    webhook: "${file:/config/feishu-webhook}"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  feishu:
    webhook: "${file:/config/feishu-webhook}"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/feishu.png" max-height="700px" alt="FeiShu notification screenshot" />
</p>
