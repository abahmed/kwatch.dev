#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/abahmed/kwatch"
RELEASES_URL="https://api.github.com/repos/abahmed/kwatch/releases/latest"
RELEASES_LIST_URL="https://api.github.com/repos/abahmed/kwatch/releases?per_page=30"
DEFAULT_NAMESPACE="kwatch"
DEFAULT_RELEASE="kwatch"
CATALOG_VERSION=1
FEATURE_CATALOG_VERSION=1
PROVIDER_CATALOG_VERSION=1
MAX_KUBECTL_ATTEMPTS=3
SELECTED_CONTEXT=""
FEATURE_CATALOG_SOURCE="unavailable"
FEATURE_CATALOG=()
PROVIDER_CATALOG_SOURCE="embedded"
CONFIG_MOUNT_PATH="/config"

# provider|display|field|type|required|secret|validation|default|description
PROVIDER_CATALOG=(
  'slack|Slack|webhook|string|false|true|url||Slack webhook URL'
  'slack|Slack|channel|string|false|false|||Override channel'
  'slack|Slack|title|string|false|false|||Custom title'
  'slack|Slack|text|string|false|false|||Custom text'
  'slack|Slack|compact|boolean|false|false|boolean|false|Single-line mode'
  'slack|Slack|token|string|false|true|||Bot token (xoxb-...)'
  'discord|Discord|webhook|string|true|true|url||Discord webhook URL'
  'discord|Discord|title|string|false|false|||Custom title'
  'discord|Discord|text|string|false|false|||Custom text'
  'email|Email|from|string|true|false|||From address'
  'email|Email|password|string|true|true|||From password'
  'email|Email|host|string|true|false|||SMTP host'
  'email|Email|port|string|true|false|port||SMTP port'
  'email|Email|to|string|true|false|||Receiver email'
  'line|LINE|token|string|true|true|||LINE Notify access token'
  'pagerduty|PagerDuty|integrationKey|string|true|true|||PagerDuty integration key'
  'telegram|Telegram|token|string|true|true|||Bot token'
  'telegram|Telegram|chatId|string|true|false|telegram-chat-id||Chat ID'
  'teams|Teams|webhook|string|true|true|url||Webhook URL'
  'teams|Teams|title|string|false|false|||Custom title'
  'teams|Teams|text|string|false|false|||Custom text'
  'rocketchat|Rocket.Chat|webhook|string|true|true|url||Webhook URL'
  'rocketchat|Rocket.Chat|text|string|false|false|||Custom text'
  'mattermost|Mattermost|webhook|string|true|true|url||Webhook URL'
  'mattermost|Mattermost|title|string|false|false|||Custom title'
  'mattermost|Mattermost|text|string|false|false|||Custom text'
  'opsgenie|Opsgenie|apiKey|string|true|true|||API Key'
  'opsgenie|Opsgenie|title|string|false|false|||Custom title'
  'opsgenie|Opsgenie|text|string|false|false|||Custom text'
  'matrix|Matrix|homeServer|string|true|false|url||HomeServer URL'
  'matrix|Matrix|accessToken|string|true|true|||Access token'
  'matrix|Matrix|internalRoomId|string|true|false|||Room ID'
  'matrix|Matrix|title|string|false|false|||Custom title'
  'matrix|Matrix|text|string|false|false|||Custom text'
  'dingtalk|Dingtalk|accessToken|string|true|true|||Access token'
  'dingtalk|Dingtalk|secret|string|false|true|||Signing secret'
  'dingtalk|Dingtalk|title|string|false|false|||Custom title'
  'feishu|Feishu|webhook|string|true|true|url||Webhook URL'
  'feishu|Feishu|title|string|false|false|||Custom title'
  'zenduty|Zenduty|integrationKey|string|true|true|||Integration Key'
  'zenduty|Zenduty|alertType|string|false|false||critical|Alert type (default: critical)'
  'googlechat|Google Chat|webhook|string|true|true|url||Webhook URL'
  'googlechat|Google Chat|text|string|false|false|||Custom text'
  'gotify|Gotify|url|string|true|false|url||Gotify server URL'
  'gotify|Gotify|token|string|true|true|||App token'
  'gotify|Gotify|priority|integer|false|false|integer||Priority (optional)'
  'gotify|Gotify|title|string|false|false|||Custom title'
  'ntfy|ntfy|topic|string|true|true|||Topic to publish to'
  'ntfy|ntfy|url|string|false|false|url|https://ntfy.sh|Server URL (default: https://ntfy.sh)'
  'ntfy|ntfy|token|string|false|true|||Optional auth token'
  'ntfy|ntfy|title|string|false|false|||Custom title'
  'ntfy|ntfy|priority|integer|false|false|integer|4|Priority 1-5 (default: 4)'
  'pushover|Pushover|token|string|true|true|||Application token'
  'pushover|Pushover|user|string|true|true|||User or group key'
  'pushover|Pushover|priority|integer|false|false|integer||Priority (optional)'
  'pushover|Pushover|title|string|false|false|||Custom title'
  'webex|Webex|accessToken|string|true|true|||Bot access token'
  'webex|Webex|roomId|string|false|false|||Room ID (optional)'
  'webex|Webex|toPersonEmail|string|false|false|||Person email (optional)'
  'github|GitHub|token|string|true|true|||Personal access token'
  'github|GitHub|owner|string|true|false|||Repository owner'
  'github|GitHub|repo|string|true|false|||Repository name'
  'github|GitHub|url|string|false|false|url||Optional endpoint override (e.g. GitHub Enterprise)'
  'gitlab|GitLab|token|string|true|true|||Personal access token'
  'gitlab|GitLab|projectId|string|true|false|||Project ID'
  'gitlab|GitLab|url|string|false|false|url||Optional endpoint override (e.g. self-hosted GitLab)'
  'gitea|Gitea|token|string|true|true|||Access token'
  'gitea|Gitea|owner|string|true|false|||Repository owner'
  'gitea|Gitea|repo|string|true|false|||Repository name'
  'gitea|Gitea|url|string|false|false|url||Optional endpoint override (e.g. self-hosted Gitea)'
  'zapier|Zapier|url|string|true|true|url||Zap webhook URL'
  'zapier|Zapier|token|string|false|true|||Optional token'
  'zapier|Zapier|title|string|false|false|||Custom title'
  'n8n|n8n|url|string|true|true|url||Workflow webhook URL'
  'n8n|n8n|token|string|false|true|||Optional auth header value'
  'n8n|n8n|title|string|false|false|||Custom title'
  'ifttt|IFTTT|key|string|true|true|||Webhooks key'
  'ifttt|IFTTT|event|string|false|false||kwatch|Event name (default: kwatch)'
  'teamsworkflow|Teams Workflow|webhook|string|true|true|url||Power Automate / Teams Workflow URL'
  'zulip|Zulip|email|string|true|false|||Bot email'
  'zulip|Zulip|token|string|true|true|||Bot API key'
  'zulip|Zulip|channel|string|true|false|||Channel/stream to post to'
  'zulip|Zulip|url|string|false|false|url|https://zulip.example.com/api/v1/messages|Server URL (default: https://zulip.example.com/api/v1/messages)'
  'zulip|Zulip|title|string|false|false|||Custom title'
  'homeassistant|Home Assistant|token|string|true|true|||Long-lived access token'
  'homeassistant|Home Assistant|url|string|false|false|url|http://localhost:8123|Server URL (default: http://localhost:8123)'
  'homeassistant|Home Assistant|service|string|false|false||notify|Notification service (default: notify)'
  'splunk|Splunk|url|string|true|false|url||HEC endpoint URL'
  'splunk|Splunk|token|string|true|true|||HEC token'
  'splunk|Splunk|source|string|false|false|||Source name (optional)'
  'splunk|Splunk|sourcetype|string|false|false|||Source type (optional)'
  'splunk|Splunk|index|string|false|false|||Index name (optional)'
  'splunk|Splunk|host|string|false|false|||Host name (optional)'
  'datadog|Datadog|apiKey|string|true|true|||API key'
  'datadog|Datadog|site|string|false|false||datadoghq.com|Datadog site (default: datadoghq.com)'
  'datadog|Datadog|applicationKey|string|false|true|||Optional application key'
  'datadog|Datadog|title|string|false|false|||Custom title'
  'datadog|Datadog|alertType|string|false|false||error|Alert type (default: error)'
  'datadog|Datadog|tags|list|false|false|list||Comma-separated tags'
  'newrelic|New Relic|apiKey|string|true|true|||User API key'
  'newrelic|New Relic|accountId|string|true|false|||Account ID'
  'clickup|ClickUp|token|string|true|true|||Personal API token'
  'clickup|ClickUp|listId|string|true|false|||List ID to create tasks in'
  'clickup|ClickUp|priority|integer|false|false|integer||Optional task priority (1-4)'
  'ilert|iLert|integrationKey|string|true|true|||Integration key'
  'ilert|iLert|priority|integer|false|false|integer||Priority (LOW/HIGH/CRITICAL, default: HIGH)'
  'incidentio|Incident.io|url|string|true|true|url||Incident.io URL'
  'incidentio|Incident.io|apiKey|string|false|true|||Optional API key'
  'squadcast|Squadcast|serviceKey|string|true|true|||Service key'
  'signl4|SIGNL4|teamSecret|string|true|true|||Team secret'
  'signl4|SIGNL4|title|string|false|false|||Custom title'
  'signl4|SIGNL4|user|string|false|false|||Optional alerting user'
  'signl4|SIGNL4|url|string|false|false|url||Optional endpoint override'
  'twilio|Twilio|accountSid|string|true|true|||Account SID'
  'twilio|Twilio|authToken|string|true|true|||Auth token'
  'twilio|Twilio|from|string|true|false|||Sender phone number'
  'twilio|Twilio|to|string|true|false|||Recipient phone number'
  'vonage|Vonage|apiKey|string|true|true|||API key'
  'vonage|Vonage|apiSecret|string|true|true|||API secret'
  'vonage|Vonage|from|string|true|false|||Sender name/number'
  'vonage|Vonage|to|string|true|false|||Recipient phone number'
  'plivo|Plivo|authId|string|true|true|||Auth ID'
  'plivo|Plivo|authToken|string|true|true|||Auth token'
  'plivo|Plivo|from|string|true|false|||Sender number'
  'plivo|Plivo|to|string|true|false|||Recipient phone number'
  'messagebird|MessageBird|accessKey|string|true|true|||Access key'
  'messagebird|MessageBird|from|string|true|false|||Sender number'
  'messagebird|MessageBird|to|string|true|false|||Recipient phone number'
  'signal|Signal|number|string|true|false|||Sender phone number'
  'signal|Signal|to|string|true|false|||Recipient phone number'
  'signal|Signal|url|string|false|false|url|http://localhost:8080|REST API URL (default: http://localhost:8080)'
  'sendgrid|SendGrid|apiKey|string|true|true|||API key'
  'sendgrid|SendGrid|from|string|true|false|||From address'
  'sendgrid|SendGrid|to|list|true|false|list||Recipients (list of addresses)'
  'sendgrid|SendGrid|subject|string|false|false|||Email subject'
  'ses|SES|accessKeyId|string|true|true|||AWS access key ID'
  'ses|SES|secretAccessKey|string|true|true|||AWS secret access key'
  'ses|SES|region|string|false|false||us-east-1|AWS region (default: us-east-1)'
  'ses|SES|from|string|true|false|||Verified sender address'
  'ses|SES|to|string|true|false|||Recipients (comma-separated)'
  'ses|SES|subject|string|false|false|||Email subject'
  'sns|SNS|accessKeyId|string|true|true|||AWS access key ID'
  'sns|SNS|secretAccessKey|string|true|true|||AWS secret access key'
  'sns|SNS|region|string|false|false||us-east-1|AWS region (default: us-east-1)'
  'sns|SNS|topicArn|string|false|false|||SNS topic ARN (or targetArn)'
  'sns|SNS|targetArn|string|false|false|||SNS target ARN (alternative to topicArn).'
  'sns|SNS|subject|string|false|false|||Optional subject (email subscriptions)'
  'jira|Jira|url|string|true|false|url||Jira base URL'
  'jira|Jira|user|string|true|false|||Email or username'
  'jira|Jira|apiToken|string|true|true|||API token'
  'jira|Jira|projectKey|string|true|false|||Project key'
  'jira|Jira|issueType|string|false|false||Task|Issue type (default: Task)'
  'wecom|WeCom|webhook|string|true|true|url||Group robot webhook URL'
  'splunkoncall|Splunk On-Call|apiKey|string|true|true|||API key'
  'splunkoncall|Splunk On-Call|routingKey|string|true|true|||Routing key'
  'splunkoncall|Splunk On-Call|url|string|false|false|url||Optional endpoint override'
  'mailgun|Mailgun|apiKey|string|true|true|||API key'
  'mailgun|Mailgun|domain|string|true|false|||Sending domain'
  'mailgun|Mailgun|from|string|true|false|||From address'
  'mailgun|Mailgun|to|string|true|false|||Recipients (comma-separated)'
  'mailgun|Mailgun|subject|string|false|false|||Email subject'
  'mailgun|Mailgun|url|string|false|false|url||Optional endpoint override (e.g. EU region)'
  'resend|Resend|apiKey|string|true|true|||API key'
  'resend|Resend|from|string|true|false|||From address'
  'resend|Resend|to|string|true|false|||Recipients (comma-separated)'
  'resend|Resend|subject|string|false|false|||Email subject'
  'goalert|GoAlert|url|string|false|false|url|https://goalert.example.com|GoAlert URL (default: https://goalert.example.com)'
  'goalert|GoAlert|token|string|true|true|||API token'
  'goalert|GoAlert|serviceId|string|true|false|||Service ID'
  'alerta|Alerta|url|string|true|false|url||Alerta server URL'
  'alerta|Alerta|apiKey|string|true|true|||API key'
  'alerta|Alerta|environment|string|false|false||Production|Environment (default: Production)'
  'alerta|Alerta|service|string|false|false||kwatch|Service name (default: kwatch)'
  'threema|Threema|gatewayId|string|true|true|||Threema Gateway ID'
  'threema|Threema|secret|string|true|true|||Gateway secret'
  'threema|Threema|to|string|true|false|||Recipient Threema ID'
  'flock|Flock|webhook|string|true|true|url||Incoming webhook URL'
  'pushbullet|Pushbullet|accessToken|string|true|true|||Access token'
  'sensugo|SensiGo|url|string|true|false|url||Sensu Go API URL'
  'sensugo|SensiGo|apiKey|string|true|true|||API key'
  'sensugo|SensiGo|namespace|string|false|false||default|Namespace (default: default)'
  'sensugo|SensiGo|entity|string|false|false||kwatch|Entity name (default: kwatch)'
  'webhook|Generic Webhook|url|string|true|true|url||Webhook URL'
  'webhook|Generic Webhook|headers|headers|false|false|||Custom headers'
  'webhook|Generic Webhook|basicAuth.username|string|false|false|||Basic-auth username.'
  'webhook|Generic Webhook|basicAuth.password|string|false|true|||Basic-auth password.'
  'slack|Slack|routes|json|false|false|json||Optional JSON route filters.'
  'slack|Slack|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'slack|Slack|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'slack|Slack|fallback|string|false|false|||Optional fallback provider name.'
  'discord|Discord|routes|json|false|false|json||Optional JSON route filters.'
  'discord|Discord|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'discord|Discord|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'discord|Discord|fallback|string|false|false|||Optional fallback provider name.'
  'email|Email|routes|json|false|false|json||Optional JSON route filters.'
  'email|Email|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'email|Email|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'email|Email|fallback|string|false|false|||Optional fallback provider name.'
  'line|LINE|routes|json|false|false|json||Optional JSON route filters.'
  'line|LINE|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'line|LINE|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'line|LINE|fallback|string|false|false|||Optional fallback provider name.'
  'pagerduty|PagerDuty|routes|json|false|false|json||Optional JSON route filters.'
  'pagerduty|PagerDuty|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'pagerduty|PagerDuty|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'pagerduty|PagerDuty|fallback|string|false|false|||Optional fallback provider name.'
  'telegram|Telegram|routes|json|false|false|json||Optional JSON route filters.'
  'telegram|Telegram|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'telegram|Telegram|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'telegram|Telegram|fallback|string|false|false|||Optional fallback provider name.'
  'teams|Teams|routes|json|false|false|json||Optional JSON route filters.'
  'teams|Teams|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'teams|Teams|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'teams|Teams|fallback|string|false|false|||Optional fallback provider name.'
  'rocketchat|Rocket.Chat|routes|json|false|false|json||Optional JSON route filters.'
  'rocketchat|Rocket.Chat|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'rocketchat|Rocket.Chat|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'rocketchat|Rocket.Chat|fallback|string|false|false|||Optional fallback provider name.'
  'mattermost|Mattermost|routes|json|false|false|json||Optional JSON route filters.'
  'mattermost|Mattermost|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'mattermost|Mattermost|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'mattermost|Mattermost|fallback|string|false|false|||Optional fallback provider name.'
  'opsgenie|Opsgenie|routes|json|false|false|json||Optional JSON route filters.'
  'opsgenie|Opsgenie|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'opsgenie|Opsgenie|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'opsgenie|Opsgenie|fallback|string|false|false|||Optional fallback provider name.'
  'matrix|Matrix|routes|json|false|false|json||Optional JSON route filters.'
  'matrix|Matrix|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'matrix|Matrix|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'matrix|Matrix|fallback|string|false|false|||Optional fallback provider name.'
  'dingtalk|Dingtalk|routes|json|false|false|json||Optional JSON route filters.'
  'dingtalk|Dingtalk|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'dingtalk|Dingtalk|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'dingtalk|Dingtalk|fallback|string|false|false|||Optional fallback provider name.'
  'feishu|Feishu|routes|json|false|false|json||Optional JSON route filters.'
  'feishu|Feishu|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'feishu|Feishu|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'feishu|Feishu|fallback|string|false|false|||Optional fallback provider name.'
  'zenduty|Zenduty|routes|json|false|false|json||Optional JSON route filters.'
  'zenduty|Zenduty|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'zenduty|Zenduty|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'zenduty|Zenduty|fallback|string|false|false|||Optional fallback provider name.'
  'googlechat|Google Chat|routes|json|false|false|json||Optional JSON route filters.'
  'googlechat|Google Chat|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'googlechat|Google Chat|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'googlechat|Google Chat|fallback|string|false|false|||Optional fallback provider name.'
  'gotify|Gotify|routes|json|false|false|json||Optional JSON route filters.'
  'gotify|Gotify|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'gotify|Gotify|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'gotify|Gotify|fallback|string|false|false|||Optional fallback provider name.'
  'ntfy|ntfy|routes|json|false|false|json||Optional JSON route filters.'
  'ntfy|ntfy|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'ntfy|ntfy|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'ntfy|ntfy|fallback|string|false|false|||Optional fallback provider name.'
  'pushover|Pushover|routes|json|false|false|json||Optional JSON route filters.'
  'pushover|Pushover|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'pushover|Pushover|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'pushover|Pushover|fallback|string|false|false|||Optional fallback provider name.'
  'webex|Webex|routes|json|false|false|json||Optional JSON route filters.'
  'webex|Webex|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'webex|Webex|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'webex|Webex|fallback|string|false|false|||Optional fallback provider name.'
  'github|GitHub|routes|json|false|false|json||Optional JSON route filters.'
  'github|GitHub|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'github|GitHub|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'github|GitHub|fallback|string|false|false|||Optional fallback provider name.'
  'gitlab|GitLab|routes|json|false|false|json||Optional JSON route filters.'
  'gitlab|GitLab|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'gitlab|GitLab|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'gitlab|GitLab|fallback|string|false|false|||Optional fallback provider name.'
  'gitea|Gitea|routes|json|false|false|json||Optional JSON route filters.'
  'gitea|Gitea|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'gitea|Gitea|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'gitea|Gitea|fallback|string|false|false|||Optional fallback provider name.'
  'zapier|Zapier|routes|json|false|false|json||Optional JSON route filters.'
  'zapier|Zapier|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'zapier|Zapier|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'zapier|Zapier|fallback|string|false|false|||Optional fallback provider name.'
  'n8n|n8n|routes|json|false|false|json||Optional JSON route filters.'
  'n8n|n8n|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'n8n|n8n|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'n8n|n8n|fallback|string|false|false|||Optional fallback provider name.'
  'ifttt|IFTTT|routes|json|false|false|json||Optional JSON route filters.'
  'ifttt|IFTTT|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'ifttt|IFTTT|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'ifttt|IFTTT|fallback|string|false|false|||Optional fallback provider name.'
  'teamsworkflow|Teams Workflow|routes|json|false|false|json||Optional JSON route filters.'
  'teamsworkflow|Teams Workflow|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'teamsworkflow|Teams Workflow|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'teamsworkflow|Teams Workflow|fallback|string|false|false|||Optional fallback provider name.'
  'zulip|Zulip|routes|json|false|false|json||Optional JSON route filters.'
  'zulip|Zulip|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'zulip|Zulip|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'zulip|Zulip|fallback|string|false|false|||Optional fallback provider name.'
  'homeassistant|Home Assistant|routes|json|false|false|json||Optional JSON route filters.'
  'homeassistant|Home Assistant|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'homeassistant|Home Assistant|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'homeassistant|Home Assistant|fallback|string|false|false|||Optional fallback provider name.'
  'splunk|Splunk|routes|json|false|false|json||Optional JSON route filters.'
  'splunk|Splunk|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'splunk|Splunk|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'splunk|Splunk|fallback|string|false|false|||Optional fallback provider name.'
  'datadog|Datadog|routes|json|false|false|json||Optional JSON route filters.'
  'datadog|Datadog|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'datadog|Datadog|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'datadog|Datadog|fallback|string|false|false|||Optional fallback provider name.'
  'newrelic|New Relic|routes|json|false|false|json||Optional JSON route filters.'
  'newrelic|New Relic|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'newrelic|New Relic|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'newrelic|New Relic|fallback|string|false|false|||Optional fallback provider name.'
  'clickup|ClickUp|routes|json|false|false|json||Optional JSON route filters.'
  'clickup|ClickUp|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'clickup|ClickUp|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'clickup|ClickUp|fallback|string|false|false|||Optional fallback provider name.'
  'ilert|iLert|routes|json|false|false|json||Optional JSON route filters.'
  'ilert|iLert|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'ilert|iLert|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'ilert|iLert|fallback|string|false|false|||Optional fallback provider name.'
  'incidentio|Incident.io|routes|json|false|false|json||Optional JSON route filters.'
  'incidentio|Incident.io|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'incidentio|Incident.io|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'incidentio|Incident.io|fallback|string|false|false|||Optional fallback provider name.'
  'squadcast|Squadcast|routes|json|false|false|json||Optional JSON route filters.'
  'squadcast|Squadcast|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'squadcast|Squadcast|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'squadcast|Squadcast|fallback|string|false|false|||Optional fallback provider name.'
  'signl4|SIGNL4|routes|json|false|false|json||Optional JSON route filters.'
  'signl4|SIGNL4|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'signl4|SIGNL4|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'signl4|SIGNL4|fallback|string|false|false|||Optional fallback provider name.'
  'twilio|Twilio|routes|json|false|false|json||Optional JSON route filters.'
  'twilio|Twilio|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'twilio|Twilio|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'twilio|Twilio|fallback|string|false|false|||Optional fallback provider name.'
  'vonage|Vonage|routes|json|false|false|json||Optional JSON route filters.'
  'vonage|Vonage|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'vonage|Vonage|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'vonage|Vonage|fallback|string|false|false|||Optional fallback provider name.'
  'plivo|Plivo|routes|json|false|false|json||Optional JSON route filters.'
  'plivo|Plivo|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'plivo|Plivo|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'plivo|Plivo|fallback|string|false|false|||Optional fallback provider name.'
  'messagebird|MessageBird|routes|json|false|false|json||Optional JSON route filters.'
  'messagebird|MessageBird|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'messagebird|MessageBird|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'messagebird|MessageBird|fallback|string|false|false|||Optional fallback provider name.'
  'signal|Signal|routes|json|false|false|json||Optional JSON route filters.'
  'signal|Signal|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'signal|Signal|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'signal|Signal|fallback|string|false|false|||Optional fallback provider name.'
  'sendgrid|SendGrid|routes|json|false|false|json||Optional JSON route filters.'
  'sendgrid|SendGrid|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'sendgrid|SendGrid|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'sendgrid|SendGrid|fallback|string|false|false|||Optional fallback provider name.'
  'ses|SES|routes|json|false|false|json||Optional JSON route filters.'
  'ses|SES|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'ses|SES|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'ses|SES|fallback|string|false|false|||Optional fallback provider name.'
  'sns|SNS|routes|json|false|false|json||Optional JSON route filters.'
  'sns|SNS|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'sns|SNS|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'sns|SNS|fallback|string|false|false|||Optional fallback provider name.'
  'jira|Jira|routes|json|false|false|json||Optional JSON route filters.'
  'jira|Jira|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'jira|Jira|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'jira|Jira|fallback|string|false|false|||Optional fallback provider name.'
  'wecom|WeCom|routes|json|false|false|json||Optional JSON route filters.'
  'wecom|WeCom|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'wecom|WeCom|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'wecom|WeCom|fallback|string|false|false|||Optional fallback provider name.'
  'splunkoncall|Splunk On-Call|routes|json|false|false|json||Optional JSON route filters.'
  'splunkoncall|Splunk On-Call|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'splunkoncall|Splunk On-Call|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'splunkoncall|Splunk On-Call|fallback|string|false|false|||Optional fallback provider name.'
  'mailgun|Mailgun|routes|json|false|false|json||Optional JSON route filters.'
  'mailgun|Mailgun|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'mailgun|Mailgun|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'mailgun|Mailgun|fallback|string|false|false|||Optional fallback provider name.'
  'resend|Resend|routes|json|false|false|json||Optional JSON route filters.'
  'resend|Resend|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'resend|Resend|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'resend|Resend|fallback|string|false|false|||Optional fallback provider name.'
  'goalert|GoAlert|routes|json|false|false|json||Optional JSON route filters.'
  'goalert|GoAlert|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'goalert|GoAlert|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'goalert|GoAlert|fallback|string|false|false|||Optional fallback provider name.'
  'alerta|Alerta|routes|json|false|false|json||Optional JSON route filters.'
  'alerta|Alerta|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'alerta|Alerta|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'alerta|Alerta|fallback|string|false|false|||Optional fallback provider name.'
  'threema|Threema|routes|json|false|false|json||Optional JSON route filters.'
  'threema|Threema|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'threema|Threema|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'threema|Threema|fallback|string|false|false|||Optional fallback provider name.'
  'flock|Flock|routes|json|false|false|json||Optional JSON route filters.'
  'flock|Flock|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'flock|Flock|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'flock|Flock|fallback|string|false|false|||Optional fallback provider name.'
  'pushbullet|Pushbullet|routes|json|false|false|json||Optional JSON route filters.'
  'pushbullet|Pushbullet|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'pushbullet|Pushbullet|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'pushbullet|Pushbullet|fallback|string|false|false|||Optional fallback provider name.'
  'sensugo|SensiGo|routes|json|false|false|json||Optional JSON route filters.'
  'sensugo|SensiGo|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'sensugo|SensiGo|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'sensugo|SensiGo|fallback|string|false|false|||Optional fallback provider name.'
  'webhook|Generic Webhook|routes|json|false|false|json||Optional JSON route filters.'
  'webhook|Generic Webhook|retry.maxAttempts|integer|false|false|integer||Optional maximum retry attempts.'
  'webhook|Generic Webhook|retry.delay|string|false|false|||Optional retry delay, for example 5s.'
  'webhook|Generic Webhook|fallback|string|false|false|||Optional fallback provider name.'
)

