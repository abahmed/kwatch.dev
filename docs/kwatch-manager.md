---
sidebar_position: 3
title: kwatch.sh manager
description: use the interactive kwatch.sh manager to install, configure, upgrade, and uninstall Kubernetes monitoring
keywords: [kwatch.sh, Kubernetes installer, Kubernetes manager, kwatch upgrade, Kubernetes monitoring]
pagination_next: null
pagination_prev: null
---

# 🧭 The kwatch.sh manager

The interactive manager is the easiest way to start with kwatch. It asks a few
simple questions, creates the Kubernetes resources, and checks that kwatch is
ready before it finishes.

## 🚀 Start the manager

You need:

- `kubectl` installed and connected to your cluster
- `curl` installed
- permission to install namespace-scoped resources and cluster-scoped CRD/RBAC
  resources

Run:

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

If you prefer to inspect the script first:

```bash
curl -fsSL https://kwatch.dev/kwatch.sh -o kwatch.sh
less kwatch.sh
bash kwatch.sh
```

The script is plain Bash and is published in the
[`kwatch.dev` repository](https://github.com/abahmed/kwatch.dev/blob/main/static/kwatch.sh).

The manager never changes your current `kubectl` context. If you have more than
one cluster configured, it shows a list and asks you to choose one.

## 🧭 How the interactive flow works

Every run starts by asking which Kubernetes context to manage. The manager
does not change your current context. It then checks for a running kwatch
Deployment and reads its image version. Configuration resources by themselves
do not count as an installation.

The available menu depends on what is actually running:

- No Deployment: **Install kwatch** or exit.
- A running version below `v1.0.0`: **Uninstall legacy kwatch and fresh-install**
  or exit.
  Catalog-based editing and other management actions are unavailable for these
  legacy releases.
- A healthy running version `v1.0.0` or newer: **Upgrade**, **Edit notification
  providers**, **Edit settings**, **View status**, or **Uninstall**.
- An unhealthy or unidentified Deployment: **Repair by upgrading**, **View
  status**, or **Uninstall**.

For a fresh installation, the manager selects a version, downloads and
validates its catalogs, lets you configure zero, one, or several notification
providers, stores credentials in a Secret, installs the CRD and hardened
workload, applies restricted Pod Security labels, and waits for the Deployment
to become ready.

During installation and upgrade, the manager shows the newest Stable release
and, when available, the newest Release Candidate. Stable is selected by
default; choose the RC interactively when you want to test preview changes.
If a Stable release does not publish the catalogs required by the manager, it
offers the available catalog-ready RC and asks before using it instead of
continuing with an unusable Stable release.
The manager asks for confirmation before using an RC for a target release,
applying security labels to an existing namespace, recreating an incompatible
Deployment, or replacing a legacy installation. No action argument or manual
manifest application is required.

The default namespace is `kwatch`. Set `KWATCH_NAMESPACE` when you want a
different namespace:

```bash
KWATCH_NAMESPACE=platform-monitoring \
  /bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

The default release name is `kwatch`. To run a second managed instance, give
it a distinct release name and namespace (each managed instance should have its
own namespace):

```bash
KWATCH_RELEASE=payments-monitor \
KWATCH_NAMESPACE=payments-monitoring \
  /bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

If the namespace already exists and is shared with other workloads, the manager
does not change its Pod Security labels automatically. Review the impact and
explicitly opt in only when appropriate:

```bash
KWATCH_ALLOW_NAMESPACE_LABELS=true \
  /bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

New namespaces created by the manager are marked as managed. Uninstall removes
the manager's restricted labels only from namespaces carrying that marker; it
does not alter labels on shared namespaces.

The manager downloads and applies the matching release resources itself. Do not
apply `deploy.yaml` or `config.yaml` manually: that bypasses guided Secret
handling and the security verification above.

The generated `config.yaml` contains only `${file:/config/...}` references.
The kwatch process rejects plain credentials, so the manager and runtime
enforce the same rule.

The guided provider prompts come from the versioned provider catalog shipped
with each kwatch release. Version 1 covers every supported notification
provider and its documented fields; credentials are automatically stored as
Secret-backed files. Choice groups, conditional fields, and at-least-one
destination groups are interpreted from the catalog, not hard-coded per
provider. See the website's [complete provider reference](/docs/channels/providers)
for the same catalog rendered as a field reference.

Authentication is asked before optional presentation settings, so a provider
such as Slack can use a bot token and channel instead of a webhook. Existing
managed deployments are adopted during an upgrade: their mounted Secret is
reused, and an incompatible immutable Deployment selector is repaired by
recreating only that workload.

When you edit notification providers, the manager shows the providers already
configured. You can edit or add providers, keep all of them unchanged, or
explicitly remove them. Providers you do not edit are preserved by default.
Legacy plaintext credentials are moved into Secret-backed files during
migration.
At provider and setting prompts, type `back` to discard the current partial
edit and return to the previous selection. No partial Secret is saved.

Telemetry is not a special installation question. `telemetry.enabled` is a
normal Operations setting in **Edit settings**. Fresh installs use the catalog
default, upgrades preserve the existing value, and users can change it with
the other settings.

For a pre-`v1.0.0` installation, **Uninstall legacy kwatch and fresh-install**
first validates the target release catalogs, creates a timestamped backup
Secret containing the available old configuration and workload manifests, and
displays its exact name. After explicit confirmation it uninstalls the old
namespaced resources and runs a fresh installation. No automatic settings
migration is attempted; the old configuration remains recoverable in the
backup.

## 📋 Interactive actions

Run the same command again after a `kwatch.sh`-managed installation. The menu
offers only actions valid for the detected running state:

| Choice | Use it when you want to... |
| --- | --- |
| 🔔 Configure notification | Add, remove, or change supported providers and their credentials |
| ⚙️ Configure settings | Change monitors, thresholds, or filters |
| ⬆️ Upgrade | Choose the latest stable or available release candidate |
| 🔎 Show status | Check the deployment and manager state |
| 🧰 Show capabilities | See features supported by the installed release |
| 🧹 Uninstall | Remove the kwatch workload and notification Secret |

The manager tracks the installation with labels on its resources and also
recognizes legacy app-labelled Deployments. A missing Deployment is treated as
no running installation, even when an old configuration resource remains; the
manager explains that and offers a fresh installation.

If you installed kwatch with Helm or your own manifests, keep using that method
to change its configuration. The manager is designed for installations it manages.

The manager is intentionally interactive and accepts no lifecycle action
arguments. Run it without arguments each time.

## 🔒 Safety and recovery

- The manager validates names, URLs, versions, and required permissions.
- Temporary Kubernetes and GitHub failures are retried.
- Configuration is backed up before an upgrade.
- Legacy replacement backs up the old configuration before uninstalling the
  old namespaced resources and prints the backup Secret name and namespace.
- If an upgrade rollout fails, the previous configuration is restored and the
  deployment is rolled back when possible.
- Uninstall removes the kwatch workload and its manager-owned notification
  Secret. It preserves an unowned Secret with the same name, plus
  the CRD, configuration resource, backups, and namespace so data is not
  deleted by surprise. Manager-owned RBAC is removed. Managed namespace
  security labels are removed only when the manager created and marked that
  namespace.

## 🧪 Optional monitors

TLS certificate monitoring is off by default because it needs read access to
TLS Secrets. The manager asks before enabling it and checks the ServiceAccount
permission.

Heartbeat is also off by default. Enable it only after adding an external
dead-man's-switch URL; see [Heartbeat Monitor](./heartbeat-monitor-configuration).

## 🆘 If something goes wrong

Check the current state:

```bash
kubectl get pods -n kwatch
kubectl logs -n kwatch deployment/kwatch
```

Run the manager again and choose **Show status** or **Configure settings**.
For a fully scripted install, use the [installation guide](./installation).
