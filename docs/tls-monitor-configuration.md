---
sidebar_position: 16
title: TLS Monitor
description: TLS certificate expiry monitor configuration with detection details
keywords: [kwatch, kubernetes, configuration, monitor, tls, certificate, ssl, expiry]
pagination_next: null
pagination_prev: null
---

# 🔒 TLS Certificate Monitor

Watches for TLS/SSL certificates in `kubernetes.io/tls` Secrets that are about
to expire. **This monitor is off by default** because it requires an additional
RBAC permission (`secrets`).

## How detection works

1. kwatch lists all Secrets of type `kubernetes.io/tls` in watched namespaces
2. Decodes and parses the `tls.crt` field (PEM-encoded X.509 certificate)
3. Checks `NotAfter` against current time
4. If less than `threshold` days away → alert with `normal` severity
5. If less than `criticalThreshold` days away → alert with `high` severity
6. Runs every 24 hours

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tlsMonitor.enabled` | `bool` | `false` | Enable TLS certificate monitoring. |
| `tlsMonitor.threshold` | `int` (days) | `30` | Days before expiry to warn. |
| `tlsMonitor.criticalThreshold` | `int` (days) | `3` | Days before expiry to raise severity to `high`. |

## Required RBAC

The TLS monitor needs `secrets` access. Uncomment these lines in your
`deploy.yaml` ClusterRole:

```yaml
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
```

## Example

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kwatch
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kwatch
  namespace: kwatch
data:
  config.yaml: |
    tlsMonitor:
      enabled: true
      threshold: 30
      criticalThreshold: 3
```

## Multiple certificates in one Secret

If a Secret contains multiple certificates (e.g. both RSA and ECDSA), kwatch
checks **all** of them and alerts on the **earliest** expiry.