# path|type|default|category|description|status|replacement
CATALOG=(
  'workers|integer|1|Performance|Number of Kubernetes work queues processed in parallel.|active|'
  'resyncSeconds|integer|0|Performance|Periodic safety resync interval in seconds; zero keeps event-driven mode.|active|'
  'maxRecentLogLines|integer|50|Alerts|Maximum recent log lines attached to an incident.|active|'
  'containerRestartThreshold|integer|0|Alerts|Alert when a container reaches this cumulative restart count; zero disables it.|active|'
  'includeEvents|boolean|true|Alerts|Include recent Kubernetes events in incident messages.|active|'
  'includeLogs|boolean|true|Alerts|Include recent container logs in incident messages.|active|'
  'namespaces|list|all|Scope|Comma-separated namespaces to watch; leave empty to watch every namespace.|active|'
  'namespaceSelector|string|empty|Scope|Kubernetes label selector used to choose namespaces.|active|'
  'reasons|list|all|Scope|Comma-separated event reasons to allow or exclude with a leading !.|active|'
  'ignoreFailedGracefulShutdown|boolean|true|Noise reduction|Ignore forceful container termination during an intentional shutdown.|active|'
  'ignoreDisruptionTerminations|boolean|true|Noise reduction|Ignore pods being deliberately evicted, preempted, or disrupted.|active|'
  'adaptiveThresholds|boolean|true|Noise reduction|Add bounded grace during normal partial rollouts.|active|'
  'reportStartupBaseline|boolean|true|Noise reduction|Summarize issues that already existed when kwatch started.|active|'
  'correlation.window|integer|10|Incident memory|Minutes in which related signals are correlated.|active|'
  'correlation.lifecycleInterval|integer|1|Incident memory|Minutes between lifecycle and resolution sweeps.|active|'
  'correlation.resolveHoldDown|integer|300|Incident memory|Seconds a signal must stay healthy before resolving.|active|'
  'correlation.cooldownMinutes|integer|10|Incident memory|Minimum minutes before the same incident can notify again.|active|'
  'correlation.maxBaseline|integer|5000|Incident memory|Maximum persisted baseline entries.|active|'
  'correlation.escalation|json|{"enabled":true,"tiers":[3,10]}|Incident memory|JSON object controlling restart-count severity escalation.|active|'
  'correlation.renotify|json|{"maxPerIncident":3}|Incident memory|JSON object controlling periodic re-notification.|active|'
  'severityByOwnerKind|json|{}|Alerts|JSON map overriding severity by workload owner kind.|active|'
  'severityByReason|json|{}|Alerts|JSON map overriding severity by detected reason.|active|'
  'smartGrouping.windowSeconds|integer|60|Noise reduction|Seconds for grouping related failures into one notification.|active|'
  'smartGrouping.namespaceFanOutThreshold|integer|3|Noise reduction|Owners failing alike before a namespace fan-out incident is created.|active|'
  'inhibition.nodeSuppressesPods|boolean|true|Noise reduction|Suppress pod symptoms while their node has an active incident.|active|'
  'nodeMonitor.enabled|boolean|true|Monitors|Watch node readiness and pressure conditions.|active|'
  'nodeMonitor.sustainedMinutes|integer|3|Monitors|Minutes a node condition must persist before alerting.|active|'
  'pvcMonitor.enabled|boolean|true|Monitors|Watch mounted PVC usage and storage pressure.|active|'
  'pvcMonitor.interval|integer|5|Monitors|Minutes between PVC usage checks.|active|'
  'pvcMonitor.threshold|float|80|Monitors|PVC usage percentage that creates a warning.|active|'
  'pvcMonitor.criticalThreshold|float|90|Monitors|PVC usage percentage that creates a high-severity alert.|active|'
  'pvcMonitor.clearThreshold|float|75|Monitors|PVC usage percentage below which an alert resolves.|active|'
  'rolloutMonitor.enabled|boolean|true|Monitors|Watch Deployments for stuck rollouts.|active|'
  'rolloutMonitor.sustainedMinutes|integer|5|Monitors|Minutes a Deployment may remain unavailable before alerting.|active|'
  'statefulSetMonitor.enabled|boolean|true|Monitors|Watch StatefulSets for stuck updates.|active|'
  'statefulSetMonitor.sustainedMinutes|integer|5|Monitors|Minutes a StatefulSet may remain unavailable before alerting.|active|'
  'daemonSetMonitor.enabled|boolean|true|Monitors|Watch DaemonSets for unavailable pods and scheduling failures.|active|'
  'daemonSetMonitor.sustainedMinutes|integer|5|Monitors|Minutes a DaemonSet may remain unavailable before alerting.|active|'
  'jobMonitor.enabled|boolean|true|Monitors|Watch Jobs for failures and deadline problems.|active|'
  'cronJobMonitor.enabled|boolean|true|Monitors|Watch CronJobs for missed or suspended work.|active|'
  'cronJobMonitor.sustainedMinutes|integer|5|Monitors|Minutes a CronJob condition must persist before alerting.|active|'
  'hpaMonitor.enabled|boolean|true|Monitors|Watch HPAs that remain constrained or maxed out.|active|'
  'hpaMonitor.sustainedMinutes|integer|20|Monitors|Minutes an HPA must remain constrained before alerting.|active|'
  'serviceMonitor.enabled|boolean|true|Monitors|Watch Services with no ready backends.|active|'
  'ingressMonitor.enabled|boolean|true|Monitors|Watch Ingress backend availability.|active|'
  'networkPolicyMonitor.enabled|boolean|true|Monitors|Detect evidence of restrictive NetworkPolicies.|active|'
  'admissionWebhookMonitor.enabled|boolean|true|Monitors|Watch admission webhook availability and failures.|active|'
  'controlPlaneMonitor.enabled|boolean|true|Monitors|Watch API server and control-plane health signals.|active|'
  'clusterResourceMonitor.enabled|boolean|true|Monitors|Watch quota, namespace, and lease lifecycle failures.|active|'
  'clusterResourceMonitor.sustainedMinutes|integer|10|Monitors|Minutes a terminating namespace or quota condition must persist before alerting.|active|'
  'clusterResourceMonitor.nodeLeaseStaleSeconds|integer|90|Monitors|Seconds without a node lease renewal before reporting a stale heartbeat.|active|'
  'heartbeatMonitor.enabled|boolean|false|Monitors|Send a periodic external dead-man heartbeat.|active|'
  'heartbeatMonitor.interval|integer|300|Monitors|Seconds between heartbeat notifications.|active|'
  'heartbeatMonitor.url|string|empty|Security|External dead-man heartbeat URL; stored only through a mounted Secret.|secret|'
  'scheduleMonitor.enabled|boolean|true|Monitors|Include scheduling delay and unschedulable diagnostics.|active|'
  'oomMonitor.enabled|boolean|true|Monitors|Track repeating OOM kills independently from current pod state.|active|'
  'oomMonitor.threshold|integer|3|Monitors|OOM kills within the window before raising a repeating-OOM incident.|active|'
  'oomMonitor.windowMinutes|integer|60|Monitors|Sliding window used for repeating OOM detection.|active|'
  'pendingPodMonitor.enabled|boolean|true|Monitors|Watch pods that remain Pending.|active|'
  'pendingPodMonitor.threshold|integer|300|Monitors|Seconds a pod may remain Pending before alerting.|active|'
  'notReadyMonitor.enabled|boolean|true|Monitors|Watch running pods that remain not ready.|active|'
  'pdbMonitor.enabled|boolean|true|Monitors|Watch PodDisruptionBudgets that block voluntary disruption.|active|'
  'pdbMonitor.sustainedMinutes|integer|5|Monitors|Minutes a PDB violation must persist before alerting.|active|'
  'nodeResourceMonitor.enabled|boolean|true|Monitors|Watch node overcommit and filesystem/inode pressure.|active|'
  'nodeResourceMonitor.intervalSeconds|integer|300|Monitors|Seconds between node resource checks.|active|'
  'nodeResourceMonitor.cpuWarning|float|2.0|Monitors|CPU requested-to-capacity ratio that raises a warning.|active|'
  'nodeResourceMonitor.cpuCritical|float|4.0|Monitors|CPU requested-to-capacity ratio that raises a critical alert.|active|'
  'nodeResourceMonitor.memWarning|float|2.0|Monitors|Memory requested-to-capacity ratio that raises a warning.|active|'
  'nodeResourceMonitor.memCritical|float|4.0|Monitors|Memory requested-to-capacity ratio that raises a critical alert.|active|'
  'nodeResourceMonitor.filesystemWarningPercent|float|90|Monitors|Node filesystem usage warning threshold.|active|'
  'nodeResourceMonitor.filesystemCriticalPercent|float|95|Monitors|Node filesystem usage critical threshold.|active|'
  'nodeResourceMonitor.inodeWarningPercent|float|90|Monitors|Node inode usage warning threshold.|active|'
  'nodeResourceMonitor.inodeCriticalPercent|float|95|Monitors|Node inode usage critical threshold.|active|'
  'runtimeMetricsMonitor.enabled|boolean|false|Monitors|Use metrics.k8s.io when available for workload usage diagnostics.|active|'
  'runtimeMetricsMonitor.intervalSeconds|integer|60|Monitors|Seconds between runtime metrics checks.|active|'
  'runtimeMetricsMonitor.memoryWarningPercent|integer|90|Monitors|Memory usage warning percentage when metrics.k8s.io is available.|active|'
  'runtimeMetricsMonitor.memoryCriticalPercent|integer|100|Monitors|Memory usage critical percentage when metrics.k8s.io is available.|active|'
  'runtimeMetricsMonitor.cpuWarningPercent|integer|90|Monitors|CPU usage warning percentage when metrics.k8s.io is available.|active|'
  'runtimeMetricsMonitor.cpuCriticalPercent|integer|100|Monitors|CPU usage critical percentage when metrics.k8s.io is available.|active|'
  'clusterAutoscalerMonitor.enabled|boolean|true|Monitors|Watch built-in cluster-autoscaler evidence from Kubernetes resources and events.|active|'
  'tlsMonitor.threshold|integer|30|Monitors|Days before certificate expiry to warn.|active|'
  'tlsMonitor.criticalThreshold|integer|3|Monitors|Days before certificate expiry for a high-severity alert.|active|'
  'controlPlaneMonitor.intervalSeconds|integer|30|Monitors|Seconds between API and control-plane health checks.|active|'
  'controlPlaneMonitor.apiServerLatencyWarningMs|integer|1000|Monitors|API readyz latency warning threshold in milliseconds.|active|'
  'controlPlaneMonitor.failureThreshold|integer|2|Monitors|Consecutive control-plane failures before alerting.|active|'
  'controlPlaneMonitor.recoveryThreshold|integer|2|Monitors|Consecutive successful checks before resolving.|active|'
  'kubeletTelemetryMonitor.enabled|boolean|true|Monitors|Read built-in kubelet telemetry without an agent.|active|'
  'kubeletTelemetryMonitor.intervalSeconds|integer|60|Monitors|Seconds between built-in kubelet telemetry sweeps.|active|'
  'kubeletTelemetryMonitor.persistState|boolean|true|Monitors|Persist telemetry counters across restarts.|active|'
  'kubeletTelemetryMonitor.failureThreshold|integer|2|Monitors|Consecutive kubelet telemetry failures before alerting.|active|'
  'kubeletTelemetryMonitor.recoveryThreshold|integer|2|Monitors|Consecutive successful telemetry checks before resolving.|active|'
  'kubeletTelemetryMonitor.memoryWarningPercent|float|90|Monitors|Kubelet memory usage warning threshold.|active|'
  'kubeletTelemetryMonitor.memoryCriticalPercent|float|100|Monitors|Kubelet memory usage critical threshold.|active|'
  'kubeletTelemetryMonitor.ephemeralStorageWarningPercent|float|90|Monitors|Ephemeral-storage usage warning threshold.|active|'
  'kubeletTelemetryMonitor.ephemeralStorageCriticalPercent|float|95|Monitors|Ephemeral-storage usage critical threshold.|active|'
  'kubeletTelemetryMonitor.cpuWarningPercent|float|90|Monitors|CPU usage warning threshold from kubelet telemetry.|active|'
  'kubeletTelemetryMonitor.cpuCriticalPercent|float|100|Monitors|CPU usage critical threshold from kubelet telemetry.|active|'
  'kubeletTelemetryMonitor.cpuThrottlingWarningPercent|float|25|Monitors|CPU throttling warning threshold.|active|'
  'kubeletTelemetryMonitor.cpuThrottlingCriticalPercent|float|50|Monitors|CPU throttling critical threshold.|active|'
  'kubeletTelemetryMonitor.psiWarningPercent|float|20|Monitors|Pressure stall warning threshold.|active|'
  'kubeletTelemetryMonitor.psiCriticalPercent|float|50|Monitors|Pressure stall critical threshold.|active|'
  'kubeletTelemetryMonitor.networkErrorRateWarning|float|1|Monitors|Network error rate warning threshold.|active|'
  'kubeletTelemetryMonitor.networkErrorRateCritical|float|10|Monitors|Network error rate critical threshold.|active|'
  'kubeletTelemetryMonitor.runtimeErrorRateWarning|float|1|Monitors|Container runtime error rate warning threshold.|active|'
  'kubeletTelemetryMonitor.runtimeErrorRateCritical|float|10|Monitors|Container runtime error rate critical threshold.|active|'
  'tlsMonitor.enabled|boolean|false|Monitors|Watch TLS certificates before expiry; reads certificate Secrets.|active|'
  'activeProbeMonitor.enabled|boolean|false|Monitors|Run explicitly configured application probes.|active|'
  'activeProbeMonitor.intervalSeconds|integer|30|Monitors|Seconds between active probe rounds.|active|'
  'activeProbeMonitor.timeoutSeconds|integer|5|Monitors|Timeout for each active probe.|active|'
  'activeProbeMonitor.failureThreshold|integer|3|Monitors|Consecutive probe failures before alerting.|active|'
  'activeProbeMonitor.recoveryThreshold|integer|2|Monitors|Consecutive successes before resolving a probe incident.|active|'
  'activeProbeMonitor.autoServices|boolean|false|Monitors|Probe discoverable Service ports automatically; opt in to avoid unexpected traffic.|active|'
  'activeProbeMonitor.http|json|[]|Monitors|JSON array of HTTP probe targets with optional paths, headers, and latency limits.|active|'
  'activeProbeMonitor.tcp|json|[]|Monitors|JSON array of TCP probe targets.|active|'
  'activeProbeMonitor.dns|json|[]|Monitors|JSON array of DNS probe targets.|active|'
  'upgrader.disableUpdateCheck|boolean|false|Operations|Disable the update notification.|active|'
  'telemetry.enabled|boolean|true|Operations|Send the adoption heartbeat.|active|'
  'maintenance.enabled|boolean|true|Operations|Honor maintenance annotations while preserving cluster-level alerts.|active|'
  'maintenance.annotation|string|kwatch.io/maintenance|Operations|Annotation that marks deliberate maintenance on a resource.|active|'
  'maintenance.untilAnnotation|string|kwatch.io/maintenance-until|Operations|Optional annotation containing the maintenance expiry timestamp.|active|'
  'healthCheck.diagnostics|boolean|false|Operations|Expose diagnostic endpoints such as incidents and test-alert.|active|'
  'healthCheck.diagnosticsToken|string|empty|Security|Bearer token for diagnostic endpoints; stored only through a mounted Secret.|secret|'
  'healthCheck.pprof|boolean|false|Operations|Expose Go profiling endpoints; keep disabled in production.|active|'
  'app.clusterName|string|empty|Operations|Cluster name shown in notifications.|active|'
  'app.proxyURL|string|empty|Operations|Optional proxy for outbound provider requests.|active|'
  'app.disableStartupMessage|boolean|false|Operations|Disable the startup notification.|active|'
  'app.logFormatter|string|text|Operations|Log output format: text or json.|active|'
  'app.insecureSkipTLSVerify|boolean|false|Security|Skip TLS verification for outbound providers; strongly discouraged.|active|'
  'app.caBundlePath|string|empty|Security|Path to a mounted PEM bundle for outbound provider TLS.|active|'
  'healthCheck.enabled|boolean|true|Operations|Expose the built-in health endpoint.|active|'
  'healthCheck.port|integer|8060|Operations|Port for health and optional diagnostic endpoints.|active|'
  'crd.enabled|boolean|true|Operations|Watch KwatchConfig and supported CRD status conditions; restart kwatch when configuration changes; enabled by the interactive installer after installing the CRD.|active|'
  'crd.failureConditions|list|empty|Operations|Additional CRD condition rules such as Ready=False or Degraded=True.|active|'
  'crd.graphReferences|list|empty|Operations|Optional CRD references used by dependency and impact analysis.|active|'
  'auditLog.enabled|boolean|true|Operations|Write structured incident lifecycle records to the configured audit sink.|active|'
  'auditLog.output|string|stdout|Operations|Audit output: stdout or a supported output sink.|active|'
  'templates|json|{}|Operations|JSON map of optional reason-specific message templates.|active|'
  'runbooks|json|{}|Operations|JSON map of reason-to-runbook URLs.|active|'
  'silences|json|[]|Noise reduction|JSON array of scoped silence rules.|active|'
  'ignoreContainerNames|list|legacy|Compatibility|Legacy container suppression field.|deprecated|silences'
  'ignorePodNames|list|legacy|Compatibility|Legacy pod-name suppression field.|deprecated|silences'
  'ignoreLogPatterns|list|legacy|Compatibility|Legacy log suppression field.|deprecated|silences'
  'ignoreContainerMessages|list|legacy|Compatibility|Legacy container-message suppression field.|deprecated|silences'
  'ignoreNodeReasons|list|legacy|Compatibility|Legacy node-reason suppression field.|deprecated|silences'
  'ignoreNodeMessages|list|legacy|Compatibility|Legacy node-message suppression field.|deprecated|silences'
)

