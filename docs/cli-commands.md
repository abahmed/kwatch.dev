---
sidebar_position: 20
title: CLI Commands
description: command-line interface commands, flags, environment variables, and exit codes for kwatch
keywords: [kwatch, cli, commands, lint, replay, version, flags]
pagination_next: null
pagination_prev: null
---

# 🛠️ CLI Commands

kwatch's binary accepts several commands and flags for runtime, validation, and
diagnostics.

## `kwatch` — run the monitor

Starts the full informer-based controller. Reads config from `CONFIG_FILE`
environment variable (default `/config/config.yaml`).

```shell
kwatch
```

## `kwatch --version` — print version

```shell
kwatch --version
# v0.11.0-rc.6
```

## `kwatch lint` — validate configuration

Validates your config file for common mistakes without running the monitor.

```shell
kwatch lint
# config OK
```

### Flags

| Flag | Description |
|------|-------------|
| `--strict` | Catches unknown/typo'd config fields (strict unmarshal) |
| `--check` | Validate config **and** test all provider credentials |

```shell
# Validate config
kwatch lint

# Strict mode — catches typos in field names
kwatch lint --strict

# Full validation + provider credential check
kwatch lint --check
#   slack: OK
#   pagerduty: OK
#   email: FAIL — could not connect to SMTP server
# config OK
```

### What `lint` checks

- At least one alert provider is configured
- `healthCheck.port` is valid when enabled
- `maxRecentLogLines` is non-negative
- PVC monitor thresholds are consistent (0 < threshold ≤ criticalThreshold ≤ 100)
- `correlation.window` and `lifecycleInterval` are positive
- `pendingPodMonitor.threshold` is positive when enabled
- `workers` is at least 1
- `escalation.tiers` are strictly ascending and positive
- `resolveHoldDown` ≤ `correlation.window * 60`
- `maxBaseline` doesn't exceed ConfigMap size limits
- No unknown provider names

## `kwatch replay` — replay past events

Reads JSONL-formatted events from stdin and simulates delivery. Useful for
testing routing, formatting, and provider configuration.

```shell
kwatch replay < events.jsonl
```

### Input format

```jsonl
# events.jsonl
{"resource":"pod","podName":"nginx-abc123","namespace":"default","reason":"OOMKilled","containerName":"nginx","logs":"...","events":"..."}
{"resource":"node","nodeName":"ip-10-0-0-1","reason":"NodeNotReady"}
```

Lines starting with `#` are ignored. Empty lines are skipped.

### Output

```shell
$ kwatch replay < events.jsonl
would notify [slack pagerduty]: default/nginx-abc123 OOMKilled: ...
would notify [slack pagerduty]:  NodeNotReady: ...
```

> **Note:** Replay mode validates config and lists which providers would be
> notified, but does **not** actually send alerts. Use `lint --check` to test
> provider connectivity.

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_FILE` | `/config/config.yaml` | Path to the YAML config file |
| `POD_NAMESPACE` | (auto-detected) | Namespace kwatch runs in (for ConfigMap state) |

The config file also supports `${VAR}` syntax for environment variable
expansion:

```yaml
alert:
  slack:
    webhook: "${SLACK_WEBHOOK_URL}"
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Config error, lint failure, or runtime error |

When `kwatch` receives SIGTERM/SIGINT, it shuts down gracefully:
1. Stops informers and drains workqueues
2. Waits up to 10s for the alert manager to flush pending notifications
3. Saves baseline state to ConfigMap
4. Exits with code `0`
