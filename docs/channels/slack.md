---
sidebar_position: 1
title: Slack
description: kwatch configuration for slack
keywords: [kwatch, slack, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Slack

If you want to enable Slack, provide either a webhook URL or a bot token with channel

**Webhook mode:**

| Parameter             |  Description                              | Required       |
|:----------------------|:----------------------------------------- |:-------------- |
| `alert.slack.webhook` |  Slack webhook URL                        | Yes            |
| `alert.slack.title`   |  Customized title in slack message        | No             |
| `alert.slack.text`    |  Customized text in slack message         | No             |

**Bot Token mode:**

| Parameter             |  Description                              | Required       |
|:----------------------|:----------------------------------------- |:-------------- |
| `alert.slack.token`   |  Slack bot token (xoxb-...)               | Yes            |
| `alert.slack.channel` |  Channel to post to (e.g. #alerts)        | Yes            |
| `alert.slack.title`   |  Customized title in slack message        | No             |
| `alert.slack.text`    |  Customized text in slack message         | No             |


### Example (Webhook)

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

### Example (Bot Token)

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
        token: xoxb-your-token
        channel: "#alerts"
        title: "optional customized title"
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/slack.png" max-height="700px" />
</p>