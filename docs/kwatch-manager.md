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

## 🧩 What happens during installation?

1. 🔎 The manager checks that Kubernetes is reachable.
2. 🎯 You choose the cluster and notification destination.
3. 🔐 Credentials are stored as separate files in a Kubernetes Secret.
4. 🧱 The manager installs the CRD and hardened kwatch workload.
5. 🛡️ It applies restricted Pod Security labels, then verifies
   non-root/read-only
   execution, dropped capabilities, `RuntimeDefault` seccomp, and `0400`
   Secret volume permissions.
6. ✅ It waits for the deployment to become ready.

During installation and upgrade, the manager shows the newest Stable release
and, when available, the newest Release Candidate. Stable is selected by
default; choose the RC interactively when you want to test preview changes.
No version argument or manual manifest application is required.

Official release images send a small pseudonymous adoption heartbeat once a
week by default. It contains an installation ID and kwatch version only; no
feature usage or cluster inventory is collected. Disable it later from the
manager's **Configure settings** menu with `telemetry.enabled: false`.

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
Secret-backed files. See the website's [complete provider reference](/docs/channels/providers)
for the same catalog rendered as a field reference.

## 📋 Commands

Run the same command again after a `kwatch.sh`-managed installation. The menu will offer:

| Choice | Use it when you want to... |
| --- | --- |
| 🔔 Configure notification | Change any supported provider and its credentials |
| ⚙️ Configure settings | Change monitors, thresholds, or filters |
| ⬆️ Upgrade | Choose the latest stable or available release candidate |
| 🔎 Show status | Check the deployment and manager state |
| 🧰 Show capabilities | See features supported by the installed release |
| 🧹 Uninstall | Remove the kwatch workload and notification Secret |

If you installed kwatch with Helm or your own manifests, keep using that method
to change its configuration. The manager is designed for installations it manages.

You can also run a command directly:

```bash
kwatch.sh status
kwatch.sh configure-alert
kwatch.sh configure
kwatch.sh upgrade
kwatch.sh features
kwatch.sh uninstall

# Show usage without selecting a cluster
bash kwatch.sh --help
```

When using the URL form, pass the command through `bash` like this:

```bash
bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)" -- status
```

## 🔒 Safety and recovery

- The manager validates names, URLs, versions, and required permissions.
- Temporary Kubernetes and GitHub failures are retried.
- Configuration is backed up before an upgrade.
- If an upgrade rollout fails, the previous configuration is restored and the
  deployment is rolled back when possible.
- Uninstall removes the kwatch workload and its manager-owned notification
  Secret. It preserves an unowned Secret with the same name, plus
  the release's ClusterRole/ClusterRoleBinding, CRD, configuration resource,
  backups, and namespace so data is not deleted by surprise. Managed namespace
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
