---
sidebar_position: 5
title: Zenduty
description: kwatch configuration for zenduty
keywords: [kwatch, zenduty, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Zenduty

If you want to enable Zenduty, provide the integration key

### Configuration

| Parameter                        |  Description                              | Required       |
|:---------------------------------|:----------------------------------------- |:-------------- |
| `alert.zenduty.integrationKey` |  Zenduty integration key [more info](https://www.zenduty.com/docs/api-integration/#to-integrate-any-applications-webhook-with-zenduty-complete-the-following-steps)                        | Yes            |
| `alert.zenduty.alertType`      | Optional alert type of incident: critical, acknowledged, resolved, error, warning, info (default: critical) |  NO  |

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
        integrationKey: INTEGRATION_KEY
```

### Screenshot

<p align="center">
    <img src="./../../img/zenduty.png" max-height="700px" />
</p>