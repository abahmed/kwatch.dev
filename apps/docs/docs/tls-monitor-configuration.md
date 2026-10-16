---
sidebar_position: 16
title: TLS Monitor
description: configure kwatch to detect expiring TLS certificates stored in Kubernetes Secrets
keywords: [kwatch, kubernetes, configuration, monitor, tls, certificate, ssl, expiry]
pagination_next: null
pagination_prev: null
---

# 🔒 TLS certificate monitor

:::info Pro
This feature is part of kwatch Pro, which is free during early access. See [Community vs Pro](/docs/editions).
:::

TLS certificates protect HTTPS connections. This detector warns before
a certificate stored in a Kubernetes Secret expires.

Watches for TLS/SSL certificates in `kubernetes.io/tls` Secrets that are about
to expire, or are invalid. It needs Secret read access, which is on by default
(`watch.secrets: true`); with `watch.secrets: false` kwatch reports that it
cannot verify certificates.

## How detection works

1. kwatch reads the `kubernetes.io/tls` Secrets it watches
2. Parses the `tls.crt` field (PEM-encoded X.509 certificate)
3. Checks `NotAfter` against the current time and reports expiring or expired certificates

## Settings

There are no TLS settings: certificate detection is part of kwatch Pro and always on, and the earlier `tlsMonitor.*` keys no longer exist. Use `silences` for a certificate you intentionally leave expired.

## Required RBAC

Certificate detection needs read access to `secrets`. The installer and the Helm chart grant it by default; `watch.secrets: false` removes it. See [Kubernetes permissions](/docs/general-configuration#-kubernetes-permissions-and-graceful-degradation).

## Multiple certificates in one Secret

If a Secret contains multiple certificates (e.g. both RSA and ECDSA), kwatch
checks all of them and alerts on the earliest expiry.
