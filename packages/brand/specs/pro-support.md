# Pro support spec

Owner: kwatch-designer (copy). Implementers: kwatch-core (README), kwatch-docs,
kwatch-web. Copy follows `../MESSAGING.md`. Status: draft, waiting on the
open decisions at the end.

## Research notes (patterns, not quotes)

From general knowledge of how these tools present support; not re-fetched
for this spec, so treat as direction.

- Sidekiq Pro, Plausible, Tailscale (small plans): support is a plain line
  ("email support", "direct access to the maintainer"), listed once, no
  numbers. Trust comes from a named person, not from a promise.
- Grafana, PostHog, larger vendors: tiers with response-time tables and SLAs.
  That is a team promise a solo maintainer cannot keep. Do not borrow it.
- What works for small open-core tools: say who answers, what they help with,
  what Community gets instead, and say honestly that it is a person.
- Avoid: "24/7", "enterprise-grade", "white-glove", "SLA", "guaranteed",
  "priority" without saying priority over what.

Direction for kwatch: **a named person, a narrow list of what they help with,
no clock.** "Prioritized" is honest only as "ahead of Community requests",
so write it that way.

## Positioning line

> Pro includes direct support from the maintainer.

Sub-line (use where there is room):

> Help with installation, and your feature requests and kwatch fixes come first.

## Benefit bullets (order is fixed)

1. **Installation help.** Stuck on the installer, Helm values or RBAC? Ask and
   get an answer from the maintainer.
2. **Feature requests first.** Pro requests are read and weighed ahead of
   Community ones.
3. **Fixes first.** When a Pro cluster hits a kwatch bug, it is looked at
   ahead of other open issues.

Small print, under the bullets wherever they appear:

> Support is one person, so there is no guaranteed reply time. Early access:
> this is part of Pro, which is free for now.

## Community gets

GitHub issues and Discussions, answered by the maintainer and community on a
best-effort basis. Everything in the docs. Same kwatch, same alerts.

> Community support is on GitHub, best effort.

## Channel (what exists today)

Verified in the repos:

- `kwatch-api/src/routes/support.ts`: `POST /support`, signed-in, active Pro
  license required, sends one email to `SUPPORT_INBOX` = `support@kwatch.dev`.
  3 requests per account per UTC day; no reply time promised.
- `kwatch.dev/apps/app/src/pages/Help.tsx`: **Get help** at app.kwatch.dev,
  Pro only. Non-Pro accounts see "Get help is for Pro. Community support is
  on GitHub." with an Open an issue button.
- `kwatch/.github/ISSUE_TEMPLATE/config.yml`: Discussions and issues for
  Community. No Pro-only label or category exists.
- `hello@kwatch.dev` is the general contact (privacy, terms, app).

Recommendation: **app.kwatch.dev > Get help is the Pro channel.** It proves
the license, attaches cluster facts, and keeps the address out of public
pages. Do not publish `support@kwatch.dev` as a link. Do not add a Pro GitHub
label. Surfaces link to `https://app.kwatch.dev` and say "choose Get help".

Dependency: spec `pro-readiness-rc21.md` open question 6 (does the
`support@kwatch.dev` mailbox exist and who reads it) must be answered
before any surface goes live. See decision 1.

## Exact copy per surface

Wording uses "the maintainer" because the product is solo-run today.

### README (`kwatch/README.md`, Editions)

Add a row to the editions table:

| | Community | Pro |
| --- | --- | --- |
| Support | GitHub issues and Discussions, best effort | Direct support from the maintainer: installation help, and your feature requests and fixes come first |

Add under the table, before "When a Pro license ends":

