---
title: Provider reference
description: Generated notification provider configuration metadata.
sidebar_position: 2
generated: true
---

# Provider reference

> This page is generated from the Kwatch provider catalog. Provider setup
> instructions remain in the provider-specific guides.

## alerta

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | false | `` | Alerta server URL |
| `apiKey` | string | true | true | `` | API key |
| `environment` | string | false | false | `Production` | Environment (default: Production) |
| `service` | string | false | false | `kwatch` | Service name (default: kwatch) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## clickup

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Personal API token |
| `listId` | string | true | false | `` | List ID to create tasks in |
| `priority` | integer | false | false | `` | Optional task priority (1-4) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## datadog

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API key |
| `site` | string | false | false | `datadoghq.com` | Datadog site (default: datadoghq.com) |
| `applicationKey` | string | false | true | `` | Optional application key |
| `title` | string | false | false | `` | Custom title |
| `alertType` | string | false | false | `error` | Alert type (default: error) |
| `tags` | list | false | false | `` | Comma-separated tags |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## dingtalk

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accessToken` | string | true | true | `` | Access token |
| `secret` | string | false | true | `` | Signing secret |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## discord

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Discord webhook URL |
| `title` | string | false | false | `` | Custom title |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## email

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `from` | string | true | false | `` | From address |
| `password` | string | true | true | `` | From password |
| `host` | string | true | false | `` | SMTP host |
| `port` | string | true | false | `` | SMTP port |
| `to` | string | true | false | `` | Receiver email |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## feishu

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Webhook URL |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## flock

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Incoming webhook URL |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## gitea

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Access token |
| `owner` | string | true | false | `` | Repository owner |
| `repo` | string | true | false | `` | Repository name |
| `url` | string | false | false | `` | Optional endpoint override (e.g. self-hosted Gitea) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## github

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Personal access token |
| `owner` | string | true | false | `` | Repository owner |
| `repo` | string | true | false | `` | Repository name |
| `url` | string | false | false | `` | Optional endpoint override (e.g. GitHub Enterprise) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## gitlab

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Personal access token |
| `projectId` | string | true | false | `` | Project ID |
| `url` | string | false | false | `` | Optional endpoint override (e.g. self-hosted GitLab) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## goalert

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | false | `` | GoAlert server URL |
| `token` | string | true | true | `` | API token |
| `serviceId` | string | true | false | `` | Service ID |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## googlechat

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Webhook URL |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## gotify

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | false | `` | Gotify server URL |
| `token` | string | true | true | `` | App token |
| `priority` | integer | false | false | `` | Priority (optional) |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## homeassistant

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Long-lived access token |
| `url` | string | false | false | `http://localhost:8123` | Server URL (default: http://localhost:8123) |
| `service` | string | false | false | `notify` | Notification service (default: notify) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## ifttt

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `key` | string | true | true | `` | Webhooks key |
| `event` | string | false | false | `kwatch` | Event name (default: kwatch) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## ilert

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `integrationKey` | string | true | true | `` | Integration key |
| `priority` | string | false | false | `HIGH` | Priority (LOW/HIGH/CRITICAL, default: HIGH) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## incidentio

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | true | `` | Incident.io URL |
| `apiKey` | string | false | true | `` | Optional API key |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## jira

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | false | `` | Jira base URL |
| `user` | string | true | false | `` | Email or username |
| `apiToken` | string | true | true | `` | API token |
| `projectKey` | string | true | false | `` | Project key |
| `issueType` | string | false | false | `Task` | Issue type (default: Task) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## line

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | LINE Notify access token |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## mailgun

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API key |
| `domain` | string | true | false | `` | Sending domain |
| `from` | string | true | false | `` | From address |
| `to` | string | true | false | `` | Recipients (comma-separated) |
| `subject` | string | false | false | `` | Email subject |
| `url` | string | false | false | `` | Optional endpoint override (e.g. EU region) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## matrix

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `homeServer` | string | true | false | `` | HomeServer URL |
| `accessToken` | string | true | true | `` | Access token |
| `internalRoomId` | string | true | false | `` | Room ID |
| `title` | string | false | false | `` | Custom title |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## mattermost

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Webhook URL |
| `title` | string | false | false | `` | Custom title |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## messagebird

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accessKey` | string | true | true | `` | Access key |
| `from` | string | true | false | `` | Sender number |
| `to` | string | true | false | `` | Recipient phone number |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## n8n

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | true | `` | Workflow webhook URL |
| `token` | string | false | true | `` | Optional auth header value |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## newrelic

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | User API key |
| `accountId` | string | true | false | `` | Account ID |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## ntfy

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `topic` | string | true | true | `` | Topic to publish to |
| `url` | string | false | false | `https://ntfy.sh` | Server URL (default: https://ntfy.sh) |
| `token` | string | false | true | `` | Optional auth token |
| `title` | string | false | false | `` | Custom title |
| `priority` | integer | false | false | `4` | Priority 1-5 (default: 4) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## opsgenie

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API Key |
| `title` | string | false | false | `` | Custom title |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## pagerduty

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `integrationKey` | string | true | true | `` | PagerDuty integration key |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## plivo

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `authId` | string | true | true | `` | Auth ID |
| `authToken` | string | true | true | `` | Auth token |
| `from` | string | true | false | `` | Sender number |
| `to` | string | true | false | `` | Recipient phone number |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## pushbullet

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accessToken` | string | true | true | `` | Access token |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## pushover

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Application token |
| `user` | string | true | true | `` | User or group key |
| `priority` | integer | false | false | `` | Priority from -2 to 2 (optional) |
| `retry` | integer | false | false | `` | Emergency retry interval in seconds |
| `expire` | integer | false | false | `` | Emergency expiration in seconds |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## resend

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API key |
| `from` | string | true | false | `` | From address |
| `to` | string | true | false | `` | Recipients (comma-separated) |
| `subject` | string | false | false | `` | Email subject |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## rocketchat

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Webhook URL |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## sendgrid

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API key |
| `from` | string | true | false | `` | From address |
| `to` | list | true | false | `` | Recipients (list of addresses) |
| `subject` | string | false | false | `` | Email subject |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## sensugo

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | false | `` | Sensu Go API URL |
| `apiKey` | string | true | true | `` | API key |
| `namespace` | string | false | false | `default` | Namespace (default: default) |
| `entity` | string | false | false | `kwatch` | Entity name (default: kwatch) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## ses

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accessKeyId` | string | true | true | `` | AWS access key ID |
| `secretAccessKey` | string | true | true | `` | AWS secret access key |
| `region` | string | false | false | `us-east-1` | AWS region (default: us-east-1) |
| `from` | string | true | false | `` | Verified sender address |
| `to` | string | true | false | `` | Recipients (comma-separated) |
| `subject` | string | false | false | `` | Email subject |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## signal

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `number` | string | true | false | `` | Sender phone number |
| `to` | string | true | false | `` | Recipient phone number |
| `url` | string | false | false | `http://localhost:8080` | REST API URL (default: http://localhost:8080) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## signl4

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `teamSecret` | string | true | true | `` | Team secret |
| `title` | string | false | false | `` | Custom title |
| `user` | string | false | false | `` | Optional alerting user |
| `url` | string | false | false | `` | Optional endpoint override |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## slack

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | false | true | `` | Slack webhook URL |
| `channel` | string | false | false | `` | Override channel |
| `title` | string | false | false | `` | Custom title |
| `text` | string | false | false | `` | Custom text |
| `compact` | boolean | false | false | `false` | Single-line mode |
| `token` | string | false | true | `` | Bot token (xoxb-...) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## sns

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accessKeyId` | string | true | true | `` | AWS access key ID |
| `secretAccessKey` | string | true | true | `` | AWS secret access key |
| `region` | string | false | false | `us-east-1` | AWS region (default: us-east-1) |
| `topicArn` | string | false | false | `` | SNS topic ARN (or targetArn) |
| `targetArn` | string | false | false | `` | SNS target ARN (alternative to topicArn) |
| `subject` | string | false | false | `` | Optional subject (email subscriptions) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## splunk

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | false | `` | HEC endpoint URL |
| `token` | string | true | true | `` | HEC token |
| `source` | string | false | false | `` | Source name (optional) |
| `sourcetype` | string | false | false | `` | Source type (optional) |
| `index` | string | false | false | `` | Index name (optional) |
| `host` | string | false | false | `` | Host name (optional) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## splunkoncall

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API key |
| `routingKey` | string | true | true | `` | Routing key |
| `url` | string | false | false | `` | Optional endpoint override |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## squadcast

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `serviceKey` | string | true | true | `` | Service key |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## teams

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Webhook URL |
| `title` | string | false | false | `` | Custom title |
| `text` | string | false | false | `` | Custom text |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## teamsworkflow

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Power Automate / Teams Workflow URL |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## telegram

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `token` | string | true | true | `` | Bot token |
| `chatId` | string | true | false | `` | Chat ID |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## threema

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `gatewayId` | string | true | true | `` | Threema Gateway ID |
| `secret` | string | true | true | `` | Gateway secret |
| `to` | string | true | false | `` | Recipient Threema ID |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## twilio

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accountSid` | string | true | true | `` | Account SID |
| `authToken` | string | true | true | `` | Auth token |
| `from` | string | true | false | `` | Sender phone number |
| `to` | string | true | false | `` | Recipient phone number |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## vonage

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `apiKey` | string | true | true | `` | API key |
| `apiSecret` | string | true | true | `` | API secret |
| `from` | string | true | false | `` | Sender name/number |
| `to` | string | true | false | `` | Recipient phone number |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## webex

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `accessToken` | string | true | true | `` | Bot access token |
| `roomId` | string | false | false | `` | Room ID (at least one destination required) |
| `toPersonEmail` | string | false | false | `` | Person email (at least one destination required) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## webhook

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | true | `` | Webhook URL |
| `headers` | headers | false | false | `` | Custom headers |
| `basicAuth.username` | string | false | false | `` | Basic-auth username. |
| `basicAuth.password` | string | false | true | `` | Basic-auth password. |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## wecom

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `webhook` | string | true | true | `` | Group robot webhook URL |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## zapier

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `url` | string | true | true | `` | Zap webhook URL |
| `token` | string | false | true | `` | Optional token |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## zenduty

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `integrationKey` | string | true | true | `` | Integration Key |
| `alertType` | string | false | false | `critical` | Alert type (default: critical) |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |

## zulip

| Field | Type | Required | Secret | Default | Description |
| --- | --- | --- | --- | --- | --- |
| `email` | string | true | false | `` | Bot email |
| `token` | string | true | true | `` | Bot API key |
| `channel` | string | true | false | `` | Channel/stream to post to |
| `url` | string | false | false | `https://zulip.example.com/api/v1/messages` | Server URL (default: https://zulip.example.com/api/v1/messages) |
| `title` | string | false | false | `` | Custom title |
| `routes` | json | false | false | `` | Optional JSON route filters. |
| `retry.maxAttempts` | integer | false | false | `` | Optional maximum retry attempts. |
| `retry.delay` | string | false | false | `` | Optional retry delay, for example 5s. |
| `fallback` | string | false | false | `` | Optional fallback provider name. |