die() { echo "Error: $*" >&2; exit 1; }
need() { type -P "$1" >/dev/null 2>&1 || die "'$1' is required"; }
require_tools() { need kubectl; need curl; }
ask() {
  local prompt="$1" default="${2:-}" answer
  [ -n "$default" ] && prompt="$prompt [$default]"
  printf '%s: ' "$prompt" >&2
  IFS= read -r answer
  printf '%s' "${answer:-$default}"
}
ask_secret() {
  local prompt="$1" answer
  printf '%s: ' "$prompt" >&2
  IFS= read -r -s answer
  printf '\n' >&2
  printf '%s' "$answer"
}
valid_name() { [[ "$1" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; }
valid_kubernetes_name() { [ "${#1}" -le 40 ] && valid_name "$1"; }
valid_release_version() { [[ "$1" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; }

is_transient_kubectl_error() {
  case "$1" in
    *[Tt]imeout*|*[Uu]navailable*|*"connection refused"*|*"connection reset"*|*"too many requests"*|*"rate limit"*|*"embedded etcd"*|*"leader changed"*) return 0 ;;
  esac
  return 1
}

kubectl() {
  local attempt=1 output rc retryable=true
  [ -t 0 ] || retryable=false
  while [ "$attempt" -le "$MAX_KUBECTL_ATTEMPTS" ]; do
    if output=$(command kubectl --context "$SELECTED_CONTEXT" "$@" 2>&1); then
      printf '%s\n' "$output"
      return 0
    fi
    rc=$?
    printf '%s\n' "$output" >&2
    if ! is_transient_kubectl_error "$output" || [ "$attempt" = "$MAX_KUBECTL_ATTEMPTS" ] || [ "$retryable" = false ]; then
      return "$rc"
    fi
    echo "Temporary Kubernetes error; retrying ($((attempt + 1))/$MAX_KUBECTL_ATTEMPTS)..." >&2
    sleep $((attempt * 2))
    attempt=$((attempt + 1))
  done
  return 1
}

select_context() {
  local current choice index context server
  local -a contexts=()
  while IFS= read -r context; do
    [ -n "$context" ] && contexts+=("$context")
  done < <(command kubectl config get-contexts -o name 2>/dev/null || true)
  [ "${#contexts[@]}" -gt 0 ] || die "no Kubernetes contexts found in kubeconfig"
  current=$(command kubectl config current-context 2>/dev/null || true)

  if [ "${#contexts[@]}" -eq 1 ]; then
    SELECTED_CONTEXT="${contexts[0]}"
  else
    [ -t 0 ] || die "multiple Kubernetes contexts found; an interactive terminal is required to choose one"
    echo >&2
    echo "Select the Kubernetes cluster to manage:" >&2
    for index in "${!contexts[@]}"; do
      if [ "${contexts[$index]}" = "$current" ]; then
        echo "  $((index + 1))) ${contexts[$index]} (current)" >&2
      else
        echo "  $((index + 1))) ${contexts[$index]}" >&2
      fi
    done
    choice=$(ask "Cluster number" "")
    [[ "$choice" =~ ^[0-9]+$ ]] || die "choose a cluster number"
    [ "$choice" -ge 1 ] && [ "$choice" -le "${#contexts[@]}" ] || die "cluster choice is out of range"
    SELECTED_CONTEXT="${contexts[$((choice - 1))]}"
  fi

  server=$(command kubectl --context "$SELECTED_CONTEXT" config view --minify \
    -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)
  [ -n "$server" ] || die "could not read the Kubernetes server for context '$SELECTED_CONTEXT'"
  echo "Selected cluster: $SELECTED_CONTEXT" >&2
  echo "Kubernetes server: $server" >&2
}

catalog_entry() {
  local wanted="$1" entry path type default category description status replacement
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$path" = "$wanted" ] && { printf '%s\n' "$entry"; return; }
  done
}

load_catalog_file() {
  local file="$1" entry path type default category description status replacement
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ config\ catalog\ v([0-9]+)$ ]]; then
      CATALOG_VERSION="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ -n "$path" ] && [ -n "$type" ] && [ -n "$category" ] && [ -n "$description" ] || return 1
    loaded+=("$entry")
  done < "$file"
  [ "${#loaded[@]}" -gt 0 ] || return 1
  CATALOG=("${loaded[@]}")
}

cache_catalog() {
  local file="$1"
  kubectl -n "$NAMESPACE" create configmap "$CATALOG_CACHE_NAME" \
    --from-file=catalog.tsv="$file" \
    --from-literal=source="$CATALOG_SOURCE" \
    --from-literal=updated-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

load_catalog_for_version() {
  local version="${1:-}" tmp cached
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      "$BASE_URL/$version/deploy/config-catalog.tsv" -o "$tmp" 2>/dev/null \
      && load_catalog_file "$tmp"; then
    CATALOG_SOURCE="release:$version"
    cache_catalog "$tmp"
    return 0
  fi
  cached=$(kubectl -n "$NAMESPACE" get configmap "$CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.catalog\.tsv}' 2>/dev/null || true)
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" > "$tmp"
    if load_catalog_file "$tmp"; then
      CATALOG_SOURCE="cache"
      return 0
    fi
  fi
  return 1
}

load_feature_catalog_file() {
  local file="$1" entry id lifecycle description dependencies
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ feature\ catalog\ v([0-9]+)$ ]]; then
      FEATURE_CATALOG_VERSION="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    [ -n "$id" ] && \
      [ "$lifecycle" = startup -o "$lifecycle" = runtime ] && \
      [ -n "$description" ] || return 1
    loaded+=("$entry")
  done < "$file"
  [ "${#loaded[@]}" -gt 0 ] || return 1
  FEATURE_CATALOG=("${loaded[@]}")
}

cache_feature_catalog() {
  local file="$1"
  kubectl -n "$NAMESPACE" create configmap "$FEATURE_CATALOG_CACHE_NAME" \
    --from-file=features.tsv="$file" \
    --from-literal=source="$FEATURE_CATALOG_SOURCE" \
    --from-literal=updated-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

load_feature_catalog_for_version() {
  local version="${1:-}" tmp cached
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      "$BASE_URL/$version/deploy/feature-catalog.tsv" -o "$tmp" 2>/dev/null \
      && load_feature_catalog_file "$tmp"; then
    FEATURE_CATALOG_SOURCE="release:$version"
    cache_feature_catalog "$tmp"
    return 0
  fi
  cached=$(kubectl -n "$NAMESPACE" get configmap "$FEATURE_CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.features\.tsv}' 2>/dev/null || true)
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" > "$tmp"
    if load_feature_catalog_file "$tmp"; then
      FEATURE_CATALOG_SOURCE="cache"
      return 0
    fi
  fi
  return 1
}

load_provider_catalog_file() {
  local file="$1" entry provider display field type required secret validation default description
  local -a loaded=()
  while IFS= read -r entry || [ -n "$entry" ]; do
    if [[ "$entry" =~ ^#\ kwatch\ provider\ catalog\ v([0-9]+)$ ]]; then
      PROVIDER_CATALOG_VERSION="${BASH_REMATCH[1]}"
      continue
    fi
    [[ -z "$entry" || "$entry" = \#* ]] && continue
    IFS='|' read -r provider display field type required secret validation default description <<<"$entry"
    [ -n "$provider" ] && [ -n "$display" ] && [ -n "$field" ] && \
      case "$type" in
        string|integer|boolean|list|json|headers) ;;
        *) return 1 ;;
      esac
    [ -n "$provider" ] && [ -n "$display" ] && [ -n "$field" ] && \
      { [ "$required" = true ] || [ "$required" = false ]; } && \
      { [ "$secret" = true ] || [ "$secret" = false ]; } && \
      [ -n "$description" ] || return 1
    loaded+=("$entry")
  done < "$file"
  [ "${#loaded[@]}" -gt 0 ] || return 1
  PROVIDER_CATALOG=("${loaded[@]}")
}

cache_provider_catalog() {
  local file="$1"
  kubectl -n "$NAMESPACE" create configmap "$PROVIDER_CATALOG_CACHE_NAME" \
    --from-file=providers.tsv="$file" \
    --from-literal=source="$PROVIDER_CATALOG_SOURCE" \
    --from-literal=updated-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

load_provider_catalog_for_version() {
  local version="${1:-}" tmp cached
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  if [ -n "$version" ] && curl -fsSL --location --retry 2 --retry-delay 1 --connect-timeout 8 \
      "$BASE_URL/$version/deploy/provider-catalog.tsv" -o "$tmp" 2>/dev/null \
      && load_provider_catalog_file "$tmp"; then
    PROVIDER_CATALOG_SOURCE="release:$version"
    cache_provider_catalog "$tmp"
    return 0
  fi
  cached=$(kubectl -n "$NAMESPACE" get configmap "$PROVIDER_CATALOG_CACHE_NAME" \
    -o jsonpath='{.data.providers\.tsv}' 2>/dev/null || true)
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached" > "$tmp"
    if load_provider_catalog_file "$tmp"; then
      PROVIDER_CATALOG_SOURCE="cache"
      return 0
    fi
  fi
  return 1
}

BACKUP_NAME=""
backup_config() {
  local spec timestamp
  spec=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" -o jsonpath='{.spec}')
  timestamp=$(date -u +%Y%m%d%H%M%S)
  BACKUP_NAME="${RELEASE}-config-$timestamp"
  kubectl -n "$NAMESPACE" create secret generic "$BACKUP_NAME" \
    --from-literal=spec.json="$spec" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

restore_backup() {
  local encoded spec deployment
  [ -n "$BACKUP_NAME" ] || return 0
  encoded=$(kubectl -n "$NAMESPACE" get secret "$BACKUP_NAME" -o jsonpath='{.data.spec\.json}')
  if spec=$(printf '%s' "$encoded" | base64 -d 2>/dev/null); then
    :
  else
    spec=$(printf '%s' "$encoded" | base64 -D)
  fi
  [ -n "$spec" ] || die "backup is empty; refusing to restore it"
  kubectl -n "$NAMESPACE" apply -f - <<EOF >/dev/null
apiVersion: kwatch.abahmed.dev/v1alpha1
kind: KwatchConfig
metadata:
  name: $RELEASE
  namespace: $NAMESPACE
spec: $spec
EOF
  deployment=$(deployment_name)
  [ -n "$deployment" ] || return 0
  kubectl -n "$NAMESPACE" rollout restart "deployment/$deployment" >/dev/null
  kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=5m >/dev/null
}

config_value() {
  local path="$1"
  kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o "jsonpath={.spec.$path}" 2>/dev/null || true
}

ensure_config_resource() {
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
      "kwatch.dev/config-schema=$CATALOG_VERSION" --overwrite >/dev/null
    return 0
  fi
  kubectl -n "$NAMESPACE" apply -f - <<EOF >/dev/null
apiVersion: kwatch.abahmed.dev/v1alpha1
kind: KwatchConfig
metadata:
  name: $RELEASE
  namespace: $NAMESPACE
  labels:
    kwatch.dev/config-schema: "$CATALOG_VERSION"
spec:
  crd:
    enabled: true
EOF
}

ensure_crd() {
  local version="${1:-}" tmp
  if [ -z "$version" ] && kubectl get crd kwatchconfigs.kwatch.abahmed.dev >/dev/null 2>&1; then
    return 0
  fi
  if [ -z "$version" ]; then
    version=$(latest_version) || die "could not determine kwatch version from GitHub"
  fi
  valid_release_version "$version" || die "invalid kwatch release version: $version"
  tmp=$(mktemp)
  trap 'if [ -n "${tmp:-}" ]; then rm -f "$tmp"; fi' RETURN
  curl -fsSL --location --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/crd.yaml" -o "$tmp" || die "could not download the CRD for $version"
  grep -q '^kind: CustomResourceDefinition$' "$tmp" || die "downloaded CRD for $version is invalid"
  kubectl apply --server-side --field-manager=kwatch-manager -f "$tmp" >/dev/null
  kubectl wait --for=condition=Established \
    crd/kwatchconfigs.kwatch.abahmed.dev --timeout=60s >/dev/null
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\r//g; s/\n/\\n/g'
}

json_array() {
  local raw="$1" item first=true
  if [ -z "$raw" ] || [ "$raw" = all ] || [ "$raw" = empty ]; then
    printf '[]'
    return
  fi
  printf '['
  IFS=',' read -ra items <<<"$raw"
  for item in "${items[@]}"; do
    item="${item#${item%%[![:space:]]*}}"
    item="${item%${item##*[![:space:]]}}"
    [ -n "$item" ] || continue
    [ "$first" = true ] || printf ','
    printf '"%s"' "$(json_escape "$item")"
    first=false
  done
  printf ']'
}

write_provider_value() {
  local file="$1" field="$2" type="$3" value="$4"
  local key parent child yaml_value
  case "$type" in
    boolean)
      [[ "$value" = true || "$value" = false ]] ||
        die "$field must be true or false"
      yaml_value="$value"
      ;;
    integer)
      [[ "$value" =~ ^[0-9]+$ ]] ||
        die "$field must be a non-negative integer"
      yaml_value="$value"
      ;;
    list)
      yaml_value=$(json_array "$value")
      ;;
    json)
      [ -n "$value" ] || die "$field cannot be empty"
      yaml_value="$value"
      ;;
    *)
      yaml_value="\"$(json_escape "$value")\""
      ;;
  esac
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: %s\n' "$child" "$yaml_value" >>"$file"
    return
  fi
  printf '    %s: %s\n' "$field" "$yaml_value" >>"$file"
}

write_provider_secret() {
  local file="$1" field="$2" value="$3" tmp_dir="$4"
  local secret_key value_file
  case "$value" in
    *$'\n'*|*$'\r'*) die "$field must be one line" ;;
  esac
  secret_key="${PROVIDER}-${field//./-}"
  value_file="$tmp_dir/$secret_key"
  printf '%s' "$value" >"$value_file"
  chmod 600 "$value_file"
  SECRET_ARGS+=(--from-file="$secret_key=$value_file")
  if [[ "$field" == *.* ]]; then
    local parent="${field%%.*}" child="${field#*.}" key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: "${file:%s/%s}"\n' \
      "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
    return
  fi
  printf '    %s: "${file:%s/%s}"\n' \
    "$field" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

write_config_secret_value() {
  local file="$1" path="$2" value="$3" tmp_dir="$4"
  local secret_key value_file parent child key
  case "$value" in
    *$'\n'*|*$'\r'*) die "$path must be one line" ;;
  esac
  if [ "$path" = heartbeatMonitor.url ] &&
    [[ ! "$value" =~ ^https?:// ]]; then
    die "heartbeatMonitor.url must be an http or https URL"
  fi
  secret_key="${RELEASE}-config-${path//./-}"
  value_file="$tmp_dir/$secret_key"
  printf '%s' "$value" >"$value_file"
  chmod 600 "$value_file"
  SECRET_ARGS+=(--from-file="$secret_key=$value_file")
  if [[ "$path" == *.* ]]; then
    parent="${path%%.*}"
    child="${path#*.}"
    key="|$parent|"
    case "$WRITTEN_CONFIG_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '%s:\n' "    $parent" >>"$file"
        WRITTEN_CONFIG_SECTIONS="${WRITTEN_CONFIG_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: "${file:%s/%s}"\n' \
      "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
    return
  fi
  printf '    %s: "${file:%s/%s}"\n' \
    "$path" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

secret_data_base64() {
  local secret_name="$1" key="$2"
  kubectl -n "$NAMESPACE" get secret "$secret_name" \
    -o "go-template={{index .data \"$key\"}}" 2>/dev/null || true
}

decode_base64_file() {
  local encoded="$1" file="$2"
  printf '%s' "$encoded" | base64 --decode >"$file" 2>/dev/null ||
    printf '%s' "$encoded" | base64 -d >"$file" 2>/dev/null ||
    printf '%s' "$encoded" | base64 -D >"$file"
}

preserve_secret_file() {
  local key="$1" tmp_dir="$2" encoded value_file
  encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" "$key")
  [ -n "$encoded" ] || return 1
  value_file="$tmp_dir/$key"
  decode_base64_file "$encoded" "$value_file" || return 1
  chmod 600 "$value_file"
  SECRET_ARGS+=(--from-file="$key=$value_file")
}

preserve_provider_secret() {
  local file="$1" provider="$2" field="$3" tmp_dir="$4"
  local secret_key key parent child
  secret_key="${provider}-${field//./-}"
  preserve_secret_file "$secret_key" "$tmp_dir" || return 1
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s: "${file:%s/%s}"\n' \
      "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
    return 0
  fi
  printf '    %s: "${file:%s/%s}"\n' \
    "$field" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

preserve_config_secret() {
  local file="$1" path="$2" tmp_dir="$3"
  local secret_key parent child key
  secret_key="${RELEASE}-config-${path//./-}"
  preserve_secret_file "$secret_key" "$tmp_dir" || return 1
  parent="${path%%.*}"
  child="${path#*.}"
  key="|$parent|"
  case "$WRITTEN_CONFIG_SECTIONS" in
    *"$key"*) ;;
    *)
      printf '    %s:\n' "$parent" >>"$file"
      WRITTEN_CONFIG_SECTIONS="${WRITTEN_CONFIG_SECTIONS}${parent}|"
      ;;
  esac
  printf '      %s: "${file:%s/%s}"\n' \
    "$child" "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
}

old_provider_field_block() {
  local provider="$1" field="$2" old_file="$3"
  local parent child
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    awk -v provider="  $provider:" -v parent="    $parent:" \
      -v child="      $child:" '
      $0 == provider { in_provider=1; next }
      in_provider && $0 ~ /^  [^ ]/ { exit }
      in_provider && $0 == parent { in_parent=1; next }
      in_parent && $0 ~ /^    [^ ]/ { in_parent=0 }
      in_parent && index($0, child) == 1 { print; exit }
    ' "$old_file"
    return
  fi
  awk -v provider="  $provider:" -v field="    $field:" '
    $0 == provider { in_provider=1; next }
    in_provider && $0 ~ /^  [^ ]/ { exit }
    in_provider && index($0, field) == 1 { print; exit }
  ' "$old_file"
}

old_provider_section() {
  local provider="$1" field="$2" old_file="$3"
  awk -v provider="  $provider:" -v field="    $field:" '
    $0 == provider { in_provider=1; next }
    in_provider && $0 ~ /^  [^ ]/ { exit }
    in_provider && index($0, field) == 1 { in_field=1 }
    in_field && $0 ~ /^    [^ ]/ && index($0, field) != 1 { exit }
    in_field { print }
  ' "$old_file"
}

preserve_provider_optional() {
  local file="$1" provider="$2" field="$3" type="$4" tmp_dir="$5"
  local block ref key parent child section_key
  [ -s "${OLD_CONFIG_PATH:-}" ] || return 1
  if [ "$type" = headers ]; then
    block=$(old_provider_section "$provider" "$field" "$OLD_CONFIG_PATH")
    [ -n "$block" ] || return 1
    while IFS= read -r ref; do
      key="${ref##*/}"
      key="${key%\}}"
      [ -n "$key" ] || continue
      preserve_secret_file "$key" "$tmp_dir" || return 1
    done < <(printf '%s\n' "$block" | grep -o '\${file:[^}]*}' || true)
    printf '%s\n' "$block" >>"$file"
    return 0
  fi
  block=$(old_provider_field_block "$provider" "$field" "$OLD_CONFIG_PATH")
  [ -n "$block" ] || return 1
  if [[ "$field" == *.* ]]; then
    parent="${field%%.*}"
    child="${field#*.}"
    section_key="|$parent|"
    case "$WRITTEN_PROVIDER_SECTIONS" in
      *"$section_key"*) ;;
      *)
        printf '    %s:\n' "$parent" >>"$file"
        WRITTEN_PROVIDER_SECTIONS="${WRITTEN_PROVIDER_SECTIONS}${parent}|"
        ;;
    esac
    printf '      %s\n' "${block#*      }" >>"$file"
    return 0
  fi
  printf '%s\n' "$block" >>"$file"
}

write_webhook_headers() {
  local file="$1" tmp_dir="$2" count name value i secret_key value_file
  count=$(ask "Number of custom webhook headers" "0")
  [[ "$count" =~ ^[0-9]+$ ]] || die "header count must be a non-negative integer"
  [ "$count" -gt 0 ] || return 0
  printf '    headers:\n' >>"$file"
  for ((i = 1; i <= count; i++)); do
    name=$(ask "Header $i name")
    [ -n "$name" ] || die "header name cannot be empty"
    value=$(ask_secret "Header $i value")
    [ -n "$value" ] || die "header value cannot be empty"
    case "$value" in
      *$'\n'*|*$'\r'*) die "header value must be one line" ;;
    esac
    secret_key="${PROVIDER}-header-${i}"
    value_file="$tmp_dir/$secret_key"
    printf '%s' "$value" >"$value_file"
    chmod 600 "$value_file"
    SECRET_ARGS+=(--from-file="$secret_key=$value_file")
    printf '      - name: "%s"\n' "$(json_escape "$name")" >>"$file"
    printf '        value: "${file:%s/%s}"\n' \
      "$CONFIG_MOUNT_PATH" "$secret_key" >>"$file"
  done
}

