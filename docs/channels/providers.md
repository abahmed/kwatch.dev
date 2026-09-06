---
sidebar_position: 2
title: All alert providers
description: Complete kwatch alert provider reference generated from the current provider catalog
keywords: [kwatch providers, Kubernetes alerts, alert integrations, webhooks, notifications]
---

# 📣 All alert providers

kwatch currently supports **56 alert providers**. This page is generated from the versioned `provider-catalog.tsv` shipped with the same release as `kwatch.sh`, so the fields here are the fields the guided setup can configure.

Use one or more blocks under `alert:`. Provider credentials, webhook URLs, tokens, API keys, passwords, and access tokens are **Secret-only**: mount them from a Kubernetes Secret and reference them with an exact `${file:/absolute/path}` value. Plain credentials and `${ENV_VAR}` substitutions are rejected for sensitive fields.

> **Source of truth:** `deploy/provider-catalog.tsv` (catalog v1). The catalog lists every canonical provider and field accepted by the current release.

`incident.io` is also accepted as a compatibility alias for the `incidentio`
provider name; it uses the same fields and is not a separate integration.

## Shared delivery options

Every provider supports the delivery controls listed in its table. `routes` filters by namespace, severity, or reason; `retry.maxAttempts` and `retry.delay` control retry behavior; `fallback` names another configured provider.

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
    routes:
      - namespaces: [production]
        severities: [high, critical]
    retry:
      maxAttempts: 3
      delay: 5s
    fallback: pagerduty
