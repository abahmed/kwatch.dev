# kwatch messaging spec

One source for the README, kwatch.dev, docs.kwatch.dev and app.kwatch.dev.
The kwatch README (abahmed/kwatch#557), the home page (#29) and the docs
(#30) follow it. Change this file first, then the surfaces.

## 1. Headline, subhead, plain-language line

- Headline: `Fifty alerts. One cause.`
- Subhead: `kwatch runs inside your Kubernetes cluster, traces every failure back to what started it, and sends one message: what broke, why, who changed it, and what to do next.`
- Plain-language line: `When something breaks in your Kubernetes cluster, kwatch tells you what broke, why, and what to do, in Slack, Discord, email and 50+ other channels.`

## 2. The six benefits (canonical names, order and copy)

The data benefit is second, right after Root cause first. This order applies
to every surface: README, home, docs, app, social cards.

| Emoji | Name | One-line copy |
| --- | --- | --- |
| 🔍 | Root cause first | kwatch follows a failure upstream and names the one cause. |
| 🔒 | Your data stays in your cluster | kwatch analyzes events and logs where they live. |
| 🔕 | Quiet by default | One message, then silence until something new is true. |
| 🕵️ | Who changed what | See who changed what, and when. |
| 👉 | The next step | Every message ends with the command to run. |
| 📣 | 50+ channels | Slack, Teams, PagerDuty, email, webhooks and more. |

### Data section spec (🔒 Your data stays in your cluster)

- Section line (bold, also the section heading under the hero on
  kwatch.dev): `Root cause, without your data leaving the cluster.`
- One-line copy: `kwatch analyzes events and logs where they live.`
- Small print, factual, directly under the line, in text-muted:
  `Only optional anonymous usage stats and Pro license checks reach kwatch.dev. Never cluster names, pod names, logs or events. Alerts go only to the channels you set up.`
- Do not claim "nothing leaves", "air-gapped" or "offline". Do not name
  competitors. Exact wording was approved; do not reword.

### Surfaces to update

- [ ] kwatch README: benefits list order; 🔒 heading and bold line in the data
      section; small print under it.
- [ ] kwatch.dev home: benefits grid order and copy (BenefitIcon, no emoji);
      new section under the hero with the bold line as its heading, the
      one-line copy and the small print.
- [ ] docs intro: benefits order and copy; docs data page (what stays, what
      is sent) uses the same small print.
- [ ] kwatch.dev Pro page: data point per `specs/pro-page.md`.
- [ ] app.kwatch.dev: any benefits list follows the new order.
- [ ] Check each claim against the code with kwatch-core before merging.

## 3. Emoji rules

- README and docs headings: one emoji per heading, at the start. Set:
  🎯 incident, 🧭 new to Kubernetes, ✨ why, ⚙️ how it works, 🔎 what it
  catches, 🚀 install, ⭐ editions and star us, 🔑 get Pro, 🔒 data, ❓ FAQ,
  📏 tested, 🤝 contributing, 🛡️ security, 💬 community, 📄 license.
- Benefits always use the six emojis above. Severity in sample output keeps
  🔴 page, 🟠 notify, 🟡 low, ✅ resolved (real kwatch output only).
- Tables: no emoji except ✅ and the dash for "not included".
- kwatch.dev and app.kwatch.dev: no emoji (brand rule). Use the six line
  icons in `apps/web/src/components/BenefitIcon.astro` (24px grid, 2px
  stroke, no fill, `currentColor`, never Signal) for the same six benefits,
  same names and copy. They are Junction-style: strokes that meet at a
  point. docs.kwatch.dev follows the README (emoji in headings, none in body
  prose).

## 4. Glossary (canonical definitions)

- Cluster: the group of machines that runs your apps.
- Node: one machine in the cluster.
- Pod: a running copy of an app.
- Namespace: a named area of the cluster, often one per team or app.
- CrashLoopBackOff: a pod keeps starting, failing and restarting.
- OOMKilled: a pod used more memory than allowed and was stopped.
- RBAC: Kubernetes permissions. It decides what kwatch may read.
- Helm: a package manager for Kubernetes, an alternative way to install.
- CRD: a custom resource definition, an extra kind of object that a tool
  adds to the cluster.

Explain on first use per page, or link to the docs glossary at
https://docs.kwatch.dev/glossary (anchors `#pod`, `#node`, `#namespace`,
`#crashloopbackoff`, `#oomkilled`, `#rbac`, `#helm`, `#crd`, `#cluster`).

## 5. How it works in 30 seconds (exact wording)

1. Install: Run one command. It asks a few questions.
2. It watches: kwatch runs as one small pod in your cluster and keeps a live
   map of what depends on what.
3. You hear: When something breaks you get one clear message: what broke,
   why, and what to do.

## 6. Install framing

- Installer: "One command, and it walks you through it." Always first.
- Helm: "Already use Helm?" with the chart as the alternative. RBAC modes,
  values and Secrets access live below, collapsed.
- Command: `/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"`
- Licenses are managed only through the installer's License / Pro menu.

## 7. Editions

- Community: free forever, no account, no key.
- Pro: free during early access. Each license is free for 3 months and we
  may renew it. One license runs one cluster; up to 2 per account or
  company. No payment details. If that ever changes, you will hear well in
  advance.
- Get a key at app.kwatch.dev, then installer > License / Pro > Add or
  replace key.
- When a Pro license ends, kwatch falls back to Community. Alerts never stop.

## 8. Numbers and words to avoid

- Channels: always "50+". Never an exact count.
- Never: "trial", prices or a Price row, "open source" (say "source
  available", ELv2), "free forever" for Pro.
- Do not promise anything not in the code; check with kwatch-core.
