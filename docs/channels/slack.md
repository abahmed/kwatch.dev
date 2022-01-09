---
sidebar_position: 1
title: Slack
description: kwatch configuration for slack
keywords: [kwatch, slack, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Slack

If you want to enable Slack, provide the webhook with optional text and title

### Configuration

| Parameter             |  Description                              | Required       |
|:----------------------|:----------------------------------------- |:-------------- |
| `alert.slack.webhook` |  Slack webhook URL                        | Yes            |
| `alert.slack.title`   |  Customized title in slack message        | No             |
| `alert.slack.text`    |  Customized text in slack message         | No             |


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
      slack:
        webhook: WEBHOOK_URL
        title: "optional customized title"
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/slack.png" max-height="700px" />
</p>