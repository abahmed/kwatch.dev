---
sidebar_position: 4
title: Rocket.Chat
description: kwatch configuration for rocket chat
keywords: [kwatch, rocketchat, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Rocket.Chat

If you want to enable Rocket Chat, provide the webhook with optional text

### Configuration

| Parameter                  |  Description                              | Required       |
|:---------------------------|:----------------------------------------- |:-------------- |
| `alert.rocketchat.webhook` |  Rocket Chat webhook URL                  | Yes            |
| `alert.rocketchat.text`    |  Customized text in Rocket Chat message   | No             |


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
      rocketchat:
        webhook: WEBHOOK_URL
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/rocketchat.png" />
</p>