---
sidebar_position: 4
title: Microsoft Teams
description: Get clear Kubernetes incident alerts in Microsoft Teams — configure webhook connector for kwatch
keywords: [kwatch, microsoft teams, kubernetes incident alerts, k8s notifications, devops]
pagination_next: null
pagination_prev: null
---

# 💼 Microsoft Teams

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.teams.webhook` | 🔗 Webhook URL | Yes |
| `alert.teams.title` | ✏️ Custom title | No |
| `alert.teams.text` | ✏️ Custom text | No |

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
  teams-webhook: "replace-me"
  config.yaml: |
    alert:
      teams:
        webhook: "${file:/config/teams-webhook}"
        title: "optional customized title"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  teams:
    webhook: "${file:/config/teams-webhook}"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/teams.png" max-height="700px" alt="Microsoft Teams notification screenshot" />
</p>