patch_config_value() {
  local path="$1" type="$2" value="$3" top field json_value
  if [[ "$path" == *.* ]]; then
    top="${path%%.*}"
    field="${path#*.}"
    case "$type" in
      boolean) [[ "$value" = true || "$value" = false ]] || die "value must be true or false"; json_value="$value" ;;
      integer) [[ "$value" =~ ^[0-9]+$ ]] || die "value must be a non-negative integer"; json_value="$value" ;;
      float) [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "value must be a non-negative number"; json_value="$value" ;;
      list) json_value="$(json_array "$value")" ;;
      json) json_value="$value" ;;
      *) json_value="\"$(json_escape "$value")\"" ;;
    esac
    kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
      -p "{\"spec\":{\"$top\":{\"$field\":$json_value}}}" >/dev/null
  else
    case "$type" in
      boolean) [[ "$value" = true || "$value" = false ]] || die "value must be true or false"; json_value="$value" ;;
      integer) [[ "$value" =~ ^[0-9]+$ ]] || die "value must be a non-negative integer"; json_value="$value" ;;
      float) [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "value must be a non-negative number"; json_value="$value" ;;
      list) json_value="$(json_array "$value")" ;;
      json) json_value="$value" ;;
      *) json_value="\"$(json_escape "$value")\"" ;;
    esac
    kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
      -p "{\"spec\":{\"$path\":$json_value}}" >/dev/null
  fi
}

