# Pro support spec

Owner: kwatch-designer (copy). Implementers: kwatch-core (README), kwatch-docs,
kwatch-web. Copy follows `../MESSAGING.md`. Status: approved; decisions at the end.

## Research notes (patterns, not quotes)

From general knowledge of how these tools present support; not re-fetched
for this spec, so treat as direction.

- Sidekiq Pro, Plausible, Tailscale (small plans): support is a plain line
  ("email support", "direct access to the author"), listed once, no
  numbers. Trust comes from a named person, not from a promise.
- Grafana, PostHog, larger vendors: tiers with response-time tables and SLAs.
  That is a team promise a small project cannot keep. Do not borrow it.
- What works for small open-core tools: say who answers, what they help with,
  what Community gets instead, and say honestly that it is a person.
- Avoid: "24/7", "enterprise-grade", "white-glove", "SLA", "guaranteed",
  "priority" without saying priority over what.

Direction for kwatch: **a narrow list of what support covers, no clock, no
statement about who answers.** "Prioritized" is honest only as "ahead of Community requests",
so write it that way.

## Positioning line

> Pro includes dedicated support.

Sub-line (use where there is room):

> Help with installation, and your feature requests and kwatch fixes come first.

## Benefit bullets (order is fixed)

1. **Installation help.** Stuck on the installer, Helm values or RBAC? Ask and
   get an answer.
2. **Feature requests first.** Pro requests are read and weighed ahead of
   Community ones.
3. **Fixes first.** When a Pro cluster hits a kwatch bug, it is looked at
   ahead of other open issues.

No small print. Support copy states benefits only: no caveats, limits or reply-time lines.

## Community gets

GitHub issues and Discussions. Everything in the docs. Same kwatch, same alerts.

> Community support on GitHub.

## Channel (what exists today)

Verified in the repos:

- `kwatch-api/src/routes/support.ts`: `POST /support`, signed-in, active Pro
  license required, sends one email to `SUPPORT_INBOX` = `support@kwatch.dev`.
  3 requests per account per UTC day.
- `kwatch.dev/apps/app/src/pages/Help.tsx`: **Get help** at app.kwatch.dev,
  Pro only. Non-Pro accounts see "Get help is for Pro. Community support is
  on GitHub." with an Open an issue button.
- `kwatch/.github/ISSUE_TEMPLATE/config.yml`: Discussions and issues for
  Community. No Pro-only label or category exists.
- `hello@kwatch.dev` is the general contact (privacy, terms, app).

Decided: **Get help at app.kwatch.dev/help (Help.tsx) is the Pro channel.** Every surface links straight to `https://app.kwatch.dev/help` and uses the name "Get help" as the app does. The app copy already says "we" and names nobody, so the app stays unchanged. It proves
the license, attaches cluster facts, and keeps the address out of public
pages. Do not publish `support@kwatch.dev` as a link. Do not add a Pro GitHub
label. 

Dependency: spec `pro-readiness-rc21.md` open question 6 (does the
`support@kwatch.dev` mailbox exist and who reads it) must be answered
before any surface goes live. See decision 1.

## Exact copy per surface

Wording never says who answers.

### README (`kwatch/README.md`, Editions)

Add a row to the editions table:

| | Community | Pro |
| --- | --- | --- |
| Support | GitHub issues and Discussions | Dedicated support: installation help, and your feature requests and fixes come first |

Add under the table, before "When a Pro license ends":

> Pro includes dedicated support. Go to [**Get help**](https://app.kwatch.dev/help). Community support is on
> [GitHub](https://github.com/abahmed/kwatch/issues).

README FAQ entry:

> **What does Pro support include?**
> Community questions go to GitHub issues and Discussions, Pro includes dedicated support:
> installation help, and your feature requests and kwatch fixes come first.

### Docs: Editions (`apps/docs/docs/editions.md`)

At-a-glance table, new row after Operations:

| Support | GitHub issues and Discussions | Dedicated support: installation help, feature requests and fixes first |

In the `## Pro` section, append one paragraph:

> Pro also includes dedicated support. See
> [Getting help](/getting-help).

### Docs: Getting help (`apps/docs/docs/getting-help.md`)

Replace the two bullets:

> - **Community:** open an issue on [GitHub](https://github.com/abahmed/kwatch/issues/new)
>   or start a Discussion. Issues are public, so remove anything private first.
>  
> - **Pro:** go to [**Get help**](https://app.kwatch.dev/help). You get dedicated support: help with
>   installation, and your feature requests and kwatch fixes come first.
>   Pro is free during early access.

Add after the bullets:

> Attach a diagnostics file (below) to get to the cause faster.

Docs FAQ (editions or getting-help):

> **What does Pro support cover?**
> Installing and configuring kwatch, your feature requests, and problems in
> kwatch itself.

The last sentence is a claim we must be able to keep. 

### Website Pro page (`apps/web/src/pages/pro.astro`)

Comparison table, new group "Support" (last group, after Operations/Account):

| What you get | Community | Pro |
| --- | --- | --- |
| Where to ask | GitHub issues and Discussions | [Get help](https://app.kwatch.dev/help) |
| Support from | Community support on GitHub | Dedicated support |
| Installation help | Docs and GitHub | Yes |
| Your feature requests | Read on GitHub | Weighed first |
| kwatch fixes | In the normal queue | Looked at first |

"Community and Pro in one glance" card, Pro list: add as the last line

> Dedicated support.

New section between "Free during early access" and "How to get Pro" is not
needed. Instead extend the hero sub-line? No: keep the hero unchanged and put
the three bullets in one short block above the table:

> **Dedicated support**
> Installation help. Your feature requests first. kwatch fixes first.

License details dl, new row:

> **Support** · [Get help](https://app.kwatch.dev/help), for accounts with an active Pro license. Community support is on GitHub.

### Website home (`apps/web/src/pages/index.astro`, editions)

Community card body: unchanged. Add after body:

> Support on GitHub.

Pro card body, append one sentence:

> Every detector. The full proof and who made the change. Unlimited channels with routing and threads. History, audit log, maintenance windows and runbooks. Dedicated support.

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

- "Dedicated support": true only if the mailbox exists and
  is read (decision 1, closed).
- "Installation help", "feature requests first", "fixes first": policy
  claims, not code. We must agree to keep them (decision 3, closed).
- "Pro only" on Get help: matches Help.tsx / support.ts (active Pro license).
- No reply-time lines, caveats, SLA, no price, no "trial".

## Decisions (closed by the user)

1. Mailbox: proceed; the lead confirms `support@kwatch.dev` before go-live.
2. No reply-time wording anywhere.
3. "First" applies. Internal note only, never on marketing surfaces: security reports are handled first under the security policy.
4. Get help at app.kwatch.dev is the only Pro channel.
5. Never say who answers: no "maintainer", "team" or "one person".
6. No line about what happens after early access.
