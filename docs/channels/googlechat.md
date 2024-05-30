---
sidebar_position: 4
title: Google Chat
description: kwatch configuration for google chat
keywords: [kwatch, googlechat, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Google Chat

If you want to enable Google Chat, provide the webhook with optional text

### Configuration

| Parameter                  |  Description                              | Required       |
|:---------------------------|:----------------------------------------- |:-------------- |
| `alert.googlechat.webhook` |  Google Chat webhook URL                  | Yes            |
| `alert.googlechat.text`    |  Customized text in Google Chat message   | No             |


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
      googlechat:
        webhook: WEBHOOK_URL
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/googlechat.png" />
</p>