---
sidebar_position: 3
title: Upgrade kwatch to v1.0.0 from v0.10.x
sidebar_label: Upgrading to v1.0.0
description: Upgrade a running kwatch v0.10.x install to v1.0.0 with the kwatch.sh installer, and what changes on the first start.
keywords: [kwatch upgrade, kwatch v1.0.0, v0.10.5, kwatch.sh, kubectl apply, helm upgrade, migration]
---

# ⬆️ Upgrading to v1.0.0

`v1.0.0` is a major release; the previous stable release is `v0.10.5`. This page
tells you what to expect when you move to it. The upgrade runs through the
[`kwatch.sh` installer](/kwatch-sh), like every other lifecycle action.

## How the installer handles it

Run the installer and select your cluster:

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

- **A running `v0.10.x`.** The installer offers **Uninstall legacy kwatch and
  fresh-install**. It validates the target release, saves a timestamped backup
  Secret with your old configuration and manifests, shows its name, and
  continues only after you confirm. Re-enter your notification providers
  afterwards; credentials are stored in a Secret.
- **A running `v1.0.0` or newer.** Choose **Upgrade**. The configuration is backed
  up first, and a failed rollout is rolled back when possible.
- **Version.** The installer selects the newest Stable release by default.

See the [installer guide](/kwatch-manager) for every menu option.

## What changes on the first start

| Area | `v0.10.x` | `v1.0.0` |
| --- | --- | --- |
| State | In memory, lost on every restart | Kept on a 2Gi volume with <span className="kw-pro">Pro</span>; Community keeps it in memory |
| Replicas | Deployment default strategy | One replica with the `Recreate` strategy; standby replicas are <span className="kw-pro">Pro</span> |
| Credentials | Inline in the config | Only `${file:/absolute/path}` references to a mounted Secret; the installer does this for you |
| Endpoints | `/healthz`, `/health` | Adds `/readyz`, `/availabilityz`, `/metrics` and the opt-in `/status` |
| Memory | 128Mi limit | 512Mi limit |

Other things to know:

- There is no state to migrate. kwatch learns baselines from scratch and sends
  one startup summary instead of announcing every existing problem.
- Alert keys now read `kwatch-<cluster>-<incident key>`. An alert that `v0.10.x`
  opened in Opsgenie, PagerDuty or another keyed provider is not closed
  automatically; close it by hand once. Update any automation that matches
  the webhook `alertKey` or the `X-Kwatch-Alert-Key` email header.
- Several old keys no longer exist (`pvcMonitor.*`, `nodeMonitor.*`,
  `maxRecentLogLines`, `ignoreLogPatterns`, `ignoreFailedGracefulShutdown`).
  The `ignore*` lists still work but are deprecated; use
  [silences](/general-configuration#-silences--advanced-suppression).
- `alert.line` (LINE Notify) is ignored; the service was shut down.
- Community sends no telemetry. With an active Pro license, telemetry can be turned off with
  `telemetry.enabled: false` under **Edit settings**. The update check is controlled by
  `upgrader.disableUpdateCheck`. See [General configuration](/general-configuration#-minimal-adoption-telemetry).
- Open the cluster port 10250 to the nodes if you run a NetworkPolicy: kwatch reads
  node stats directly from each kubelet.

## Permissions

The installer applies the read-only permissions kwatch needs. kwatch no longer
gets `nodes/proxy`, and `get` is granted only on namespaces, nodes, node stats
and metrics, and pod logs. Secrets are watched by default; set
`watch.secrets: false` to remove all Secret access. The license instance key
Secret needs only `get` and `update`. See
[RBAC and deployment security](/operations/rbac-and-security).

## If you applied manifests with kubectl

Use the installer; it is the recommended path. If you apply manifests yourself,
note that the Deployment selector changed: it now includes
`app.kubernetes.io/instance: kwatch`. Kubernetes does not allow a selector to
change on an existing Deployment, so delete the old Deployment first, then
apply the new manifests:

```bash
kubectl -n kwatch delete deployment kwatch
```

kwatch is down until the new manifests are applied.

## If you use Helm (advanced)

Helm is a short pointer here; the installer is the supported path. The chart
repository is `https://kwatch.dev/charts`, and the `v1.0.0` release ships
chart `1.0.0`. `helm upgrade` with your existing values from `v0.10.x` works.
The default `rbac.mode` is `least-privilege`; pass `--set rbac.mode=full` to
watch custom resources and kinds added later. The chart rejects unknown
values, so compare your values file with the chart's `values.yaml` before
upgrading. Chart values are listed in the
[chart README](https://github.com/abahmed/kwatch/blob/main/deploy/chart/README.md).

## Verify

1. `kubectl -n kwatch get pods,pvc`: the Pod is `Running` and, with Pro, the claim is `Bound`.
2. **View status** in the installer shows a healthy install and the license state.
3. The first startup summary arrives in your channel.

## Rolling back

When the installer replaces a `v0.10.x` install, it first saves a backup
Secret named `kwatch-legacy-backup-<timestamp>` (it shows the exact name) with
the old Deployment, ConfigMap and config. It keeps that Secret after the
uninstall, so you can read your old settings from it. The installer does not
restore a legacy install from it automatically.

To go back, run the installer again and install the earlier release, then
re-enter your notification providers using the backup as a reference.
`v0.10.x` does not read the new state file, so a rollback loses only what
`v1.0.0` learned. A Pro license ends cleanly: kwatch falls back to Community
and detection and alerting never stop.
