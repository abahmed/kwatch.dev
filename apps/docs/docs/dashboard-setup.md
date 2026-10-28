---
sidebar_position: 2
title: "kwatch dashboard setup with Helm, GitOps or your own Ingress"
sidebar_label: Dashboard setup (Helm)
description: Turn on the kwatch dashboard with Helm values, keep its password in your own Secret for GitOps, and point your own Ingress or route at the dashboard Service.
keywords: [kwatch dashboard Helm, dashboard.enabled, existingSecret, Argo CD, Flux, Ingress, trustProxy]
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
- Creates a Secret named `<release>-dashboard` with two keys: `password` (what
  people type to sign in) and `token` (what scripts send to the
  [Dashboard API](/dashboard-api)). It generates both and keeps them across
  upgrades.

The chart does not open the dashboard to the outside. You decide how people
reach it, which is the next section.

## Local use

```yaml
dashboard:
  enabled: true
```

Read the password, then connect with a port-forward:

```bash
kubectl -n kwatch get secret kwatch-dashboard -o jsonpath='{.data.password}' | base64 -d
kubectl -n kwatch port-forward svc/kwatch-dashboard 8061:8061
```

Open `http://localhost:8061` and sign in. Replace `kwatch` and the Secret name
if your namespace or release name differs.

## Share it with your team

Point your own Ingress, Gateway route, OpenShift Route or load balancer at the
Service `<release>-dashboard`, port name `dashboard`. Then tell kwatch that
people arrive over https:

```yaml
dashboard:
  enabled: true
  mode: shared
  trustProxy: true
```

`mode: shared` makes kwatch refuse sign-in over plain http and mark the sign-in
cookie Secure. It also needs one way to know the visit was https, or the chart
stops with a clear message:

| Your setup | Set |
|---|---|
| An Ingress, route or proxy ends https and handles https and passes the traffic on to kwatch | `trustProxy: true` |
| kwatch serves https itself (load balancer or NodePort with nothing in front) | `tls.secretName: <your TLS Secret>` |

Use `trustProxy` only when that proxy is the sole way in from outside the
cluster, because kwatch then believes the `X-Forwarded-Proto` and
`X-Forwarded-For` headers it sends. With it set, kwatch counts failed sign-ins
per real client. Without it, everyone behind the Ingress shares one address.

For `tls.secretName`, create a `kubernetes.io/tls` Secret (keys `tls.crt` and
`tls.key`) in the kwatch namespace. kwatch picks up renewals without a restart.

Here is a minimal Ingress that works with `trustProxy: true`:

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

By default the chart keeps the generated password by looking up the existing
Secret when you upgrade. Argo CD, Flux with post-rendering and `helm template`
cannot look it up, so each sync would make a new password and sign everyone
out. With GitOps, create the Secret yourself and name it:

```yaml
dashboard:
  enabled: true
  existingSecret: kwatch-dashboard-credentials
```

The Secret needs the keys `password` and `token`. Use a sealed or external
secret to keep it out of Git in plain text. The installer's password format is
16 letters and digits in four groups, like `7K4M-QX9P-2HVD-T6RE`, but you can
choose your own. People can type it with or without dashes, in any
case.

## Good to know

- Sign-ins last 12 hours. Changing the password, or any kwatch restart,
  signs everyone out.
- After 10 wrong passwords in a minute from one client, sign-in waits until
  the next minute.
- With Helm, the generated Secret is kept when you uninstall or turn the dashboard
  off, so a reinstall keeps the same password. Delete the Secret to forget it.
  (The installer's **Turn off** deletes it.)

## Values

| Value | What it does | Default |
|---|---|---|
| `dashboard.enabled` | Turn on the dashboard and its Service | `false` |
| `dashboard.port` | Dashboard port; must differ from `healthCheck.port` | `8061` |
| `dashboard.mode` | `local` for a port-forward, `shared` for https only | `local` |
| `dashboard.trustProxy` | Trust the proxy's forwarded headers | `false` |
| `dashboard.tls.secretName` | TLS Secret kwatch serves https from itself | empty |
| `dashboard.existingSecret` | Your Secret with `password` and `token` | empty |
| `dashboard.networkPolicyFrom` | Extra NetworkPolicy peers allowed to reach the port | `[]` |

The full chart reference lives with the chart, in `deploy/chart/README.md` in
the [kwatch repository](https://github.com/abahmed/kwatch). For Community
installs the dashboard stays off and the port stays closed.