```

## Provider reference

### Slack (`slack`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.slack.webhook` | `string` | no | yes | url | — | Slack webhook URL |
| `alert.slack.channel` | `string` | no | no | — | — | Override channel |
| `alert.slack.title` | `string` | no | no | — | — | Custom title |
| `alert.slack.text` | `string` | no | no | — | — | Custom text |
| `alert.slack.compact` | `boolean` | no | no | boolean | false | Single-line mode |
| `alert.slack.token` | `string` | no | yes | — | — | Bot token (xoxb-...) |
| `alert.slack.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.slack.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.slack.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.slack.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Discord (`discord`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.discord.webhook` | `string` | yes | yes | url | — | Discord webhook URL |
| `alert.discord.title` | `string` | no | no | — | — | Custom title |
| `alert.discord.text` | `string` | no | no | — | — | Custom text |
| `alert.discord.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.discord.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.discord.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.discord.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Email (`email`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.email.from` | `string` | yes | no | — | — | From address |
| `alert.email.password` | `string` | yes | yes | — | — | From password |
| `alert.email.host` | `string` | yes | no | — | — | SMTP host |
| `alert.email.port` | `string` | yes | no | port | — | SMTP port |
| `alert.email.to` | `string` | yes | no | — | — | Receiver email |
| `alert.email.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.email.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.email.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.email.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### LINE (`line`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.line.token` | `string` | yes | yes | — | — | LINE Notify access token |
| `alert.line.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.line.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.line.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.line.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### PagerDuty (`pagerduty`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.pagerduty.integrationKey` | `string` | yes | yes | — | — | PagerDuty integration key |
| `alert.pagerduty.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.pagerduty.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.pagerduty.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.pagerduty.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Telegram (`telegram`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.telegram.token` | `string` | yes | yes | — | — | Bot token |
| `alert.telegram.chatId` | `string` | yes | no | telegram-chat-id | — | Chat ID |
| `alert.telegram.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.telegram.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.telegram.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.telegram.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Teams (`teams`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.teams.webhook` | `string` | yes | yes | url | — | Webhook URL |
| `alert.teams.title` | `string` | no | no | — | — | Custom title |
| `alert.teams.text` | `string` | no | no | — | — | Custom text |
| `alert.teams.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.teams.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.teams.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.teams.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Rocket.Chat (`rocketchat`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.rocketchat.webhook` | `string` | yes | yes | url | — | Webhook URL |
| `alert.rocketchat.text` | `string` | no | no | — | — | Custom text |
| `alert.rocketchat.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.rocketchat.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.rocketchat.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.rocketchat.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Mattermost (`mattermost`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.mattermost.webhook` | `string` | yes | yes | url | — | Webhook URL |
| `alert.mattermost.title` | `string` | no | no | — | — | Custom title |
| `alert.mattermost.text` | `string` | no | no | — | — | Custom text |
| `alert.mattermost.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.mattermost.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.mattermost.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.mattermost.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Opsgenie (`opsgenie`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.opsgenie.apiKey` | `string` | yes | yes | — | — | API Key |
| `alert.opsgenie.title` | `string` | no | no | — | — | Custom title |
| `alert.opsgenie.text` | `string` | no | no | — | — | Custom text |
| `alert.opsgenie.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.opsgenie.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.opsgenie.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.opsgenie.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Matrix (`matrix`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.matrix.homeServer` | `string` | yes | no | url | — | HomeServer URL |
| `alert.matrix.accessToken` | `string` | yes | yes | — | — | Access token |
| `alert.matrix.internalRoomId` | `string` | yes | no | — | — | Room ID |
| `alert.matrix.title` | `string` | no | no | — | — | Custom title |
| `alert.matrix.text` | `string` | no | no | — | — | Custom text |
| `alert.matrix.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.matrix.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.matrix.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.matrix.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Dingtalk (`dingtalk`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.dingtalk.accessToken` | `string` | yes | yes | — | — | Access token |
| `alert.dingtalk.secret` | `string` | no | yes | — | — | Signing secret |
| `alert.dingtalk.title` | `string` | no | no | — | — | Custom title |
| `alert.dingtalk.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.dingtalk.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.dingtalk.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.dingtalk.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Feishu (`feishu`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.feishu.webhook` | `string` | yes | yes | url | — | Webhook URL |
| `alert.feishu.title` | `string` | no | no | — | — | Custom title |
| `alert.feishu.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.feishu.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.feishu.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.feishu.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Zenduty (`zenduty`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.zenduty.integrationKey` | `string` | yes | yes | — | — | Integration Key |
| `alert.zenduty.alertType` | `string` | no | no | — | critical | Alert type (default: critical) |
| `alert.zenduty.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.zenduty.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.zenduty.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.zenduty.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Google Chat (`googlechat`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.googlechat.webhook` | `string` | yes | yes | url | — | Webhook URL |
| `alert.googlechat.text` | `string` | no | no | — | — | Custom text |
| `alert.googlechat.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.googlechat.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.googlechat.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.googlechat.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Gotify (`gotify`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.gotify.url` | `string` | yes | no | url | — | Gotify server URL |
| `alert.gotify.token` | `string` | yes | yes | — | — | App token |
| `alert.gotify.priority` | `integer` | no | no | integer | — | Priority (optional) |
| `alert.gotify.title` | `string` | no | no | — | — | Custom title |
| `alert.gotify.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.gotify.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.gotify.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.gotify.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### ntfy (`ntfy`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.ntfy.topic` | `string` | yes | yes | — | — | Topic to publish to |
| `alert.ntfy.url` | `string` | no | no | url | https://ntfy.sh | Server URL (default: https://ntfy.sh) |
| `alert.ntfy.token` | `string` | no | yes | — | — | Optional auth token |
| `alert.ntfy.title` | `string` | no | no | — | — | Custom title |
| `alert.ntfy.priority` | `integer` | no | no | integer | 4 | Priority 1-5 (default: 4) |
| `alert.ntfy.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.ntfy.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.ntfy.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.ntfy.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Pushover (`pushover`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.pushover.token` | `string` | yes | yes | — | — | Application token |
| `alert.pushover.user` | `string` | yes | yes | — | — | User or group key |
| `alert.pushover.priority` | `integer` | no | no | integer | — | Priority (optional) |
| `alert.pushover.title` | `string` | no | no | — | — | Custom title |
| `alert.pushover.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.pushover.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.pushover.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.pushover.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Webex (`webex`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.webex.accessToken` | `string` | yes | yes | — | — | Bot access token |
| `alert.webex.roomId` | `string` | no | no | — | — | Room ID (provide this or `toPersonEmail`) |
| `alert.webex.toPersonEmail` | `string` | no | no | — | — | Person email (provide this or `roomId`) |
| `alert.webex.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.webex.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.webex.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.webex.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### GitHub (`github`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.github.token` | `string` | yes | yes | — | — | Personal access token |
| `alert.github.owner` | `string` | yes | no | — | — | Repository owner |
| `alert.github.repo` | `string` | yes | no | — | — | Repository name |
| `alert.github.url` | `string` | no | no | url | — | Optional endpoint override (e.g. GitHub Enterprise) |
| `alert.github.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.github.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.github.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.github.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### GitLab (`gitlab`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.gitlab.token` | `string` | yes | yes | — | — | Personal access token |
| `alert.gitlab.projectId` | `string` | yes | no | — | — | Project ID |
| `alert.gitlab.url` | `string` | no | no | url | — | Optional endpoint override (e.g. self-hosted GitLab) |
| `alert.gitlab.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.gitlab.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.gitlab.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.gitlab.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Gitea (`gitea`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.gitea.token` | `string` | yes | yes | — | — | Access token |
| `alert.gitea.owner` | `string` | yes | no | — | — | Repository owner |
| `alert.gitea.repo` | `string` | yes | no | — | — | Repository name |
| `alert.gitea.url` | `string` | no | no | url | — | Optional endpoint override (e.g. self-hosted Gitea) |
| `alert.gitea.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.gitea.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.gitea.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.gitea.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Zapier (`zapier`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.zapier.url` | `string` | yes | yes | url | — | Zap webhook URL |
| `alert.zapier.token` | `string` | no | yes | — | — | Optional token |
| `alert.zapier.title` | `string` | no | no | — | — | Custom title |
| `alert.zapier.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.zapier.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.zapier.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.zapier.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### n8n (`n8n`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.n8n.url` | `string` | yes | yes | url | — | Workflow webhook URL |
| `alert.n8n.token` | `string` | no | yes | — | — | Optional auth header value |
| `alert.n8n.title` | `string` | no | no | — | — | Custom title |
| `alert.n8n.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.n8n.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.n8n.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.n8n.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### IFTTT (`ifttt`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.ifttt.key` | `string` | yes | yes | — | — | Webhooks key |
| `alert.ifttt.event` | `string` | no | no | — | kwatch | Event name (default: kwatch) |
| `alert.ifttt.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.ifttt.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.ifttt.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.ifttt.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Teams Workflow (`teamsworkflow`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.teamsworkflow.webhook` | `string` | yes | yes | url | — | Power Automate / Teams Workflow URL |
| `alert.teamsworkflow.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.teamsworkflow.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.teamsworkflow.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.teamsworkflow.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Zulip (`zulip`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.zulip.email` | `string` | yes | no | — | — | Bot email |
| `alert.zulip.token` | `string` | yes | yes | — | — | Bot API key |
| `alert.zulip.channel` | `string` | yes | no | — | — | Channel/stream to post to |
| `alert.zulip.url` | `string` | no | no | url | https://zulip.example.com/api/v1/messages | Server URL (default: https://zulip.example.com/api/v1/messages) |
| `alert.zulip.title` | `string` | no | no | — | — | Custom title |
| `alert.zulip.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.zulip.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.zulip.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.zulip.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Home Assistant (`homeassistant`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.homeassistant.token` | `string` | yes | yes | — | — | Long-lived access token |
| `alert.homeassistant.url` | `string` | no | no | url | http://localhost:8123 | Server URL (default: http://localhost:8123) |
| `alert.homeassistant.service` | `string` | no | no | — | notify | Notification service (default: notify) |
| `alert.homeassistant.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.homeassistant.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.homeassistant.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.homeassistant.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Splunk (`splunk`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.splunk.url` | `string` | yes | no | url | — | HEC endpoint URL |
| `alert.splunk.token` | `string` | yes | yes | — | — | HEC token |
| `alert.splunk.source` | `string` | no | no | — | — | Source name (optional) |
| `alert.splunk.sourcetype` | `string` | no | no | — | — | Source type (optional) |
| `alert.splunk.index` | `string` | no | no | — | — | Index name (optional) |
| `alert.splunk.host` | `string` | no | no | — | — | Host name (optional) |
| `alert.splunk.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.splunk.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.splunk.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.splunk.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Datadog (`datadog`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.datadog.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.datadog.site` | `string` | no | no | — | datadoghq.com | Datadog site (default: datadoghq.com) |
| `alert.datadog.applicationKey` | `string` | no | yes | — | — | Optional application key |
| `alert.datadog.title` | `string` | no | no | — | — | Custom title |
| `alert.datadog.alertType` | `string` | no | no | — | error | Alert type (default: error) |
| `alert.datadog.tags` | `list` | no | no | list | — | Comma-separated tags |
| `alert.datadog.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.datadog.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.datadog.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.datadog.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### New Relic (`newrelic`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.newrelic.apiKey` | `string` | yes | yes | — | — | User API key |
| `alert.newrelic.accountId` | `string` | yes | no | — | — | Account ID |
| `alert.newrelic.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.newrelic.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.newrelic.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.newrelic.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### ClickUp (`clickup`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.clickup.token` | `string` | yes | yes | — | — | Personal API token |
| `alert.clickup.listId` | `string` | yes | no | — | — | List ID to create tasks in |
| `alert.clickup.priority` | `integer` | no | no | integer | — | Optional task priority (1-4) |
| `alert.clickup.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.clickup.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.clickup.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.clickup.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### iLert (`ilert`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.ilert.integrationKey` | `string` | yes | yes | — | — | Integration key |
| `alert.ilert.priority` | `integer` | no | no | integer | — | Priority (LOW/HIGH/CRITICAL, default: HIGH) |
| `alert.ilert.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.ilert.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.ilert.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.ilert.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Incident.io (`incidentio`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.incidentio.url` | `string` | yes | yes | url | — | Incident.io URL |
| `alert.incidentio.apiKey` | `string` | no | yes | — | — | Optional API key |
| `alert.incidentio.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.incidentio.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.incidentio.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.incidentio.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Squadcast (`squadcast`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.squadcast.serviceKey` | `string` | yes | yes | — | — | Service key |
| `alert.squadcast.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.squadcast.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.squadcast.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.squadcast.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### SIGNL4 (`signl4`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.signl4.teamSecret` | `string` | yes | yes | — | — | Team secret |
| `alert.signl4.title` | `string` | no | no | — | — | Custom title |
| `alert.signl4.user` | `string` | no | no | — | — | Optional alerting user |
| `alert.signl4.url` | `string` | no | no | url | — | Optional endpoint override |
| `alert.signl4.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.signl4.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.signl4.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.signl4.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Twilio (`twilio`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.twilio.accountSid` | `string` | yes | yes | — | — | Account SID |
| `alert.twilio.authToken` | `string` | yes | yes | — | — | Auth token |
| `alert.twilio.from` | `string` | yes | no | — | — | Sender phone number |
| `alert.twilio.to` | `string` | yes | no | — | — | Recipient phone number |
| `alert.twilio.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.twilio.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.twilio.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.twilio.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Vonage (`vonage`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.vonage.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.vonage.apiSecret` | `string` | yes | yes | — | — | API secret |
| `alert.vonage.from` | `string` | yes | no | — | — | Sender name/number |
| `alert.vonage.to` | `string` | yes | no | — | — | Recipient phone number |
| `alert.vonage.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.vonage.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.vonage.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.vonage.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Plivo (`plivo`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.plivo.authId` | `string` | yes | yes | — | — | Auth ID |
| `alert.plivo.authToken` | `string` | yes | yes | — | — | Auth token |
| `alert.plivo.from` | `string` | yes | no | — | — | Sender number |
| `alert.plivo.to` | `string` | yes | no | — | — | Recipient phone number |
| `alert.plivo.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.plivo.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.plivo.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.plivo.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### MessageBird (`messagebird`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.messagebird.accessKey` | `string` | yes | yes | — | — | Access key |
| `alert.messagebird.from` | `string` | yes | no | — | — | Sender number |
| `alert.messagebird.to` | `string` | yes | no | — | — | Recipient phone number |
| `alert.messagebird.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.messagebird.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.messagebird.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.messagebird.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Signal (`signal`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.signal.number` | `string` | yes | no | — | — | Sender phone number |
| `alert.signal.to` | `string` | yes | no | — | — | Recipient phone number |
| `alert.signal.url` | `string` | no | no | url | http://localhost:8080 | REST API URL (default: http://localhost:8080) |
| `alert.signal.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.signal.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.signal.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.signal.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### SendGrid (`sendgrid`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.sendgrid.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.sendgrid.from` | `string` | yes | no | — | — | From address |
| `alert.sendgrid.to` | `list` | yes | no | list | — | Recipients (list of addresses) |
| `alert.sendgrid.subject` | `string` | no | no | — | — | Email subject |
| `alert.sendgrid.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.sendgrid.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.sendgrid.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.sendgrid.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### SES (`ses`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.ses.accessKeyId` | `string` | yes | yes | — | — | AWS access key ID |
| `alert.ses.secretAccessKey` | `string` | yes | yes | — | — | AWS secret access key |
| `alert.ses.region` | `string` | no | no | — | us-east-1 | AWS region (default: us-east-1) |
| `alert.ses.from` | `string` | yes | no | — | — | Verified sender address |
| `alert.ses.to` | `string` | yes | no | — | — | Recipients (comma-separated) |
| `alert.ses.subject` | `string` | no | no | — | — | Email subject |
| `alert.ses.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.ses.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.ses.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.ses.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### SNS (`sns`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.sns.accessKeyId` | `string` | yes | yes | — | — | AWS access key ID |
| `alert.sns.secretAccessKey` | `string` | yes | yes | — | — | AWS secret access key |
| `alert.sns.region` | `string` | no | no | — | us-east-1 | AWS region (default: us-east-1) |
| `alert.sns.topicArn` | `string` | no | no | — | — | SNS topic ARN (or targetArn) |
| `alert.sns.targetArn` | `string` | no | no | — | — | SNS target ARN (alternative to topicArn). |
| `alert.sns.subject` | `string` | no | no | — | — | Optional subject (email subscriptions) |
| `alert.sns.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.sns.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.sns.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.sns.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Jira (`jira`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.jira.url` | `string` | yes | no | url | — | Jira base URL |
| `alert.jira.user` | `string` | yes | no | — | — | Email or username |
| `alert.jira.apiToken` | `string` | yes | yes | — | — | API token |
| `alert.jira.projectKey` | `string` | yes | no | — | — | Project key |
| `alert.jira.issueType` | `string` | no | no | — | Task | Issue type (default: Task) |
| `alert.jira.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.jira.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.jira.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.jira.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### WeCom (`wecom`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.wecom.webhook` | `string` | yes | yes | url | — | Group robot webhook URL |
| `alert.wecom.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.wecom.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.wecom.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.wecom.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Splunk On-Call (`splunkoncall`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.splunkoncall.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.splunkoncall.routingKey` | `string` | yes | yes | — | — | Routing key |
| `alert.splunkoncall.url` | `string` | no | no | url | — | Optional endpoint override |
| `alert.splunkoncall.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.splunkoncall.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.splunkoncall.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.splunkoncall.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Mailgun (`mailgun`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.mailgun.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.mailgun.domain` | `string` | yes | no | — | — | Sending domain |
| `alert.mailgun.from` | `string` | yes | no | — | — | From address |
| `alert.mailgun.to` | `string` | yes | no | — | — | Recipients (comma-separated) |
| `alert.mailgun.subject` | `string` | no | no | — | — | Email subject |
| `alert.mailgun.url` | `string` | no | no | url | — | Optional endpoint override (e.g. EU region) |
| `alert.mailgun.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.mailgun.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.mailgun.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.mailgun.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Resend (`resend`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.resend.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.resend.from` | `string` | yes | no | — | — | From address |
| `alert.resend.to` | `string` | yes | no | — | — | Recipients (comma-separated) |
| `alert.resend.subject` | `string` | no | no | — | — | Email subject |
| `alert.resend.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.resend.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.resend.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.resend.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### GoAlert (`goalert`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.goalert.url` | `string` | no | no | url | https://goalert.example.com | GoAlert URL (default: https://goalert.example.com) |
| `alert.goalert.token` | `string` | yes | yes | — | — | API token |
| `alert.goalert.serviceId` | `string` | yes | no | — | — | Service ID |
| `alert.goalert.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.goalert.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.goalert.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.goalert.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Alerta (`alerta`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.alerta.url` | `string` | yes | no | url | — | Alerta server URL |
| `alert.alerta.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.alerta.environment` | `string` | no | no | — | Production | Environment (default: Production) |
| `alert.alerta.service` | `string` | no | no | — | kwatch | Service name (default: kwatch) |
| `alert.alerta.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.alerta.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.alerta.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.alerta.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Threema (`threema`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.threema.gatewayId` | `string` | yes | yes | — | — | Threema Gateway ID |
| `alert.threema.secret` | `string` | yes | yes | — | — | Gateway secret |
| `alert.threema.to` | `string` | yes | no | — | — | Recipient Threema ID |
| `alert.threema.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.threema.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.threema.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.threema.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Flock (`flock`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.flock.webhook` | `string` | yes | yes | url | — | Incoming webhook URL |
| `alert.flock.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.flock.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.flock.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.flock.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Pushbullet (`pushbullet`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.pushbullet.accessToken` | `string` | yes | yes | — | — | Access token |
| `alert.pushbullet.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.pushbullet.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.pushbullet.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.pushbullet.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### SensiGo (`sensugo`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.sensugo.url` | `string` | yes | no | url | — | Sensu Go API URL |
| `alert.sensugo.apiKey` | `string` | yes | yes | — | — | API key |
| `alert.sensugo.namespace` | `string` | no | no | — | default | Namespace (default: default) |
| `alert.sensugo.entity` | `string` | no | no | — | kwatch | Entity name (default: kwatch) |
| `alert.sensugo.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.sensugo.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.sensugo.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.sensugo.fallback` | `string` | no | no | — | — | Optional fallback provider name. |


### Generic Webhook (`webhook`)

| Field | Type | Required | Secret | Validation | Default | Description |
|:--|:--|:--:|:--:|:--|:--|:--|
| `alert.webhook.url` | `string` | yes | yes | url | — | Webhook URL |
| `alert.webhook.headers` | `headers` | no | no | — | — | Custom headers |
| `alert.webhook.basicAuth.username` | `string` | no | no | — | — | Basic-auth username. |
| `alert.webhook.basicAuth.password` | `string` | no | yes | — | — | Basic-auth password. |
| `alert.webhook.routes` | `json` | no | no | json | — | Optional JSON route filters. |
| `alert.webhook.retry.maxAttempts` | `integer` | no | no | integer | — | Optional maximum retry attempts. |
| `alert.webhook.retry.delay` | `string` | no | no | — | — | Optional retry delay, for example 5s. |
| `alert.webhook.fallback` | `string` | no | no | — | — | Optional fallback provider name. |
