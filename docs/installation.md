---
sidebar_position: 2
title: Installation
description: a complete guide to deploy kwatch on your Kubernetes cluster
keywords: [kwatch, kubernetes, install, deploy, cluster, monitoring, helm, kubectl]
pagination_next: null
pagination_prev: null
---

# Installation

## Prerequisites

- A Kubernetes cluster (v1.21+)
- `kubectl` configured with cluster access
- (Optional) Helm 3+ for Helm installation

kwatch needs the following RBAC permissions (all included in the deploy manifest):

| Resource | Verbs | Purpose |
|----------|-------|---------|
| `pods`, `pods/log`, `events`, `nodes`, `nodes/proxy`, `persistentvolumeclaims` | get, watch, list | Monitor resources |
| `namespaces` | get, list, watch | Multi-namespace support |
| `daemonsets`, `statefulsets`, `deployments`, `replicasets` | get, watch, list | Owner resolution |
| `horizontalpodautoscalers` | get, watch, list | HPA monitoring |
| `jobs`, `cronjobs` | get, watch, list | Job/CronJob monitoring |
| `configmaps` | get, create, update, patch | State persistence |
| `secrets` | get, list, watch | TLS monitoring (optional, uncomment) |
| `kwatchconfigs` | get, watch, list | CRD live reload (optional, uncomment) |

---

## 📦 Method 1: Helm (recommended)

### Add the repository

```shell
helm repo add kwatch https://kwatch.dev/charts
helm repo update
```

### Create a values file

```yaml
# values.yaml
config:
  alert:
    slack:
      webhook: "https://hooks.slack.com/services/..."
  app:
    clusterName: "production-us-east"
```

### Install

```shell
helm install kwatch kwatch/kwatch \
  --namespace kwatch \
  --create-namespace \
  --values values.yaml \
  --version 0.11.0-rc.6
```

> ⚠️ **Release candidates have no Helm chart** — only the stable release publishes to the
> `kwatch/kwatch` chart repo. As of the current preview build, `0.11.0` is still a release
> candidate; for it, use the kubectl method below. This Helm command is documented for the
> stable release (e.g. `0.10.5`) once the RC ships.

### Verify

```shell
kubectl get pods -n kwatch
# NAME                      READY   STATUS    RESTARTS   AGE
# kwatch-6f9b7c9d8f-abc12   1/1     Running   0          30s
```

> The pod runs a single container, `kwatch` — one small pod, no storage.

### Upgrade

```shell
helm repo update
helm upgrade kwatch kwatch/kwatch \
  --namespace kwatch \
  --values values.yaml
```

### Uninstall

```shell
helm uninstall kwatch --namespace kwatch
```

---

## 🐙 Method 2: kubectl (manual)

### Step 1: Create the configuration

Download the example config:

```bash
curl -L https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/config.yaml -o config.yaml
```

Edit `config.yaml` and configure at least one alert provider:

```yaml
data:
  config.yaml: |
    alert:
      slack:
        webhook: "https://hooks.slack.com/services/..."
```

Remove or comment out providers you don't use. See
[Channels](/docs/channels) for all supported providers.

Apply the config:

```bash
kubectl apply -f config.yaml
```

### Step 2: Deploy kwatch

```bash
kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/deploy.yaml
```

### Step 3: Verify

```bash
kubectl get pods -n kwatch
# NAME                      READY   STATUS    RESTARTS   AGE
# kwatch-6f9b7c9d8f-abc12   1/1     Running   0          30s

kubectl logs -n kwatch deployment/kwatch
# I0629 10:00:00.000000       1 main.go:79] "kwatch v0.11.0-rc.6 ..."
```

### Step 4: Test it

```bash
# Port-forward the health endpoint
kubectl port-forward -n kwatch deployment/kwatch 8060:8060

# Send a test alert
curl -X POST http://localhost:8060/test-alert
```

If everything is set up correctly, you should receive a test notification
on your configured channel.

> 💡 `/test-alert` (and `/incidents`, `/deadletters`) require
> `healthCheck.diagnostics: true` in your config.

---

## 🔧 Method 3: Custom deployment

You can customize the deployment by downloading and editing the manifest:

```bash
curl -L https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/deploy.yaml -o deploy.yaml
# Edit deploy.yaml (change resources, env vars, etc.)
kubectl apply -f config.yaml
kubectl apply -f deploy.yaml
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_FILE` | `/config/config.yaml` | Path to the config file |
| `POD_NAMESPACE` | (field ref) | Used for ConfigMap state access |
| `GOMEMLIMIT` | (resource field ref) | Go memory limit (soft) |

---

## ✅ Verifying the installation

### Check pod status

```bash
kubectl get pods -n kwatch -o wide
```

The container (`kwatch`) should be `Running` and `Ready 1/1`.

### Check health endpoint

```bash
kubectl port-forward -n kwatch deployment/kwatch 8060:8060 &
curl http://localhost:8060/healthz
# ok
curl http://localhost:8060/readyz
# ok
curl http://localhost:8060/health
# {"status": "ok"}
```

### View active incidents

```bash
# Requires diagnostics: true in config
curl http://localhost:8060/incidents
# []  (empty array = all clear)
```

### Check Prometheus metrics

```bash
curl http://localhost:8060/metrics | grep kwatch
```

---

## ⬆️ Upgrading

### Upgrading within a release line

1. Check the [changelog](https://github.com/abahmed/kwatch/releases) and the
   [release notes](https://github.com/abahmed/kwatch/blob/main/RELEASES.md)
2. Update config if needed (deprecated `Ignore*` fields → `silences`)
3. Upgrade via Helm or re-apply `deploy.yaml`

---

## 🧹 Clean up

### Helm

```shell
helm uninstall kwatch --namespace kwatch
kubectl delete namespace kwatch
```

### kubectl

```shell
kubectl delete -f https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/config.yaml
kubectl delete -f https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/deploy.yaml
```
