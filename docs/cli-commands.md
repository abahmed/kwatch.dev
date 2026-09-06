---
sidebar_position: 20
title: CLI Commands
description: command-line interface commands, flags, environment variables, and exit codes for kwatch
keywords: [kwatch, cli, commands, lint, replay, version, flags]
pagination_next: null
pagination_prev: null
---

# 💻 CLI commands

Use the CLI when you want to run kwatch, validate a configuration, or replay a
saved event. Most users can start with `kwatch lint`.

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
# vX.Y.Z
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
| `--check` | Validate config and verify credentials for providers that support checks |

```shell
# Validate config
kwatch lint

# Strict mode — catches typos in field names
kwatch lint --strict

# Full validation + supported provider credential checks
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

The runtime can intentionally run in monitor-only mode with no alert providers;
the `lint` command keeps the stricter requirement because it validates an
alerting configuration.

## `kwatch replay` — replay saved events

Reads JSONL-formatted events from stdin and sends them through the configured
providers. This is useful for testing event formatting and delivery. Because
the normal command sends real notifications, use `--dry-run` when you only
want to preview the result.

```shell
kwatch replay < events.jsonl

# Preview without sending notifications
kwatch replay --dry-run < events.jsonl
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
$ kwatch replay --dry-run < events.jsonl
would replay to [slack pagerduty]: [replay] default/nginx-abc123 OOMKilled: ...
would replay to [slack pagerduty]: [replay] / NodeNotReady: ...
```

> **Safety note:** `kwatch replay` sends real notifications unless
> `--dry-run` is set. Use `lint --check` to test provider connectivity without
> sending an event.

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_FILE` | `/config/config.yaml` | Path to the YAML config file |
| `POD_NAMESPACE` | (auto-detected) | Namespace kwatch runs in (for ConfigMap state) |

The config file supports `${VAR}` for non-sensitive strings. Credentials must
use an absolute file reference backed by a mounted Secret:

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
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
