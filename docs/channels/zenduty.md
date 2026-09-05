---
sidebar_position: 8
title: Zenduty
description: Forward clear Kubernetes incident alerts to Zenduty — configure integration key for kwatch
keywords: [kwatch, zenduty, kubernetes incident alerts, incident response, k8s monitoring]
pagination_next: null
pagination_prev: null
---

# 🛡️ Zenduty

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.zenduty.integrationKey` | 🔑 Integration Key | Yes |
| `alert.zenduty.alertType` | 🏷️ Alert type (default: critical) | No |

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
  zenduty-integration-key: "replace-me"
  config.yaml: |
    alert:
      zenduty:
        integrationKey: "${file:/config/zenduty-integration-key}"
        alertType: critical
```

### Routing

```yaml
alert:
  zenduty:
    integrationKey: "${file:/config/zenduty-integration-key}"
    alertType: critical
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  zenduty:
    integrationKey: "${file:/config/zenduty-integration-key}"
    alertType: critical
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  zenduty:
    integrationKey: "${file:/config/zenduty-integration-key}"
    alertType: critical
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  zenduty:
    integrationKey: "${file:/config/zenduty-integration-key}"
    alertType: critical
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/zenduty.png" max-height="700px" alt="Zenduty notification screenshot" />
</p>
