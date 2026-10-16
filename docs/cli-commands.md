---
sidebar_position: 20
title: CLI Commands
description: kwatch command-line reference covering lint, version, license status, move and deactivate, replay-export, environment variables and exit codes.
keywords: [kwatch, cli, commands, lint, version, license, replay-export, flags]
pagination_next: null
pagination_prev: null
---

# 💻 CLI commands

The `kwatch` binary runs the monitor and ships a few commands for validating a
configuration, checking your license and exporting a recording. Most users only
need `kwatch lint`. The commands run inside the kwatch pod, for example:

```bash
kubectl -n kwatch exec deploy/kwatch -- kwatch lint
```

| Command | What it does | Edition |
| --- | --- | --- |
| `kwatch` | Run the monitor | Community and Pro |
| `kwatch version` | Print the version, commit and build date | Community and Pro |
| `kwatch lint` | Validate the configuration | Community and Pro |
| `kwatch license status` | Show the local license state | Community and Pro |
| `kwatch license move` | Move the license to this cluster | Pro |
| `kwatch license deactivate` | Release the license from this cluster | Pro |
| `kwatch replay-export` | Export the flight recording | Pro |

An unknown command exits with code 2 and does not start the monitor.

## `kwatch` — run the monitor

Starts the monitor. It reads the config from the `CONFIG_FILE` environment
variable (default `/config/config.yaml`).

## `kwatch version` — print the version

```shell
kwatch version
# version v1.0.0 (commit abc1234, built 2026-01-01T00:00:00Z)

kwatch version --json
```

`--json` prints the same data plus the active edition. The older `--version`
flag still prints only the short version.

## `kwatch lint` — validate configuration

Checks your config file without running the monitor.

```shell
kwatch lint
# config OK
```

| Flag | Description |
| --- | --- |
| `--strict` | Reject unknown or misspelled config fields instead of warning |
| `--check` | Also contact each provider that supports checks and verify its credentials |

```shell
kwatch lint --check
#   slack: OK
#   email: FAIL — could not connect to SMTP server
```

Lint exits `1` on an error and prints warnings, which are not fatal, for
settings that work but may mislead. It also prints an `info:` line for each
<span className="kw-pro">Pro</span> setting your configuration contains while
the edition is Community. Those settings are ignored, and the file stays valid
for an upgrade. A real configuration check includes provider names and
settings, ports, thresholds and silences. Lint requires at least one alert
provider, although the monitor itself can run without one.

## `kwatch license` — manage the Pro license

Community needs no key, and these commands only matter for
[Pro](/docs/editions). They read the key from `license.key` or the
`KWATCH_LICENSE_KEY` variable (the variable wins). The installer's
**License / Pro** menu runs them for you; see [License](/docs/license).

### `kwatch license status`

Prints the local state of the configured key without using the network. The
key is shown masked.

```shell
kubectl -n kwatch exec deploy/kwatch -- kwatch license status
# Key:     KW1-…ab12
# State:   valid key (activation is not checked here)
# Plan:    trial
# License: lic_…9f3c
# Expires: 2027-01-15 (88 days left)
```

With no key it prints that kwatch runs the Community edition. The live state
(`active`, `grace`, `conflict` and so on) is in the `/status` output; see
[the license states](/docs/license#troubleshooting-status).

### `kwatch license move`

Takes the license over for the cluster you run it in. Use it when the key is
bound to another cluster.

```shell
kubectl -n kwatch exec deploy/kwatch -- kwatch license move
```

It asks the running kwatch, which holds the cluster identity, to do the move,
and prints one of:

| Outcome | Exit code |
| --- | --- |
| Moved: the license is now active here and the previous cluster drops to Community at its next daily check | `0` |
| Already active on this cluster, nothing to move | `0` |
| Transfer limit reached: 3 moves per 30 days, with the days until a slot frees | `1` |
| The license server does not accept the key | `1` |
| The request waited too long for the running kwatch (it stays queued for 10 minutes) | `1` |

Install the key on the new cluster first, and make sure kwatch is running
there. A move counts toward the same 3 per 30 days as a website transfer.

### `kwatch license deactivate`

Releases this cluster's binding on the license server so the key can be used
elsewhere. The installer runs it for you during uninstall.

```shell
kubectl -n kwatch exec deploy/kwatch -- kwatch license deactivate
```

It counts as one of the 3 moves per 30 days. With no key configured it does
nothing.

## `kwatch replay-export` — export the flight recording <span className="kw-pro">Pro</span>

kwatch keeps a sanitized flight recording of what its sources observed (48
hours, capped at 64 MiB). `replay-export` writes a window of it as a log the
scenario library can replay. Names are hashed pseudonyms, and log and event
text is dropped, so the file is safe to share.

```shell
kubectl exec -n kwatch deploy/kwatch -- \
  kwatch replay-export --since 2h --out /var/lib/kwatch/incident.jsonl
kubectl cp kwatch/<pod>:/var/lib/kwatch/incident.jsonl ./incident.jsonl
```

| Flag | Description |
| --- | --- |
| `--since` | Start of the window: a duration back (`2h`) or an RFC 3339 time. Required in practice |
| `--until` | End of the window, same format; default is now |
| `--state` | State file to read; default is the kwatch state file |
| `--out` | File to write. Required |

The state file is locked while kwatch runs, so the command works on a copy next
to the output file and needs free space for it. In Community the command exits
with `replay-export is a kwatch Pro feature`.

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `CONFIG_FILE` | `/config/config.yaml` | Path to the YAML config file |
| `POD_NAMESPACE` | detected from the pod | Namespace kwatch runs in |
| `KWATCH_LICENSE_KEY` | empty | Pro license key; wins over `license.key` |
| `KWATCH_DATA_DIR` | `/var/lib/kwatch` | Directory of the state file |
| `GOMEMLIMIT` | based on the resource limit | Soft Go memory limit |

The config file supports `${VAR}` for non-sensitive strings. Credentials must
use an absolute file reference backed by a mounted Secret:

```yaml
alert:
  slack:
    webhook: "${file:/config/slack-webhook}"
```

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Success |
| `1` | Config error, lint failure, runtime error, or a Pro-only command in Community |
| `2` | Unknown command or wrong arguments |

When `kwatch` receives SIGTERM or SIGINT it shuts down gracefully: it marks
readiness false, stops monitoring and delivery, waits for persistence writers,
and exits with code `0`.
