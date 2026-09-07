---
sidebar_position: 2
title: Installation
description: install and manage kwatch on Kubernetes with the interactive kwatch.sh manager and Secret-backed credentials
keywords: [kwatch, kubernetes installation, kwatch.sh, Kubernetes monitoring, cluster alerts, Kubernetes Secret]
pagination_next: kwatch-manager
pagination_prev: getting-started
---

# 🚀 Installation

> 🧭 **Supported path:** use `kwatch.sh` for installation, upgrades, configuration,
> and removal. It creates the Secret, applies the matching release resources,
> enables the namespace security labels, and verifies the workload posture.
> Do not apply `deploy.yaml` or `config.yaml` manually.

For the normal lifecycle, use the manager:

| You want to... | Use |
| --- | --- |
| Try kwatch with the fewest decisions | 🧭 [Interactive manager](#-interactive-manager-recommended) |
| Need to inspect the generated resources | 🔍 [Release artifacts](https://github.com/abahmed/kwatch/tree/main/deploy) |

## ✅ Before you begin

You need:

- A supported Kubernetes cluster.
- `kubectl` configured for that cluster.
- `curl` for the manager.

Check access before installing:

```bash
kubectl cluster-info
```

kwatch runs as one small pod and reads cluster resources through Kubernetes
RBAC. The official manifests include the required read-only permissions. TLS
monitoring needs additional Secret access and is off by default.

## 🧭 Interactive manager (recommended)

Run one command:

```bash
/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"
```

The manager will:

1. 🧭 Ask which Kubernetes cluster to manage.
2. 🔎 Check the selected cluster and your permissions.
3. 🎯 Ask where alerts should go.
4. 🔐 Store notification credentials in a Secret.
5. 🧱 Install the CRD and kwatch workload.
6. ✅ Wait for kwatch to become ready.

Run the same command later to configure, upgrade, check status, or uninstall.
The manager is fully interactive: select the cluster first, then it detects
the running kwatch version and shows only the actions valid for that state.
Read the [kwatch.sh manager guide](/docs/kwatch-manager) for every menu option,
legacy migration, recovery behavior, and advanced usage.

The release artifacts below are for inspection only. The supported lifecycle is
through `kwatch.sh`; do not apply or delete the files directly.

## 📦 Release artifacts (inspection only)

The repository contains the CRD, Deployment, RBAC, chart, and catalog files so
that users can audit exactly what the manager applies. They are not a second
supported installation path. Do not apply or delete these files directly: the
manager owns namespace safety, Secret references, upgrades, rollback behavior,
and ownership-aware cleanup.

Run the interactive manager again for the lifecycle of every manager-created
installation. If a deployment must be customized beyond the manager's
options, treat it as an unsupported fork and keep it separate from a
`kwatch.sh`-managed release.

The main environment variables inside the workload are:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CONFIG_FILE` | `/config/config.yaml` | Config file path |
| `POD_NAMESPACE` | detected from the Pod | Namespace for persisted state |
| `GOMEMLIMIT` | based on the resource limit | Soft Go memory limit |

## 🔎 Troubleshooting

### The pod is not ready

```bash
kubectl describe pod -n kwatch -l app=kwatch
kubectl logs -n kwatch deployment/kwatch
```

Look for an invalid provider credential, a missing permission, or a Kubernetes
API access problem.

### Check the health endpoint

```bash
kubectl port-forward -n kwatch deployment/kwatch 8060:8060
curl http://localhost:8060/healthz
curl http://localhost:8060/readyz
```

Both endpoints should return `ok`.

### Change configuration safely

Run `kwatch lint` before applying a changed config. Use `kwatch lint --check`
when you also want to test credentials for providers that support checks. See the [configuration
reference](/docs/general-configuration).