verify_runtime_tls_access() {
  local deployment service_account subject result verb
  deployment=$(deployment_name)
  if [ -z "$deployment" ]; then
    echo "Cannot verify TLS access: kwatch deployment was not found." >&2
    return 1
  fi
  service_account=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.serviceAccountName}' 2>/dev/null || true)
  [ -n "$service_account" ] || service_account=default
  subject="system:serviceaccount:$NAMESPACE:$service_account"
  for verb in get list watch; do
    result=$(kubectl auth can-i "$verb" secrets --all-namespaces --as="$subject" 2>/dev/null || true)
    case "$result" in
      yes) ;;
      no)
        echo "TLS monitoring needs the kwatch ServiceAccount to $verb Secrets; RBAC is missing." >&2
        return 1
        ;;
      *) echo "Warning: could not verify TLS RBAC ($verb Secrets as $subject). TLS monitoring may stay unavailable." >&2 ;;
    esac
  done
}

enable_initial_tls_monitor() {
  [ "${TLS_MONITOR_ENABLED:-false}" = true ] || return 0
  kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
    -p '{"spec":{"tlsMonitor":{"enabled":true}}}' >/dev/null || \
    { echo "Could not enable TLS monitoring in KwatchConfig." >&2; return 1; }
  verify_runtime_tls_access
}

