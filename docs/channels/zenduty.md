---
sidebar_position: 8
title: Zenduty
description: Forward Kubernetes crash alerts to Zenduty — configure integration key for kwatch
keywords: [kwatch, zenduty, kubernetes crash alerts, incident response, k8s monitoring]
pagination_next: null
pagination_prev: null
---

# Zenduty

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
kind: ConfigMap
metadata:
  name: kwatch
  namespace: kwatch
data:
  config.yaml: |
    alert:
      zenduty:
        integrationKey: YOUR_INTEGRATION_KEY
        alertType: critical
```

### Routing

```yaml
alert:
  zenduty:
    integrationKey: YOUR_INTEGRATION_KEY
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
    integrationKey: YOUR_INTEGRATION_KEY
    alertType: critical
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  zenduty:
    integrationKey: YOUR_INTEGRATION_KEY
    alertType: critical
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  zenduty:
    integrationKey: YOUR_INTEGRATION_KEY
    alertType: critical
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/zenduty.png" max-height="700px" alt="Zenduty notification screenshot" />
</p>
