---
sidebar_position: 2
title: Discord
description: kwatch configuration for discord
keywords: [kwatch, discord, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Discord

If you want to enable Discord, provide the webhook with optional text and title

### Configuration

| Parameter                |  Description                              | Required       |
|:-------------------------|:----------------------------------------- |:-------------- |
| `alert.discord.webhook`  |  Discord webhook URL                      | Yes            |
| `alert.discord.title`    |  Customized title in discord message      | No             |
| `alert.discord.text`     |  Customized text in discord message       | No             |


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
      discord:
        webhook: WEBHOOK_URL
        title: "optional customized title"
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/discord.png" max-height="400px" />
</p>