---
sidebar_position: 15
title: Send Kubernetes alerts to Custom Webhook with kwatch
sidebar_label: Custom Webhook
description: Send clear Kubernetes incident alerts to any custom webhook — configure endpoint and payload format for kwatch
keywords: [kwatch, webhook, custom, kubernetes incident alerts, k8s notifications, webhook integration]
pagination_next: null
pagination_prev: null
---

# 🔗 Custom Webhook

Use the [interactive kwatch manager](/installation) to configure Custom
Webhook alerts. It stores credentials in Kubernetes Secrets and verifies the
installation. The configuration fragments below explain provider settings;
they are not separate installation steps.

| Parameter | Description | Required |
|:----------|:------------|:---------|
| `alert.webhook.url` | 🔗 Webhook URL | Yes |
| `alert.webhook.headers` | 📋 Custom headers | No |
| `alert.webhook.basicAuth` | 🔐 Username + password | No |

## Configuration example

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
```

## Routing <span className="kw-pro">Pro</span>

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
    routes:
      - namespaces: ["production"]
        severities: ["high", "critical"]
      - reasons: ["OOMKilled"]
```

## Retry

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
    retry:
      maxAttempts: 5
      delay: 5s
```

## Fallback

```yaml
alert:
  webhook:
    url: "${file:/config/webhook-url}"
    headers:
      - name: X-Custom
        value: "${file:/config/webhook-header}"
    basicAuth:
      username: "user"
      password: "${file:/config/webhook-password}"
    fallback: <another_provider>
```

## Evidence <span className="kw-pro">Pro</span>

For an investigated incident, the payload carries one extra `evidence`
object. Receivers that ignore it keep working, and Community payloads never
carry it. See [What kwatch checks for you](/what-kwatch-checks).

```json
"evidence": {
  "confirmed": true,
  "checks": 6,
  "facts": ["checkout logs: ...", "10.96.14.7 is Service orders-db ..."],
  "quote": { "container": "app", "run": "previous", "lines": ["..."] },
  "fix": [{ "text": "Point the Service at the label the pods carry",
            "command": "kubectl patch service ...", "mutating": true }]
}
```

| Field | Meaning |
| --- | --- |
| `confirmed` | `true` when the gathered evidence proves the cause |
| `checks` | How many checks ran and read an answer |
| `facts` | Up to 4 key facts, most decisive first |
| `quote` | Up to 5 log lines that carry the failure's signature, with the `container` and the `run` (`previous` or `current`) |
| `fix` | Steps that change the cluster, each with `text`, an optional `command` and `mutating: true` |

## Related

- [Custom Webhook provider settings](/channels/provider-guides/webhook) for every field
- [All alert providers](/channels/providers) and [troubleshoot missing alerts](/operations/troubleshooting)
