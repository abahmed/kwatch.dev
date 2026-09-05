---
sidebar_position: 11
title: Opsgenie
description: Forward clear Kubernetes incident alerts to Opsgenie — configure API key and team routing for kwatch
keywords: [kwatch, opsgenie, kubernetes incident alerts, incident management, k8s monitoring]
pagination_next: null
pagination_prev: null
---

# 🔔 Opsgenie

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
kind: Secret
metadata:
  name: kwatch
  namespace: kwatch
stringData:
  opsgenie-api-key: "replace-me"
  config.yaml: |
    alert:
      opsgenie:
        apiKey: "${file:/config/opsgenie-api-key}"
        title: "optional customized title"
        text: "optional customized text"
```

### Routing

```yaml
alert:
  opsgenie:
    apiKey: "${file:/config/opsgenie-api-key}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

### Retry

```yaml
alert:
  opsgenie:
    apiKey: "${file:/config/opsgenie-api-key}"
    retry:
      maxAttempts: 5
      delay: 5s
```

### Fallback

```yaml
alert:
  opsgenie:
    apiKey: "${file:/config/opsgenie-api-key}"
    fallback: <another_provider>
```

### Compact mode

```yaml
alert:
  opsgenie:
    apiKey: "${file:/config/opsgenie-api-key}"
    compact: true
```

### Screenshot

<p align="center">
    <img src="./../../img/opsgenie.png" max-height="700px" alt="Opsgenie notification screenshot" />
</p>
