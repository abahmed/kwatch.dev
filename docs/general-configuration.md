---
sidebar_position: 3
title: General Configuration
description: general configuration used in kwatch
keywords: [kwatch, kubernetes, configuration, general]
pagination_next: null
pagination_prev: null
---

# General Configuration


| Parameter                |  Description                              | Required       | Default   |
|:-------------------------|:----------------------------------------- |:-------------- |:----------|
| `maxRecentLogLines`  |  Optional Max tail log lines in messages, if it's not provided it will get all log lines webhook URL                      | No            | 0  |
| `namespaces`    |  Optional comma separated list of namespaces that you want to watch or forbid, if it's not provided it will watch all namespaces. If you want to forbid a namespace, configure it with "!<namespace_name>". You can either set forbidden namespaces or allowed, not both.      | No             | [] |
| `ignoreFailedGracefulShutdown` | If set to true, containers which are forcefully killed during shutdown (as their graceful shutdown failed) are not reported as error | No | false |
| `disableUpdateCheck` | If set to true, does not check for and notify about kwatch updates | No | false |


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
    maxRecentLogLines: 20
    ignoreFailedGracefulShutdown: true
    namespaces:
      - default
```