> Pro includes direct support from the maintainer. It is one person, so there
> is no guaranteed reply time. Sign in at [app.kwatch.dev](https://app.kwatch.dev)
> and choose **Get help**. Community support is on
> [GitHub](https://github.com/abahmed/kwatch/issues).

README FAQ entry:

> **Who answers support questions?**
> Community questions go to GitHub issues and Discussions, answered on a
> best-effort basis. Pro includes direct support from the maintainer:
> installation help, and your feature requests and kwatch fixes come first.
> There is no guaranteed reply time.

### Docs: Editions (`apps/docs/docs/editions.md`)

At-a-glance table, new row after Operations:

| Support | GitHub issues and Discussions, best effort | Direct support from the maintainer: installation help, feature requests and fixes first |

In the `## Pro` section, append one paragraph:

> Pro also includes direct support from the maintainer. See
> [Getting help](/getting-help).

### Docs: Getting help (`apps/docs/docs/getting-help.md`)

Replace the two bullets:

> - **Community:** open an issue on [GitHub](https://github.com/abahmed/kwatch/issues/new)
>   or start a Discussion. Issues are public, so remove anything private first.
>   Answers are best effort.
> - **Pro:** sign in to [app.kwatch.dev](https://app.kwatch.dev) and choose
>   **Get help**. You get direct support from the maintainer: help with
>   installation, and your feature requests and kwatch fixes come first.
>   Pro is free during early access.

Add after the bullets:

> kwatch is maintained by one person, so there is no guaranteed reply time.
> Attach a diagnostics file (below) to get to the cause faster.

Docs FAQ (editions or getting-help):

> **What does Pro support cover?**
> Installing and configuring kwatch, your feature requests, and problems in
> kwatch itself. It does not cover running your cluster or your applications.
> Requests are read in order of when they arrive, with Pro ahead of Community.

The last sentence is a claim the maintainer must be able to keep. See
decision 3.

### Website Pro page (`apps/web/src/pages/pro.astro`)

Comparison table, new group "Support" (last group, after Operations/Account):

| What you get | Community | Pro |
| --- | --- | --- |
| Where to ask | GitHub issues and Discussions | Get help at app.kwatch.dev |
| Answers from | The maintainer and community, best effort | The maintainer, directly |
| Installation help | Docs and GitHub | Yes |
| Your feature requests | Read on GitHub | Weighed first |
| kwatch fixes | In the normal queue | Looked at first |

"Community and Pro in one glance" card, Pro list: add as the last line

> Direct support from the maintainer.

New section between "Free during early access" and "How to get Pro" is not
needed. Instead extend the hero sub-line? No: keep the hero unchanged and put
the three bullets in one short block above the table:

> **Support from the maintainer**
> Installation help. Your feature requests first. kwatch fixes first.
> It is one person, so there is no guaranteed reply time.

License details dl, new row:

> **Support** · Get help at app.kwatch.dev, for accounts with an active Pro license. Community support is on GitHub.

### Website home (`apps/web/src/pages/index.astro`, editions)

Community card body: unchanged. Add after body:

> Support on GitHub.

Pro card body, append one sentence:

> Every detector. The full proof and who made the change. Unlimited channels with routing and threads. History, audit log, maintenance windows and runbooks. Direct support from the maintainer.

Keep one button per card. Signal stays on the single primary button.

### App (`apps/app`, for kwatch-app only)

No change required. The **Get help** page already says "Get help is for Pro.
Community support is on GitHub." Keep it.

## Tokens, states, responsive, dark, accessibility

No new components. Table rows and list lines reuse existing tokens. In the
website comparison table the new group heading uses the existing
`colgroup` header style. At 375px the table keeps its current stacked
behaviour; the Support group follows it. Dark mode inherits. No icons, no
emoji, no new Signal usage. Links use text-link style and must have visible
focus. "Get help" is bold in running text, as for other UI labels.

## Claims check (before merge)

- "Direct support from the maintainer": true only if the mailbox exists and
  is read (decision 1).
- "Installation help", "feature requests first", "fixes first": policy
  claims, not code. The maintainer must agree to keep them (decision 3).
- "Pro only" on Get help: matches Help.tsx / support.ts (active Pro license).
- No reply time, no SLA, no price, no "trial".

## Open decisions for the user

1. **Support mailbox.** Does `support@kwatch.dev` exist, accept mail, and do
   you read it? `kwatch-api` already sends Get help requests there, but
   the rc21 spec left this unconfirmed. No surface should go live until this
   is yes.
2. **Reply time.** Recommended: promise none ("no guaranteed reply time").
   Alternative if you want one: "We aim to reply within 2 business days",
   stated as a goal, not a guarantee. Which?
3. **What "first" means.** Is "Pro requests and fixes are looked at ahead of
   Community ones" a policy you will keep when a Community issue is more
   serious (for example a security bug)? Suggested carve-out: security
   reports are always first, per the security policy.
4. **Channel.** Confirm Get help at app.kwatch.dev as the only Pro channel
   (recommended), or also add a public address or a Pro label on GitHub.
5. **"Maintainer" wording.** Keep "the maintainer" while it is one person, or
   use "the kwatch team"? Recommended: keep "the maintainer"; it is honest
   and is the draw.
6. **After early access.** Support stays a Pro benefit. Do you want any line
   about that now? Recommended: no, covered by "If that ever changes, you
   will hear well in advance."
