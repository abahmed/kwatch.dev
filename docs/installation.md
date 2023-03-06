---
sidebar_position: 2
title: Installation
description: a guide to deploy kwatch on kubernetes cluster
keywords: [kwatch, kubernetes, install, deploy, cluster, monitoring]
pagination_next: null
pagination_prev: null
---

# Installation

You can install kwatch into your kubernetes(k8s) cluster easily in one command

### Step 1: Get Configuration

Get the configuration template

```bash
curl  -L https://raw.githubusercontent.com/abahmed/kwatch/v0.8.1/deploy/config.yaml -o config.yaml
```

Here is an example of the configuration file

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
    maxRecentLogLines: <optional_number_of_lines>
    ignoreFailedGracefulShutdown: <optional_boolean>
    alert:
      slack:
        webhook: <webhook_url>
      pagerduty:
        integrationKey: <integration_key>
      discord:
        webhook: <webhook_url>
      telegram:
          token: <token_key>
          chatId: <chat_id>
      teams:
          webhook: <webhook_url>
      rocketchat:
          webhook: <webhook_url>
      mattermost:
          webhook: <webhook_url>
      opsgenie:
        apiKey: <api_key>
    namespaces:
      - <optional_namespace>
```

It contains full configurations that kwatch might have.

**you don't need to use all of them, check [General Configuration](./general-configuration) and [Channels](./channels)**

You need to update, or remove `<...>` this with your configuration and **remove unused configs**


### Step 2: Apply Configuration

Apply your configuration

```bash
kubectl apply -f config.yaml
```

### Step 3: Deploy kwatch

Deploy kwatch on your cluster with one command

```bash
kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.8.1/deploy/deploy.yaml
```