show_catalog_entry() {
  local entry="$1" path type default category description status replacement current
  IFS='|' read -r path type default category description status replacement <<<"$entry"
  current=$(config_value "$path")
  [ -n "$current" ] || current="default ($default)"
  echo
  echo "$path"
  echo "  $description"
  echo "  Type: $type | Current: $current | Default: $default"
  if [ "$status" = deprecated ]; then
    echo "  Deprecated: use $replacement instead."
  fi
}

migration_notice() {
  local schema entry path type default category description status replacement current
  schema=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o 'jsonpath={.metadata.labels.kwatch\.dev/config-schema}' 2>/dev/null || true)
  if [ -n "$schema" ] && [ "$schema" -lt "$CATALOG_VERSION" ] 2>/dev/null; then
    echo "Configuration schema $schema is older than this manager's schema $CATALOG_VERSION." >&2
    echo "New settings will use their documented defaults; existing settings are preserved." >&2
  fi
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = deprecated ] || continue
    current=$(config_value "$path")
    [ -n "$current" ] && echo "Deprecated config detected: $path (use $replacement)" >&2
  done
}

migrate_legacy_silences() {
  local marker values item field rule_key first
  marker=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/legacy-silences-migrated}' 2>/dev/null || true)
  [ "$marker" = "$CATALOG_VERSION" ] && return 0

  for field in ignoreContainerNames ignorePodNames ignoreLogPatterns ignoreContainerMessages ignoreNodeReasons ignoreNodeMessages; do
    case "$field" in
      ignoreContainerNames) rule_key=containerNames ;;
      ignorePodNames) rule_key=podNamePatterns ;;
      ignoreLogPatterns) rule_key=logPatterns ;;
      ignoreContainerMessages) rule_key=containerMessages ;;
      ignoreNodeReasons) rule_key=nodeReasons ;;
      ignoreNodeMessages) rule_key=nodeMessages ;;
    esac
    values=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
      -o "jsonpath={range .spec.$field[*]}{.}{\"\\n\"}{end}" 2>/dev/null || true)
    [ -n "$values" ] || continue
    first=$(kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" \
      -o 'jsonpath={.spec.silences}' 2>/dev/null || true)
    if [ -z "$first" ]; then
      kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type merge \
        -p '{"spec":{"silences":[]}}' >/dev/null
    fi
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type=json \
        -p "[{\"op\":\"add\",\"path\":\"/spec/silences/-\",\"value\":{\"$rule_key\":[\"$(json_escape "$item")\"]}}]" >/dev/null
    done <<< "$values"
    kubectl -n "$NAMESPACE" patch kwatchconfig "$RELEASE" --type=json \
      -p "[{\"op\":\"remove\",\"path\":\"/spec/$field\"}]" >/dev/null
  done
  kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
    "kwatch.dev/legacy-silences-migrated=$CATALOG_VERSION" --overwrite >/dev/null
  echo "Legacy ignore settings were migrated into scoped silences." >&2
}

configure_flow() {
  ensure_crd
  preflight_access manage
  preflight_config_resource
  ensure_config_resource
  backup_config
  if ! migrate_legacy_silences; then
    echo "Legacy configuration migration failed; restoring the previous configuration." >&2
    restore_backup
    die "configuration migration failed"
  fi
  while true; do
    echo
    echo "kwatch configuration"
    printf '%s\n' "1) Alerts" "2) Scope" "3) Performance" \
      "4) Incident memory" "5) Noise reduction" "6) Monitors" \
      "7) Operations" "8) Compatibility" "9) Product control" \
      "10) Security" "11) Back"
    local choice category entry path type default category_name description status replacement current value
    choice=$(ask "Category" "1")
    case "$choice" in
      1) category="Alerts" ;; 2) category="Scope" ;; 3) category="Performance" ;;
      4) category="Incident memory" ;; 5) category="Noise reduction" ;; 6) category="Monitors" ;;
      7) category="Operations" ;; 8) category="Compatibility" ;; 9) category="Product control" ;;
      10) category="Security" ;; 11) return ;;
      *) echo "Unknown choice"; continue ;;
    esac
    echo
    local i=1 display_value prompt_default
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      current=$(config_value "$path")
      display_value="$current"
      [ -n "$display_value" ] || display_value="default ($default)"
      printf '%s) %s — %s\n' "$i" "$path" "$display_value"
      i=$((i + 1))
    done
    choice=$(ask "Setting" "")
    [ "$choice" -ge 1 ] 2>/dev/null || { echo "Unknown setting"; continue; }
    i=1
    for entry in "${CATALOG[@]}"; do
      IFS='|' read -r path type default category_name description status replacement <<<"$entry"
      [ "$category_name" = "$category" ] || continue
      if [ "$i" = "$choice" ]; then
        if [ "$status" = secret ]; then
          echo "Secret-backed settings are changed with configure-alert."
          break
        fi
        current=$(config_value "$path")
        show_catalog_entry "$entry"
        [ "$status" = deprecated ] && echo "  Existing values are preserved; migration is not destructive."
        prompt_default="$current"
        [ -n "$prompt_default" ] || prompt_default="$default"
        value=$(ask "New value (Enter keeps current)" "$prompt_default")
        [ -n "$value" ] || continue
        backup_config
        if ! patch_config_value "$path" "$type" "$value"; then
          echo "Invalid configuration value; restoring the previous configuration." >&2
          restore_backup
          die "configuration update failed"
        fi
        if [ "$path" = tlsMonitor.enabled ] && [ "$value" = true ]; then
          if ! verify_runtime_tls_access; then
            echo "TLS monitoring was not enabled because the deployed ServiceAccount lacks Secret access." >&2
            restore_backup
            die "TLS RBAC validation failed"
          fi
        fi
        kubectl -n "$NAMESPACE" annotate kwatchconfig "$RELEASE" \
          "kwatch.dev/config-schema=$CATALOG_VERSION" --overwrite >/dev/null
        if ! kubectl -n "$NAMESPACE" rollout restart "deployment/$(deployment_name)" >/dev/null \
          || ! kubectl -n "$NAMESPACE" rollout status "deployment/$(deployment_name)" --timeout=5m; then
          echo "Configuration failed validation; restoring backup." >&2
          restore_backup
          die "configuration update failed"
        fi
        echo "Updated $path."
        break
      fi
      i=$((i + 1))
    done
  done
}

configure_alert_flow() {
  local backup deployment
  preflight_alert_access
  backup=$(mktemp)
  trap 'if [ -n "${backup:-}" ]; then rm -f "$backup"; fi' RETURN
  kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" -o yaml >"$backup" 2>/dev/null || true
  write_config_secret
  deployment=$(deployment_name)
  if [ -n "$deployment" ] && ! kubectl -n "$NAMESPACE" rollout restart "deployment/$deployment" >/dev/null; then
    kubectl apply -f "$backup" >/dev/null 2>&1 || true
    die "could not restart kwatch after changing the notification destination"
  fi
  if [ -n "$deployment" ] && ! kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=5m; then
    echo "Notification update failed; restoring the previous credential and configuration." >&2
    [ -s "$backup" ] && kubectl apply -f "$backup" >/dev/null
    kubectl -n "$NAMESPACE" rollout restart "deployment/$deployment" >/dev/null
    kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=5m >/dev/null
    die "notification update failed"
  fi
  echo "Notification destination updated."
}

preflight_alert_access() {
  check_access get deployments namespace
  check_access patch deployments namespace
  check_access get secrets namespace
  check_access create secrets namespace
  check_access patch secrets namespace
}

NAMESPACE="${KWATCH_NAMESPACE:-$DEFAULT_NAMESPACE}"
RELEASE="${KWATCH_RELEASE:-$DEFAULT_RELEASE}"
NAMESPACE_CREATED=false
CONFIG_SECRET_NAME="${RELEASE}-config"
STATE_CONFIGMAP_NAME="${RELEASE}-manager-state"
CATALOG_CACHE_NAME="${RELEASE}-config-catalog"
CATALOG_SOURCE="embedded"
FEATURE_CATALOG_CACHE_NAME="${RELEASE}-feature-catalog"
PROVIDER_CATALOG_CACHE_NAME="${RELEASE}-provider-catalog"
valid_kubernetes_name "$NAMESPACE" || die "invalid namespace: $NAMESPACE (maximum 40 characters)"
valid_kubernetes_name "$RELEASE" || die "invalid release name: $RELEASE (maximum 40 characters)"

record_state() {
  local phase="$1" version="${2:-}" message="${3:-}"
  kubectl -n "$NAMESPACE" create configmap "$STATE_CONFIGMAP_NAME" \
    --from-literal=phase="$phase" \
    --from-literal=version="$version" \
    --from-literal=context="$SELECTED_CONTEXT" \
    --from-literal=message="$message" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
}

previous_state() {
  kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o jsonpath='{.data.phase}' 2>/dev/null || true
}

confirm_resume() {
  local phase choice
  phase=$(previous_state)
  [ -n "$phase" ] && [ "$phase" != complete ] || return 0
  [ -t 0 ] || die "a previous kwatch operation is '$phase'; an interactive terminal is required to resume safely"
  echo "A previous kwatch operation stopped during: $phase" >&2
  choice=$(ask "Continue and resume the operation" "y")
  case "$choice" in
    y|Y|yes|Yes) ;;
    *) die "operation cancelled; no changes were made" ;;
  esac
}

check_access() {
  local verb="$1" resource scope="${2:-}" result
  if [ -n "$scope" ]; then
    result=$(kubectl auth can-i "$verb" "$resource" --namespace "$NAMESPACE" 2>/dev/null || true)
  else
    result=$(kubectl auth can-i "$verb" "$resource" 2>/dev/null || true)
  fi
  case "$result" in
    yes) ;;
    no) die "missing Kubernetes permission: $verb $resource${scope:+ in namespace $NAMESPACE}" ;;
    *) echo "Warning: could not verify permission '$verb $resource'. The operation may fail later." >&2 ;;
  esac
}

