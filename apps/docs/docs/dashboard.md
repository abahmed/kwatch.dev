---
sidebar_position: 1
title: "kwatch dashboard: see your issues in a browser"
sidebar_label: Dashboard
description: Turn on the kwatch dashboard from the installer, see active and resolved issues in your browser, share it with your team, and manage its password.
keywords: [kwatch dashboard, Kubernetes dashboard, incident dashboard, kwatch Pro, kwatch.sh, share dashboard]
---

# 🖥️ Dashboard <span className="kw-pro">Pro</span>

:::info Pro
The dashboard is part of kwatch Pro, which is free during early access. It needs kwatch v1.2 or newer. See [Community vs Pro](/editions).
:::

The dashboard is a read-only web page that shows what kwatch sees: the issues
that need you now, the full story of each one, what recovered, and whether
kwatch itself is healthy. It changes nothing in your cluster, so it is a good
page to open when someone asks "is anything wrong?"

## What you can see

- **Active issues.** Everything that needs attention, most urgent first. Filter
  by namespace, by how urgent it is, or by searching for a name. When nothing
  is wrong, the page says all clear.
- **Issue detail.** Click an issue to see the likely cause in plain words, the
  suggested fix with commands you can copy, a timeline of what happened, and the
  log lines kwatch captured.
- **Resolved.** Issues that recovered in the last 7 days, so you can check that
  a fix held.
- **kwatch status.** The version, when kwatch last checked your cluster, which
  namespaces it watches, and whether each alert channel is delivering.

## Turn it on

Run the installer and choose **Dashboard** from the menu:

```bash
bash <(curl -fsSL https://kwatch.dev/kwatch.sh)
```

The Dashboard entry shows its state next to it: off, on and local only, or
shared. Choose **Turn on, local only** and the installer:

1. Turns the dashboard on and restarts kwatch.
2. Prints a link and a password. Save the password in your password manager.
3. Opens the dashboard in your browser.

Local only means nothing leaves your computer. The dashboard opens at a
`localhost` address while the installer window stays open. Press Ctrl-C to
close the connection; the dashboard stays on, and **Open the dashboard** in the
menu connects you again.

:::tip Persistent storage
Turning the dashboard on restarts kwatch. If kwatch keeps its data in a
temporary volume, it forgets the issues it was tracking and finds them again on
its next check. The installer tells you before it restarts in that case.
:::

If you see "part of Pro" when you open the menu, add your key first from
**License / Pro**. If you see "doesn't have the dashboard yet", upgrade kwatch
from the main menu; the dashboard needs v1.2 or newer.

## Share it with your team

Choose **Share with my team**. The installer looks at your cluster and shows only
the ways that will work there. It creates nothing until you confirm, and it
never shares anything if you just press Enter, because the menu starts on
**Local only**. Every shared way uses https, and kwatch refuses to sign anyone
in over plain http.

You need to control the address you pick (for example `kwatch.example.com`) at
your DNS provider. The installer prints the exact DNS record to add. Some
setups let you also limit access to certain IP addresses; the password is still
needed.

### Local only

Opens in your browser while the installer window stays open. Pick this to try
the dashboard, or when only you need it.

### Ingress

An Ingress is your cluster's front door for web traffic. Pick this when other
apps in the cluster already have a normal https address. The installer finds
your ingress controller (nginx, Traefik, HAProxy, Contour, Kong, AWS ALB, GKE,
Azure Application Gateway and others), and can get a certificate for you from
cert-manager, use a certificate Secret you already have, or make a self-signed
one for a test. It also supports Tailscale and ngrok ingress, which give the
dashboard an address without a DNS step.

### Gateway API or Istio

Pick this when your cluster uses Gateways or Istio rather than Ingress. The
installer adds an HTTPRoute (Gateway API) or a VirtualService (Istio) to a
Gateway you choose. It never edits the Gateway itself.

### OpenShift Route

Pick this on OpenShift. The default address is under your cluster's apps
domain, which already has a certificate.

### Load balancer

Pick this when you have no ingress and your cloud (or MetalLB or kube-vip) can
give kwatch its own address. kwatch handles https itself, using the certificate
you choose. You can make it reachable from the internet or only from inside
your network.

### NodePort

Opens one port on each machine in the cluster, and kwatch handles https itself.
Pick this for a small cluster without a load balancer. Point your address at
several machines so the link survives one going away.

### Cloudflare Tunnel or another outside proxy

Pick this only if you already run something outside the cluster that adds https
for you. kwatch receives plain http from your proxy and trusts it to say the
visit was over https, so the installer asks you to type `yes` after explaining
this. Use it only when the proxy is the only way in from outside.

### Service only

kwatch creates its internal address and shows it. Pick this if you will set up
access yourself. The next page, [Dashboard setup](/dashboard-setup), shows how.

## Show or reset the password

- **Show my access link and password** prints the link, and the password after
  you press Enter. For a shared dashboard it also tells you whether the
  certificate is ready.
- **Reset password** makes a new password and signs everyone out. Use it if the
  password was shared too widely or you lost it.

Anyone with the link and the password can read your issues, so share them only
with the people who should see them. A sign-in lasts 12 hours, and restarting
kwatch (an upgrade, for example) signs everyone out. After 10 wrong passwords
in a minute from one address, sign-in waits until the next minute.

## Change how it is shared

Choose **Change how it's shared** to see the current setup and move to another
way. The installer creates the new setup first, checks it, and only then
removes the old one. It only ever removes what it created; your own Ingresses,
Gateways and Secrets are left alone. **Switch to local only** takes the shared
link down and keeps your password.

## Turn it off

Choose **Turn off**. The link stops working and the password is deleted. Your
issues and alerts are not affected. If you shared the dashboard, the installer
also removes what it created for sharing. DNS records, cloud certificates and
Secrets you supplied are not touched, so remove the DNS record when you like.

## Next steps

- [Dashboard setup](/dashboard-setup) for Helm, GitOps and your own Ingress.
- [Dashboard API](/dashboard-api) to read the same data from a script.
- [Is kwatch working?](/operations/is-kwatch-working) for other ways to check on kwatch.
