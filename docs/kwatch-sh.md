---
sidebar_position: 2
title: kwatch.sh manager reference
description: Install, configure, upgrade, verify, and uninstall kwatch with the interactive kwatch.sh manager.
keywords: [kwatch.sh, Kubernetes installation, kwatch manager, Kubernetes Secrets]
---

# 🧭 The `kwatch.sh` manager

`kwatch.sh` is the easiest way to install and manage kwatch. It is a small
Bash script that uses your existing `kubectl` access; it does not install a
second package manager.

## 🚀 Start here

Requirements:

- `kubectl` connected to a Kubernetes cluster
- `curl`
- permission to install namespace-scoped resources and cluster-scoped CRD/RBAC
  resources

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

To inspect it before running it:

```bash
curl -fsSL https://kwatch.dev/kwatch.sh -o kwatch.sh
less kwatch.sh
bash kwatch.sh
```

The script is plain Bash and is published in
[`kwatch.dev/static/kwatch.sh`](https://github.com/abahmed/kwatch.dev/blob/main/static/kwatch.sh).

The manager checks the cluster, lets you configure zero, one, or several alert
providers, stores credentials in a Kubernetes Secret, installs the CRD and
hardened workload, and
waits for the deployment to become ready. It also verifies restricted Pod
Security labels, non-root/read-only execution, dropped capabilities,
`RuntimeDefault` seccomp, and the `0400` Secret volume mode before reporting
success. It applies the namespace's restricted Pod Security labels itself, so
the normal install does not require a separate `kubectl apply` or label step.
Choosing no provider is valid for a monitor-only installation; providers can be
added later with `configure-alert`.

This is the supported installation path. It downloads and applies the matching
release resources itself; do not apply `deploy.yaml` or `config.yaml` manually,
because that bypasses the guided Secret handling and security verification.

## 🎯 Choose a cluster safely

If your kubeconfig has more than one context, the manager shows the contexts
and asks you to choose one. It passes that context explicitly to `kubectl`; it
does not change your current context.

## 📋 Interactive actions

The manager is intentionally run without lifecycle arguments:

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

After selecting a cluster, it detects the running kwatch Deployment and shows
only actions that match the detected state:

- No running Deployment: install or exit.
- A running version below `v1.0.0`: uninstall legacy kwatch and fresh-install
  or exit.
- A healthy running version `v1.0.0` or newer: upgrade, edit notification
  providers, edit settings, view capabilities, view status, or uninstall.
- An unhealthy or unidentified Deployment: repair by upgrading, view status,
  or uninstall.

Configuration resources without a running Deployment do not count as an
installation. They are preserved and the manager explains that a fresh
installation is available.

## 🔐 What the manager protects

- Credentials go into a Secret, not a ConfigMap.
- The generated `config.yaml` contains only `${file:/config/...}` references;
  a plain credential is rejected by the kwatch process.
- The manager validates names, versions, and required permissions.
- Config is backed up before an upgrade.
- A failed rollout restores the previous config and attempts a rollback.
- Optional TLS monitoring is enabled only after you approve its Secret access.
- Uninstall preserves the CRD, configuration resource, backups, and namespace.

## 🧪 Version-aware settings

The manager loads the configuration, feature, and guided-provider catalogs for
the installed release. It caches each catalog in the cluster and only reuses a
cache entry when it is tagged for that exact release. There are no embedded
catalog fallbacks in `kwatch.sh`; if the matching artifact and cache are both
unavailable, catalog-dependent actions stop with an explicit error. The provider catalog covers
every supported notification provider, defines each documented prompt, and
marks whether its value must be stored as a Secret file. The guided flow asks
for the selected provider's authentication first, then required destinations,
then optional presentation settings. You may intentionally choose no provider
and add more than one provider in the same run.

When the latest Stable release does not publish the catalogs required by the
manager, it offers a catalog-ready Release Candidate and asks before using it.
The manager confirms target-release selection, legacy replacement, namespace
security changes, and any Deployment recreation before making those changes.

When an older kwatch Deployment is found, the manager reuses its mounted
configuration Secret when one is present before writing changes. During an
update it preserves the old immutable selector; if Kubernetes still rejects
the workload, it
recreates only that Deployment and keeps the configuration resource and Secret.
For ConfigMap-based legacy installs, **Uninstall legacy kwatch and
fresh-install** validates the target catalogs, creates a timestamped backup
Secret, displays its name, and then waits for explicit confirmation before
removing the old namespaced resources and performing a fresh installation. No
automatic settings migration is attempted. Editing providers lists the current
providers and preserves providers you did not edit unless you explicitly
confirm removal.

Telemetry is a normal `telemetry.enabled` setting under **Edit settings**. It
is not asked during installation or provider configuration; fresh installs use
the catalog default and upgrades preserve the existing value.

Provider and settings prompts support `back`. It discards the current partial
edit and returns to the previous menu without saving a partial configuration.

The release workflow generates these catalogs from Go definitions. When a new
setting or guided provider is added, update its source definition and regenerate
the release artifacts.

## 🆘 Troubleshooting

```bash
kubectl get pods -n kwatch
kubectl logs -n kwatch deployment/kwatch
```

Run the manager again and choose **Show status**. For manual installation and
Helm, see [Installation](/docs/installation).
