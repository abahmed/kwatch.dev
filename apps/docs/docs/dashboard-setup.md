---
sidebar_position: 2
title: "kwatch dashboard setup with Helm, GitOps or your own Ingress"
sidebar_label: Dashboard setup (Helm)
description: Turn on the kwatch dashboard with Helm values, keep its password in your own Secret for GitOps, and point your own Ingress or route at the dashboard Service.
keywords: [kwatch dashboard Helm, dashboard.enabled, existingSecret, Argo CD, Flux, Ingress, trustedProxies]
---

# 🧩 Dashboard setup with Helm <span className="kw-pro">Pro</span>

:::info Pro
The dashboard is part of kwatch Pro, which is free during early access. It needs kwatch v1.2 or newer.
:::

The easiest way to turn on and share the dashboard is the installer's
**Dashboard** menu: see [Dashboard](/dashboard). This page is for people who
manage kwatch with Helm (a package manager for Kubernetes) or GitOps (keeping
your settings in Git) and want to set it up by hand. For a first
install, use the installer; Helm is the alternative path.

## What the chart gives you

When you set `dashboard.enabled: true`, the chart:

- Starts the dashboard on its own port (`8061` by default), separate from the
  health port.
- Creates a ClusterIP Service named `<release>-dashboard`, with a port named
  `dashboard`.
- Creates a Secret named `<release>-dashboard`, empty at first. The first time
  kwatch starts, it writes two keys into it: `password` (what people type to
  sign in) and `token` (what scripts send to the
  [Dashboard API](/dashboard-api)). They stay the same across upgrades.

The chart does not open the dashboard to the outside. You decide how people
reach it, which is the next section.

## Local use

```yaml
dashboard:
  enabled: true
```

Give kwatch a moment to start, then read the password and connect with a
port-forward:

```bash
kubectl -n kwatch get secret kwatch-dashboard -o jsonpath='{.data.password}' | base64 -d
kubectl -n kwatch port-forward svc/kwatch-dashboard 8061:8061
```

Open `http://localhost:8061` and sign in. Replace `kwatch` and the Secret name
if your namespace or release name differs.

## Share it with your team

Point your own Ingress, Gateway route, OpenShift Route or load balancer at the
Service `<release>-dashboard`, port name `dashboard`. Then tell kwatch which
addresses your Ingress, Gateway or proxy connects from:

```yaml
dashboard:
  enabled: true
  trustedProxies:
    - 10.244.0.0/16
```

`trustedProxies` is a list of addresses or ranges (CIDRs). Use the range your
cluster gives pods when the Ingress or Gateway runs inside the cluster, or a
smaller range if you know it. With any entry, or with `tls.secretName`, kwatch
treats the dashboard as shared: it refuses sign-in over plain http and marks
the sign-in cookie Secure. With neither, it is local only, reached through a
port-forward over http.

| Your setup | Set |
|---|---|
| An Ingress, route or proxy ends https and passes the traffic on to kwatch | `trustedProxies: [<its addresses>]` |
| kwatch serves https itself (load balancer or NodePort with nothing in front) | `tls.secretName: <your TLS Secret>` |

List only the proxy's addresses, and make sure it is the sole way in from
outside the cluster. kwatch believes the `X-Forwarded-Proto` and
`X-Forwarded-For` headers only from those addresses. With them, kwatch counts
failed sign-ins per real client. Without them, everyone behind the Ingress
shares one address.

For `tls.secretName`, create a `kubernetes.io/tls` Secret (keys `tls.crt` and
`tls.key`) in the kwatch namespace. kwatch picks up renewals without a restart.

Here is a minimal Ingress that works with `trustedProxies`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kwatch-dashboard
  namespace: kwatch
spec:
  ingressClassName: nginx
  tls:
    - hosts: [kwatch.example.com]
      secretName: kwatch-dashboard-tls
  rules:
    - host: kwatch.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kwatch-dashboard
                port:
                  name: dashboard
```

If you use NetworkPolicies, turn them on and list who may
reach the dashboard port, such as your ingress controller:

```yaml
networkPolicy:
  enabled: true
dashboard:
  networkPolicyFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
```

## GitOps: set your own Secret

By default the chart ships the Secret empty and kwatch fills in the password
and token itself the first time it starts, so every render (Argo CD, Flux,
`helm template`) is the same and nothing changes on a sync. If you would
rather keep the password in your own Secret, for example a sealed or external
one, create it yourself and name it:

```yaml
dashboard:
  enabled: true
  existingSecret: kwatch-dashboard-credentials
```

The Secret needs the keys `password` and `token`. Keep it out of Git in plain
text. If you change the Secret, the change takes effect when kwatch restarts. The installer's password format is
16 letters and digits in four groups, like `7K4M-QX9P-2HVD-T6RE`, but you can
choose your own. People can type it with or without dashes, in any
case.

## Good to know

- Sign-ins last 12 hours. Changing the password, or any kwatch restart,
  signs everyone out.
- After 10 wrong passwords in a minute from one client, sign-in waits until
  the next minute.
- With Helm, the Secret that kwatch filled in is kept when you uninstall or turn the dashboard
  off, so a reinstall keeps the same password. Delete the Secret to forget it.
  (The installer's **Turn off** deletes it.)

## Values

| Value | What it does | Default |
|---|---|---|
| `dashboard.enabled` | Turn on the dashboard and its Service | `false` |
| `dashboard.port` | Dashboard port; must differ from `healthCheck.port` | `8061` |
| `dashboard.trustedProxies` | Addresses or ranges of the Ingress, Gateway or proxy in front of kwatch; any entry makes the dashboard https only | `[]` (local only) |
| `dashboard.tls.secretName` | TLS Secret kwatch serves https from itself | empty |
| `dashboard.existingSecret` | Your Secret with `password` and `token` | empty |
| `dashboard.networkPolicyFrom` | Extra NetworkPolicy peers allowed to reach the port | `[]` |

The full chart reference lives with the chart, in `deploy/chart/README.md` in
the [kwatch repository](https://github.com/abahmed/kwatch). For Community
installs the dashboard stays off and the port stays closed.
