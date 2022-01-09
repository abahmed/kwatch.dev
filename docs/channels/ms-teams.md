---
sidebar_position: 3
title: Microsoft Teams
description: kwatch configuration for ms teams
keywords: [kwatch, teams, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Microsoft Teams

If you want to enable Microsoft Teams, provide the channel webhook with optional text and title

### Configuration

| Parameter             |  Description                                        | Required       |
|:----------------------|:--------------------------------------------------- |:-------------- |
| `alert.teams.webhook` |  Microsoft teams webhook URL                        | Yes            |
| `alert.teams.title`   |  Customized title in Microsoft teams message        | No             |
| `alert.teams.text`    |  Customized text in Microsoft teams message         | No             |


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
      teams:
        webhook: WEBHOOK_URL
        title: "optional customized title"
        text: "optional customized text"
```

### Screenshot

<p align="center">
    <img src="./../../img/teams.png" max-height="700px" />
</p>