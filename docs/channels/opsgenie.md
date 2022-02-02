---
sidebar_position: 8
title: Opsgenie
description: kwatch configuration for opsgenie
keywords: [kwatch, opsgenie, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Opsgenie

If you want to enable Opsgenie, provide the API key

### Configuration

| Parameter                             | Description                             |
|:--------------------------------------|:--------------------------------------- |
| `alert.opsgenie.apiKey`               | Opsgenie API Key                        |
| `alert.opsgenie.title`                | Customized title in Opsgenie message    |
| `alert.opsgenie.text`                 | Customized text in Opsgenie message     |

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
        apiKey: API_KEY
```

### Screenshot

<p align="center">
    <img src="./../../img/opsgenie.png" max-height="700px" />
</p>