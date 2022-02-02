---
sidebar_position: 7
title: Mattermost
description: kwatch configuration for mattermost
keywords: [kwatch, mattermost, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Mattermost

If you want to enable Mattermost, provide the webhook with optional text

### Configuration

| Parameter                             | Description                               |
|:--------------------------------------|:----------------------------------------- |
| `alert.mattermost.webhook`            | Mattermost webhook URL                    |
| `alert.mattermost.title`              | Customized title in Mattermost message    |
| `alert.mattermost.text`               | Customized text in Mattermost message     |


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
      mattermost:
        webhook: WEBHOOK_URL
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/mattermost.png" />
</p>