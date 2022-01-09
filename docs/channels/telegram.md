---
sidebar_position: 6
title: Telegram
description: kwatch configuration for telegram
keywords: [kwatch, telegram, chat, monitor, detect, crash, kubernetes, cluster]
pagination_next: null
pagination_prev: null
---

# Telegram

If you want to enable Telegram, provide a valid token and the chatId

### Configuration

| Parameter               |  Description                              | Required       |
|:------------------------|:----------------------------------------- |:-------------- |
| `alert.telegram.token`  |  Telegram token                           | Yes            |
| `alert.telegram.chatId` |  Customized title in slack message        | Yes            |


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
      telegram:
        token: TOKEN
        chatId: CHAT_ID
```

### Screenshot

<p align="center">
    <img src="./../../img/telegram.png" max-height="700px" />
</p>