preflight_access() {
  local mode="${1:-manage}"
  check_access get deployments namespace
  check_access get secrets namespace
  check_access get pods namespace
  check_access get roles namespace
  check_access get rolebindings namespace
  check_access get customresourcedefinitions
  check_access patch namespaces
  if [ "$mode" = install ]; then
    check_access create namespaces
    check_access create deployments namespace
    check_access patch deployments namespace
    check_access create secrets namespace
    check_access patch secrets namespace
    check_access create roles namespace
    check_access patch roles namespace
    check_access create rolebindings namespace
    check_access patch rolebindings namespace
    check_access create customresourcedefinitions
    check_access patch customresourcedefinitions
    check_access create clusterroles
    check_access patch clusterroles
    check_access create clusterrolebindings
    check_access patch clusterrolebindings
  else
    check_access patch deployments namespace
    check_access patch secrets namespace
    check_access patch customresourcedefinitions
    if [ "$mode" = upgrade ]; then
      check_access patch clusterroles
      check_access patch clusterrolebindings
    fi
  fi
}

preflight_config_resource() {
  check_access get kwatchconfigs namespace
  if kubectl -n "$NAMESPACE" get kwatchconfig "$RELEASE" >/dev/null 2>&1; then
    check_access patch kwatchconfigs namespace
  else
    check_access create kwatchconfigs namespace
  fi
}

latest_version() {
  local response version
  response=$(curl -fsSL --location --retry 3 --retry-delay 2 --connect-timeout 10 "$RELEASES_URL") || return 1
  version=$(printf '%s' "$response" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  valid_release_version "$version" || return 1
  printf '%s' "$version"
}

latest_release_candidate() {
  local response tag
  response=$(curl -fsSL --location --retry 3 --retry-delay 2 \
    --connect-timeout 10 "$RELEASES_LIST_URL") || return 1
  while IFS= read -r tag; do
    if [[ "$tag" == *-rc.* ]] && valid_release_version "$tag"; then
      printf '%s' "$tag"
      return 0
    fi
  done < <(
    printf '%s' "$response" |
      sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
  )
  return 1
}

select_release_version() {
  local stable preview choice
  stable=$(latest_version) || return 1
  preview=$(latest_release_candidate || true)
  if [ -z "$preview" ]; then
    printf '%s' "$stable"
    return 0
  fi
  echo "Available kwatch releases:" >&2
  echo "  1) Stable ($stable) [recommended]" >&2
  echo "  2) Release candidate ($preview)" >&2
  choice=$(ask "Release channel" "1")
  case "$choice" in
    1) printf '%s' "$stable" ;;
    2) printf '%s' "$preview" ;;
    *) echo "Invalid release choice." >&2; return 1 ;;
  esac
}

deployment_name() {
  local name
  name=$(kubectl -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "$name" ]; then
    printf '%s' "$name"
    return
  fi
  kubectl -n "$NAMESPACE" get deployment \
    -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

installed_version() {
  local image tag
  image=$(kubectl -n "$NAMESPACE" get deployment \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' \
    2>/dev/null || true)
  if [ -z "$image" ]; then
    image=$(kubectl -n "$NAMESPACE" get deployment \
      -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' \
      -o jsonpath='{.items[0].spec.template.spec.containers[0].image}' \
      2>/dev/null || true)
  fi
  tag="${image##*:}"
  valid_release_version "$tag" && printf '%s' "$tag"
}

maybe_load_catalog() {
  local version="${1:-}"
  if [ -z "$version" ]; then
    version=$(installed_version || true)
  fi
  if [ -z "$version" ]; then
    version=$(latest_version || true)
  fi
  if load_catalog_for_version "$version"; then
    echo "Configuration catalog: $CATALOG_SOURCE" >&2
  else
    echo "Configuration catalog: embedded fallback" >&2
  fi
  if load_feature_catalog_for_version "$version"; then
    echo "Feature catalog: $FEATURE_CATALOG_SOURCE" >&2
  else
    echo "Feature catalog: unavailable (the running image still enforces its feature plan)" >&2
  fi
  if load_provider_catalog_for_version "$version"; then
    echo "Provider catalog: $PROVIDER_CATALOG_SOURCE" >&2
  else
    echo "Provider catalog: embedded fallback" >&2
  fi
}

features_flow() {
  [ "${#FEATURE_CATALOG[@]}" -gt 0 ] || die "feature catalog is unavailable; retry while the release artifact is reachable"
  echo "kwatch capabilities:"
  local entry id lifecycle description dependencies
  for entry in "${FEATURE_CATALOG[@]}"; do
    IFS='|' read -r id lifecycle description dependencies <<<"$entry"
    if [ -n "$dependencies" ]; then
      printf '%-42s %-7s %s (needs: %s)\n' "$id" "$lifecycle" "$description" "$dependencies"
    else
      printf '%-42s %-7s %s\n' "$id" "$lifecycle" "$description"
    fi
  done
}

remove_namespaced_workload() {
  delete_owned() {
    local scope="$1" kind="$2" name="$3" owner
    if [ "$scope" = namespace ]; then
      owner=$(kubectl -n "$NAMESPACE" get "$kind" "$name" \
        -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
        2>/dev/null || true)
    else
      owner=$(kubectl get "$kind" "$name" \
        -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
        2>/dev/null || true)
    fi
    [ "$owner" = kwatch.sh ] || return 0
    if [ "$scope" = namespace ]; then
      kubectl -n "$NAMESPACE" delete "$kind" "$name" \
        --ignore-not-found >/dev/null 2>&1 || true
    else
      kubectl delete "$kind" "$name" --ignore-not-found >/dev/null 2>&1 || true
    fi
  }
  delete_owned namespace deployment "$RELEASE"
  delete_owned namespace service "$RELEASE"
  delete_owned namespace serviceaccount "$RELEASE"
  delete_owned namespace role "${RELEASE}-configmap-manager"
  delete_owned namespace rolebinding "${RELEASE}-configmap-manager"
  delete_owned cluster clusterrolebinding "$RELEASE"
  delete_owned cluster clusterrole "$RELEASE"
}

rollback_deployment() {
  local deployment
  deployment=$(deployment_name)
  [ -n "$deployment" ] || return 0
  kubectl -n "$NAMESPACE" rollout undo "deployment/$deployment" >/dev/null 2>&1 || return 0
  kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=5m >/dev/null 2>&1 || true
}

choose_provider() {
  local choice entry provider display field type required secret validation default description previous="" i=0
  local -a providers=()
  echo >&2
  echo "📣 Where should kwatch send alerts?" >&2
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider display field type required secret validation default description <<<"$entry"
    [ "$provider" = "$previous" ] && continue
    i=$((i + 1))
    providers+=("$provider")
    printf '  %d) %s\n' "$i" "$display" >&2
    previous="$provider"
  done
  choice=$(ask "🎯 Provider" "1")
  [[ "$choice" =~ ^[0-9]+$ ]] || die "unknown provider"
  [ "$choice" -ge 1 ] && [ "$choice" -le "${#providers[@]}" ] || die "unknown provider"
  PROVIDER="${providers[$((choice - 1))]}"
}

choose_tls_monitor() {
  local choice
  choice=$(ask "🔒 Enable TLS certificate monitoring? It reads TLS Secrets" "n")
  case "$choice" in
    y|Y|yes|Yes) TLS_MONITOR_ENABLED=true ;;
    n|N|no|No) TLS_MONITOR_ENABLED=false ;;
    *) die "please answer yes or no for TLS certificate monitoring" ;;
  esac
}

write_config_secret() {
  local secret_name="${RELEASE}-config" tmp_dir config_tmp telemetry_enabled
  local entry provider display field type required secret validation default description value
  local configure_optional force_field slack_webhook="" slack_token="" slack_channel=""
  local sns_topic_arn="" sns_target_arn=""
  local old_provider encoded old_config_file
  SECRET_ARGS=()
  WRITTEN_PROVIDER_SECTIONS="|"
  WRITTEN_CONFIG_SECTIONS="|"
  tmp_dir=$(mktemp -d)
  config_tmp="$tmp_dir/config.yaml"
  trap 'if [ -n "${tmp_dir:-}" ]; then rm -rf "$tmp_dir"; fi' RETURN
  OLD_CONFIG_PATH="$tmp_dir/old-config.yaml"
  encoded=$(secret_data_base64 "$CONFIG_SECRET_NAME" config.yaml)
  if [ -n "$encoded" ] && decode_base64_file "$encoded" "$OLD_CONFIG_PATH"; then
    old_config_file="$OLD_CONFIG_PATH"
  else
    old_config_file=""
  fi
  choose_provider
  telemetry_enabled=$(ask "📊 Send anonymous usage data to help improve kwatch" "y")
  case "$telemetry_enabled" in
    y|Y|yes|Yes) telemetry_enabled=true ;;
    n|N|no|No) telemetry_enabled=false ;;
    *) die "please answer yes or no for anonymous usage data" ;;
  esac
  configure_optional=$(ask "Configure optional provider settings too" "n")
  case "$configure_optional" in
    y|Y|yes|Yes) configure_optional=true ;;
    n|N|no|No) configure_optional=false ;;
    *) die "please answer yes or no for optional provider settings" ;;
  esac
  old_provider=""
  if [ -n "$old_config_file" ]; then
    old_provider=$(awk '
      /^alert:$/ { in_alert=1; next }
      in_alert && /^  [^ ]+:/ {
        sub(/^  /, "")
        sub(/:.*/, "")
        print
        exit
      }
    ' "$old_config_file")
  fi
  printf 'crd:\n  enabled: true\ntelemetry:\n  enabled: %s\nalert:\n  %s:\n' \
    "$telemetry_enabled" "$PROVIDER" > "$config_tmp"
  for entry in "${PROVIDER_CATALOG[@]}"; do
    IFS='|' read -r provider display field type required secret validation default description <<<"$entry"
    [ "$provider" = "$PROVIDER" ] || continue
    if [ "$provider" = slack ] && [ "$field" = token ] &&
      [ -n "$slack_webhook" ]; then
      continue
    fi
    force_field=false
    if [ "$provider" = slack ] && [ "$field" = webhook ]; then
      force_field=true
    elif [ "$provider" = slack ] && [ "$field" = token ] &&
      [ -z "$slack_webhook" ]; then
      force_field=true
    elif [ "$provider" = sns ] && [ "$field" = topicArn ]; then
      force_field=true
    elif [ "$provider" = sns ] && [ "$field" = targetArn ] &&
      [ -z "$sns_topic_arn" ]; then
      force_field=true
    elif [ "$provider" = sns ] && [ "$field" = targetArn ] &&
      [ -n "$sns_topic_arn" ]; then
      continue
    fi
    if [ "$required" != true ] && [ "$configure_optional" = false ] &&
      [ "$force_field" = false ]; then
      if [ "$secret" = true ] &&
        preserve_provider_secret "$config_tmp" "$provider" "$field" "$tmp_dir"; then
        case "$field" in
          webhook) slack_webhook=preserved ;;
          token) slack_token=preserved ;;
          topicArn) sns_topic_arn=preserved ;;
          targetArn) sns_target_arn=preserved ;;
        esac
      elif [ "$provider" = "$old_provider" ] &&
        preserve_provider_optional "$config_tmp" "$provider" "$field" \
        "$type" "$tmp_dir"; then
        [ "$field" = channel ] && slack_channel=preserved
      elif [ -n "$default" ] && [ "$type" != headers ]; then
        write_provider_value "$config_tmp" "$field" "$type" "$default"
        [ "$field" = channel ] && slack_channel="$default"
      fi
      continue
    fi
    if [ "$type" = headers ]; then
      [ "$configure_optional" = true ] || continue
      write_webhook_headers "$config_tmp" "$tmp_dir"
      continue
    fi
    if [ "$secret" = true ]; then
      value=$(ask_secret "$description")
    else
      value=$(ask "$description" "$default")
    fi
    if [ -z "$value" ] && [ "$secret" = true ] &&
      preserve_provider_secret "$config_tmp" "$provider" "$field" "$tmp_dir"; then
      case "$field" in
        webhook) slack_webhook=preserved ;;
        token) slack_token=preserved ;;
        topicArn) sns_topic_arn=preserved ;;
        targetArn) sns_target_arn=preserved ;;
      esac
      continue
    fi
    [ "$required" = false ] || [ -n "$value" ] || die "$field cannot be empty"
    case "$validation" in
      url) [[ "$value" =~ ^https?:// ]] || die "$field must be an http or https URL" ;;
      telegram-chat-id) [[ "$value" =~ ^-?[0-9]+$ ]] || die "$field must be a Telegram chat ID" ;;
      port) [[ "$value" =~ ^[0-9]+$ ]] || die "$field must be a numeric port" ;;
      integer) [[ "$value" =~ ^[0-9]+$ ]] || die "$field must be a non-negative integer" ;;
      boolean) [[ "$value" = true || "$value" = false ]] || die "$field must be true or false" ;;
      json) [[ "$value" = \[* || "$value" = \{* ]] || die "$field must be a JSON object or array" ;;
      "") ;;
      *) die "provider catalog has unknown validation: $validation" ;;
    esac
    [ -n "$value" ] || continue
    if [ "$secret" = true ]; then
      write_provider_secret "$config_tmp" "$field" "$value" "$tmp_dir"
    else
      write_provider_value "$config_tmp" "$field" "$type" "$value"
    fi
    case "$field" in
      webhook) slack_webhook="$value" ;;
      token) slack_token="$value" ;;
      channel) slack_channel="$value" ;;
      topicArn) sns_topic_arn="$value" ;;
      targetArn) sns_target_arn="$value" ;;
    esac
  done
  if [ "$PROVIDER" = slack ]; then
    if [ -z "$slack_webhook" ] && [ -z "$slack_token" ]; then
      die "Slack requires a webhook or bot token"
    fi
    if [ -n "$slack_token" ] && [ -z "$slack_channel" ]; then
      slack_channel=$(ask "Slack channel for bot-token mode")
      [ -n "$slack_channel" ] || die "Slack channel cannot be empty in bot-token mode"
      write_provider_value "$config_tmp" channel string "$slack_channel"
    fi
  fi
  if [ "$PROVIDER" = sns ] && [ -z "$sns_topic_arn" ] &&
    [ -z "$sns_target_arn" ]; then
    die "SNS requires a topic ARN or target ARN"
  fi
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r path type default category description status replacement <<<"$entry"
    [ "$status" = secret ] || continue
    value=$(ask_secret "$description (leave empty to skip)")
    if [ -z "$value" ]; then
      preserve_config_secret "$config_tmp" "$path" "$tmp_dir" || true
      continue
    fi
    write_config_secret_value "$config_tmp" "$path" "$value" "$tmp_dir"
  done
  kubectl -n "$NAMESPACE" create secret generic "$secret_name" \
    --from-file=config.yaml="$config_tmp" \
    "${SECRET_ARGS[@]}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl -n "$NAMESPACE" label secret "$secret_name" \
    app.kubernetes.io/instance="$RELEASE" \
    app.kubernetes.io/managed-by=kwatch.sh --overwrite >/dev/null
  CONFIG_SECRET_NAME="$secret_name"
}

