---
sidebar_position: 11
title: Opsgenie
description: Forward Kubernetes crash alerts to Opsgenie — configure API key and team routing for kwatch
keywords: [kwatch, opsgenie, kubernetes crash alerts, incident management, k8s monitoring]
pagination_next: null
pagination_prev: null
---

# Opsgenie

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.opsgenie.apiKey` | 🔑 API Key | Yes |
| `alert.opsgenie.title` | ✏️ Custom title | No |
| `alert.opsgenie.text` | ✏️ Custom text | No |

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
      opsgenie:
        apiKey: "YOUR_API_KEY"
        title: "optional customized title"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  opsgenie:
    apiKey: "YOUR_API_KEY"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  opsgenie:
    apiKey: "YOUR_API_KEY"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  opsgenie:
    apiKey: "YOUR_API_KEY"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  opsgenie:
    apiKey: "YOUR_API_KEY"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/opsgenie.png" max-height="700px" alt="Opsgenie notification screenshot" />
</p>
