---
sidebar_position: 7
title: PagerDuty
description: Route Kubernetes crash alerts to PagerDuty — configure integration key and severity routing for kwatch
keywords: [kwatch, pagerduty, kubernetes crash alerts, incident response, k8s monitoring]
pagination_next: null
pagination_prev: null
---

# PagerDuty

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.pagerduty.integrationKey` | 🔑 PagerDuty integration key | Yes |

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
      pagerduty:
        integrationKey: YOUR_INTEGRATION_KEY
```

### Routing

```yaml
alert:
  pagerduty:
    integrationKey: YOUR_INTEGRATION_KEY
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  pagerduty:
    integrationKey: YOUR_INTEGRATION_KEY
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  pagerduty:
    integrationKey: YOUR_INTEGRATION_KEY
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  pagerduty:
    integrationKey: YOUR_INTEGRATION_KEY
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/pagerduty.png" max-height="700px" alt="PagerDuty notification screenshot" />
</p>