apply_manifests() {
  local version="$1" tmp crd_tmp deployment
  valid_release_version "$version" || die "invalid kwatch release version: $version"
  tmp=$(mktemp)
  crd_tmp=$(mktemp)
  trap 'rm -f "${tmp:-}" "${tmp:-}.bak" "${crd_tmp:-}" 2>/dev/null || true' RETURN
  curl -fsSL --location --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/crd.yaml" -o "$crd_tmp" || return 1
  kubectl apply -f "$crd_tmp"
  kubectl wait --for=condition=Established \
    crd/kwatchconfigs.kwatch.abahmed.dev --timeout=60s >/dev/null
  preflight_config_resource
  curl -fsSL --location --retry 3 --retry-delay 2 --connect-timeout 10 \
    "$BASE_URL/$version/deploy/deploy.yaml" -o "$tmp" || return 1
  grep -q '^kind: Deployment$' "$tmp" || return 1
  sed -i.bak \
    -e "/^kind: Namespace$/,/^---$/ s/^  name: kwatch$/  name: __KWATCH_NAMESPACE__/" \
    -e "s/^\( *name: \)kwatch$/\1$RELEASE/g" \
    -e "s/^\( *name: \)kwatch-configmap-manager$/\1${RELEASE}-configmap-manager/g" \
    -e "s/namespace: kwatch/namespace: $NAMESPACE/g" \
    -e "s/^\( *app.kubernetes.io\/instance: \)kwatch$/\1$RELEASE/g" \
    -e "s#ghcr.io/abahmed/kwatch:[^[:space:]]*#ghcr.io/abahmed/kwatch:$version#g" \
    -e "s/secretName: kwatch/secretName: $CONFIG_SECRET_NAME/g" \
    -e "s/__KWATCH_NAMESPACE__/$NAMESPACE/g" \
    "$tmp"
  kubectl apply -f "$tmp"
  ensure_config_resource
  if [ "${TLS_MONITOR_ENABLED:-false}" = true ]; then
    enable_initial_tls_monitor
  elif [ "$(config_value tlsMonitor.enabled)" = true ]; then
    verify_runtime_tls_access
  fi
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  kubectl -n "$NAMESPACE" rollout status "deployment/$deployment" --timeout=5m
}

verify_operational_security() {
  local deployment enforce non_root read_only no_escalation seccomp dropped secret_mode
  deployment=$(deployment_name)
  [ -n "$deployment" ] || deployment="$RELEASE"
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}')
  non_root=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.runAsNonRoot}')
  read_only=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}')
  no_escalation=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}')
  seccomp=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.seccompProfile.type}')
  dropped=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.containers[0].securityContext.capabilities.drop[0]}')
  secret_mode=$(kubectl -n "$NAMESPACE" get deployment "$deployment" \
    -o 'jsonpath={.spec.template.spec.volumes[0].secret.defaultMode}')
  [ "$enforce" = restricted ] || {
    echo "namespace Pod Security enforcement is not restricted" >&2
    return 1
  }
  [ "$non_root" = true ] || {
    echo "kwatch deployment is not configured as non-root" >&2
    return 1
  }
  [ "$read_only" = true ] || {
    echo "kwatch deployment root filesystem is writable" >&2
    return 1
  }
  [ "$no_escalation" = false ] || {
    echo "kwatch deployment allows privilege escalation" >&2
    return 1
  }
  [ "$seccomp" = RuntimeDefault ] || {
    echo "kwatch deployment lacks RuntimeDefault seccomp" >&2
    return 1
  }
  [ "$dropped" = ALL ] || {
    echo "kwatch deployment does not drop all capabilities" >&2
    return 1
  }
  [ "$secret_mode" = 256 ] || {
    echo "kwatch Secret volume is not mode 0400" >&2
    return 1
  }
  echo "🛡️ Kubernetes operational protection verified."
}

apply_operational_namespace_labels() {
  local enforce audit warn managed
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}' \
    2>/dev/null || true)
  managed=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/managed-namespace}' \
    2>/dev/null || true)
  audit=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/audit}' \
    2>/dev/null || true)
  warn=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/warn}' \
    2>/dev/null || true)
  if { [ "$enforce" != restricted ] || [ "$audit" != restricted ] ||
    [ "$warn" != restricted ]; } && [ "$managed" != true ] &&
    [ "$NAMESPACE_CREATED" != true ] &&
    [ "${KWATCH_ALLOW_NAMESPACE_LABELS:-false}" != true ]; then
    die "namespace '$NAMESPACE' already exists without restricted Pod Security labels; set KWATCH_ALLOW_NAMESPACE_LABELS=true only after reviewing the shared namespace"
  fi
  kubectl label namespace "$NAMESPACE" \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/audit=restricted \
    pod-security.kubernetes.io/warn=restricted --overwrite >/dev/null
  if [ "$NAMESPACE_CREATED" = true ]; then
    kubectl annotate namespace "$NAMESPACE" \
      kwatch.dev/managed-namespace=true --overwrite >/dev/null
  fi
}

clear_managed_namespace_labels() {
  local managed enforce audit warn
  managed=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.annotations.kwatch\.dev/managed-namespace}' \
    2>/dev/null || true)
  [ "$managed" = true ] || return 0
  enforce=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/enforce}' \
    2>/dev/null || true)
  audit=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/audit}' \
    2>/dev/null || true)
  warn=$(kubectl get namespace "$NAMESPACE" \
    -o 'jsonpath={.metadata.labels.pod-security\.kubernetes\.io/warn}' \
    2>/dev/null || true)
  [ "$enforce" = restricted ] && [ "$audit" = restricted ] && \
    [ "$warn" = restricted ] || return 0
  kubectl label namespace "$NAMESPACE" \
    pod-security.kubernetes.io/enforce- \
    pod-security.kubernetes.io/audit- \
    pod-security.kubernetes.io/warn- >/dev/null 2>&1 || true
  kubectl annotate namespace "$NAMESPACE" \
    kwatch.dev/managed-namespace- >/dev/null 2>&1 || true
}

install_flow() {
  kubectl cluster-info >/dev/null || die "cannot reach the Kubernetes cluster"
  confirm_resume
  local version
  version=$(select_release_version) || die "could not determine kwatch release from GitHub"
  maybe_load_catalog "$version"
  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    NAMESPACE_CREATED=false
  else
    kubectl create namespace "$NAMESPACE" >/dev/null
    NAMESPACE_CREATED=true
  fi
  apply_operational_namespace_labels
  preflight_access install
  record_state preflight "$version" "cluster selected and reachable"
  echo "🚀 Installing kwatch $version..."
  record_state backup "$version" "creating notification Secret"
  choose_tls_monitor
  write_config_secret
  record_state apply "$version" "applying CRD and Deployment"
  if ! apply_manifests "$version" || ! verify_operational_security; then
    record_state failed "$version" "installation failed; workload cleanup attempted"
    echo "Installation failed; removing the workload resources that were created." >&2
    remove_namespaced_workload
    die "installation failed; the CRD and any configuration resource were preserved"
  fi
  record_state complete "$version" "installation verified"
  echo "✅ kwatch is ready."
}

upgrade_flow() {
  local version
  confirm_resume
  version=$(select_release_version) || die "could not determine kwatch release from GitHub"
  maybe_load_catalog "$version"
  echo "⬆️ Upgrading kwatch to $version..."
  apply_operational_namespace_labels
  record_state preflight "$version" "upgrade started"
  ensure_crd "$version"
  preflight_access upgrade
  preflight_config_resource
  ensure_config_resource
  backup_config
  record_state backup "$version" "configuration backup created"
  if ! migrate_legacy_silences; then
    echo "Legacy configuration migration failed; restoring the previous configuration." >&2
    restore_backup
    record_state failed "$version" "legacy configuration migration failed"
    die "upgrade migration failed"
  fi
  record_state apply "$version" "applying upgraded Deployment"
  if ! apply_manifests "$version" || ! verify_operational_security; then
    echo "Upgrade failed; restoring the previous configuration." >&2
    restore_backup
    rollback_deployment
    record_state failed "$version" "deployment rollout failed; rollback attempted"
    die "upgrade failed"
  fi
  record_state complete "$version" "upgrade verified"
  echo "✅ kwatch upgraded successfully."
}

status_flow() {
  echo "Context: $SELECTED_CONTEXT"
  echo "Namespace: $NAMESPACE"
  echo "Configuration catalog: $CATALOG_SOURCE"
  kubectl -n "$NAMESPACE" get deployment,pod \
    -l "app.kubernetes.io/instance=$RELEASE,app.kubernetes.io/managed-by=kwatch.sh" \
    2>/dev/null || \
    kubectl -n "$NAMESPACE" get deployment,pod \
      -l 'app=kwatch,app.kubernetes.io/managed-by=kwatch.sh' 2>/dev/null || true
  kubectl -n "$NAMESPACE" get configmap "$STATE_CONFIGMAP_NAME" \
    -o 'custom-columns=PHASE:.data.phase,VERSION:.data.version,MESSAGE:.data.message' \
    --no-headers 2>/dev/null || echo "Manager state: not available"
}

uninstall_flow() {
  local confirm secret_owner
  confirm=$(ask "Type uninstall to remove kwatch" "")
  [ "$confirm" = uninstall ] || { echo "Cancelled."; return; }
  echo "🧹 Removing kwatch resources from namespace '$NAMESPACE'; other namespace resources will be preserved." >&2
  remove_namespaced_workload
  secret_owner=$(kubectl -n "$NAMESPACE" get secret "$CONFIG_SECRET_NAME" \
    -o 'jsonpath={.metadata.labels.app\.kubernetes\.io/managed-by}' \
    2>/dev/null || true)
  if [ "$secret_owner" = kwatch.sh ]; then
    kubectl -n "$NAMESPACE" delete secret "$CONFIG_SECRET_NAME" \
      --ignore-not-found
  else
    echo "Preserving unowned Secret '$CONFIG_SECRET_NAME'." >&2
  fi
  clear_managed_namespace_labels
  echo "✅ kwatch workload removed. KwatchConfig, backups, namespace, and CRD were preserved." >&2
}

main() {
  local action="${1:-}"
  case "$action" in
    --help|-h)
      echo "Usage: kwatch.sh [install|configure-alert|configure|upgrade|status|features|uninstall]"
      echo "🧭 Interactive kubectl manager with operational security checks."
      exit 0
      ;;
    --version|-v)
      echo "kwatch manager catalog $CATALOG_VERSION"
      exit 0
      ;;
  esac
  require_tools
  select_context
  maybe_load_catalog
  migration_notice
  if [ -z "$action" ]; then
    if [ -n "$(deployment_name)" ]; then
      cat >&2 <<'EOF'

✅ kwatch is already installed:
  1) Configure notification destination
  2) Configure settings
  3) Upgrade
  4) Show status
  5) Show capabilities
  6) Uninstall
  7) Exit
EOF
      action=$(ask "Choice" "1")
      case "$action" in
        1) action=configure-alert ;; 2) action=configure ;; 3) action=upgrade ;;
        4) action=status ;; 5) action=features ;; 6) action=uninstall ;; 7) exit 0 ;; *) die "unknown choice" ;;
      esac
    else
      action=install
    fi
  fi
  case "$action" in
    install) install_flow ;; configure-alert) configure_alert_flow ;; configure) configure_flow ;; upgrade) upgrade_flow ;;
    status) status_flow ;; features) features_flow ;; uninstall) uninstall_flow ;;
    *) die "usage: $0 [install|configure-alert|configure|upgrade|status|features|uninstall]" ;;
  esac
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
