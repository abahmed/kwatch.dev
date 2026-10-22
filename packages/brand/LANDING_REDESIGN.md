# kwatch.dev landing redesign: conversion and clarity

Owner: kwatch-designer. Implementer: kwatch-web (`apps/web/src/pages/index.astro`,
`styles/global.css`, `components/`). Design only, no production code here.
Copy follows `MESSAGING.md`. Visual consolidation (spacing, radii, Panel,
buttons, breakpoints) is already specified in `specs/landing-redesign.md` and
is not repeated; this document changes **structure, hero, order and copy** and
adds the shared tokens (`tokens.css`) and per-app checklist
(`specs/shared-tokens-checklist.md`). Status: proposed.

**Copy rule: landing copy states strengths only.** No limits, caveats,
requirements, permissions, edge cases, what Community lacks, what kwatch does
not do, or "only/just/but/however" contrasts on the landing page. Detail that
must be disclosed lives in the approved data wording, `/pro`, and docs.

**Signal:** the logo's lime point is brand chrome and exempt from "Signal at
most once per view". Content gets one Signal fill per view (the final CTA).

## 1. Audit of the current page

Audited at `index.astro` on main (b7bbfbb).

| # | Finding | Why it costs conversions | Fix |
|---|---|---|---|
| A1 | Hero CTA "Install free" is an anchor (`#install`, line 120) to a section roughly seven screens down. The command is not in the hero. | The visitor must scroll to learn what "install" means. The page's promise (one command) is hidden. | Put the command in the hero, with a copy button (section 3.1). |
| A2 | Hero carries two paragraphs (`lede`, `lede-sub`) that say the same thing. | The first read is two blocks of grey text before any action. | Use the subhead only; the plain-language line moves to "How it works". |
| A3 | Hero card overlaps the noise list with `margin: -150px 0 0 28px` and a 60px shadow (`index.astro` .card). | It is the best proof on the page, but at tablet width it collides with text; the noise list is read as decoration. | Keep the idea as a two-state before/after (section 3.1), no negative margin. |
| A4 | Order: strip, `#quick` (3 steps plus benefits), `#how` (3 more steps), catches, quiet, install, pro, faq, cta. | "How it works" is told twice (30-second steps, then trace). Benefits sit inside the steps section. Install comes after six sections. | Collapse to one story with install earlier (section 2). |
| A5 | Privacy detail (two Panels and the Never-sent strip) sits right under the hero. | Heavy reading before value is understood. It is right to be prominent, but as a short band first, detail on demand. | Short band with the approved bold line; panels behind the "What is sent" disclosure and on docs (section 3.6). |
| A6 | No trust section. Source-available and GitHub appear only as one bullet in `.facts`. | The first question of an engineer who installs into prod is "can I read it?" | A trust row with only verifiable facts (section 3.7). |
| A7 | Copy with limits or contrast in marketing sections: catches sub ("Community covers X; Pro covers everything below"), quiet note ("in Community they arrive as short follow-up messages"). | Violates positive-only copy, makes the free tier read as the lesser one. | State what each edition gives; no "only", no comparison inside feature sections (section 3.4, 3.5). |
| A8 | Four H2 patterns and two CTA label styles ("Install free", "Install kwatch free", "Install", "Get a free Pro license"). | The primary action has four names. | One label: "Install kwatch" (section 4). |
| A9 | The failure strip (`aria-hidden`, marquee) and glossary are decorative or defensive; strip carries 10 keywords the benefits already imply. | Motion draws the eye away from the CTA. | Keep the strip static (a single wrapped row of mono keywords) and below the hero; it is real vocabulary for scanning. |
| A10 | Mobile: hero stacks text, then noise, then card; CTA row wraps into two lines; nav is 4 links plus brand wrapping under it at <=640. | Install command is not reachable in the first 700px of a phone. | Mobile hero order in section 5. |

## 2. New section order

1. Header
2. Hero: headline, subhead, installer command, before/after proof
3. Static keyword strip (what it catches, one row)
4. How it works (one section, three steps, trace as the visual)
5. Benefits (six, MESSAGING order) with the data line as benefit 2 expanded
6. Community and Pro
7. Trust: source available, real output, what is sent
8. FAQ
9. Final CTA (the one Signal fill on the page)
10. Footer

Removed as separate sections: the second steps list (merged), "Quiet by
default" timeline (becomes benefit 3's proof, section 3.5), the install
terminal section (moves into the hero; the full session shown inside "How it
works" step 1). Catches grid moves to docs/Pro page as the full list; the
landing keeps the strip and a link ("See everything it catches").

## 3. Sections: layout, copy, states

Eyebrow (mono 13px `--text-muted`), H2 `display`, lede 18px `--text-soft`,
max 62ch, always left aligned. Use token names from `tokens.css`.

### 3.1 Hero

Layout (>=960px): uneven 7fr / 5fr grid, content aligned top, gutters
`--gutter`. Left: text and install. Right: the proof, a vertical pair.

Copy (exact):
- Mono line: `03:07 · #prod-alerts · 47 new messages` (real output style).
- H1: `Fifty alerts. One cause.` ("One cause." keeps the Ink block `mark`; no Signal.)
- Subhead (MESSAGING section 1): `kwatch runs inside your Kubernetes cluster, traces every failure back to what started it, and sends one message: what broke, why, who changed it, and what to do next.`
- Install block (the primary action): a Geist Mono command field with a Copy button.
  - Label above, 13px mono: `Install in one command`
  - Field: `/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"`
  - Copy button label: `Copy`; after click, `Copied` for 2s, announced via `aria-live="polite"`. No-JS: the command is plain selectable text in the page; the Copy button is progressive enhancement, rendered `hidden` and revealed by a small script, so without JS the visitor still sees and selects the command.
  - Under the field, 15px `--text-muted`: `It walks you through it and checks your cluster before it changes anything.`
- Secondary row: `Already use Helm? See the chart guide →` (link to the chart guide) and `Pro is free during early access →` (to `#editions`).
- Proof (right): two stacked blocks.
  1. "Before" `.noise` list, 4 lines then `+ 41 more`, mono 13px, dimmed progressively, caption `Without kwatch`.
  2. "After" ink alert card (radius `--radius-output`, `--shadow-output`), caption `With kwatch`. Content exactly as today: `checkout-api is crash-looping because a ConfigMap changed 4 minutes ago.` with Why / Who / Impact / Next. Caption under: `Example alert.`
  No negative margins: the two blocks are separated by a 16px gap and a 1px `--line` arrow-free divider.

States: the command field is a `<code>` in a focusable `div[role=group]`; Copy
is a real `<button>`, 44px high, `.btn-line`. Focus ring `--focus-width`
`--focus-offset` `--text`. If clipboard is unavailable, select the text
(button label `Select`). The field wraps (`overflow-wrap: anywhere`) at <=480px.
Dark mode: field uses `--surface` fill, `--line` border; ink alert card as today.

Single primary action in the hero is the command. No filled Signal button.

### 3.2 Static keyword strip

One row of mono keywords on `--ink`, no marquee, wraps to two rows on mobile,
`aria-hidden` removed and rendered as a `<ul>` so it is readable: CrashLoopBackOff, OOMKilled,
ImagePullBackOff, NodeNotReady, FailedScheduling, CertificateExpiring, PVC
Pending, WebhookTimeout, RolloutStuck, CronJob missed. Prefix label
(`ink-muted`): `Catches`. End link (ink-text, underlined): `See everything it catches →`.

### 3.3 How it works

Eyebrow `How it works in 30 seconds`. H2: `It follows the trail, the way you would.`
Lede: `When something breaks in your Kubernetes cluster, kwatch tells you what broke, why, and what to do, in Slack, Discord, email and 50+ other channels.`

Three steps, uneven grid `4fr 5fr 3fr`, 2px `--text` top rule (the one emphasis rule):
1. **Install.** `Run one command. It asks a few questions.` Visual: the installer session (`? Where should alerts go?`, `? Add a Pro license key? (Enter to skip)`), `--ink` terminal.
2. **It watches.** `kwatch runs as one small pod in your cluster and keeps a live map of what depends on what.` Visual: the trace chips (symptom to cause, cause row inked).
3. **You hear.** `When something breaks you get one clear message: what broke, why, and what to do.` Visual: link "See the example alert" back to the hero card (no duplicate).

Mobile: single column, step number as mono eyebrow, visuals full width.
Glossary stays as a collapsed `<details>` under the steps.

### 3.4 Benefits

Eyebrow `Why teams keep it`. H2: `One message, with the cause.` Six items in MESSAGING order, `BenefitIcon` (no emoji), 3x2 grid desktop, 2x3 at <=960, 1 column at <=480, divided by 1px `--line` with `--radius-card` outer corners:

1. Root cause first: `kwatch follows a failure upstream and names the one cause.`
2. Your data stays in your cluster: `kwatch analyzes events and logs where they live.`
3. Quiet by default: `One message, then silence until something new is true.`
4. Who changed what: `See who changed what, and when.`
5. The next step: `Every message ends with the command to run.`
6. 50+ channels: `Slack, Teams, PagerDuty, email, webhooks and more.`

Benefits 2 and 3 are expandable cards (a `<details>`-style disclosure that reads as one control, 44px summary):
- Benefit 2 expands to the approved bold line `Root cause, without your data leaving the cluster.`, the small print exactly as in MESSAGING, link `What is sent` to the docs data-flow page, and the two Panels plus the Never-sent strip (existing `DataFlows.astro`). Collapsed by default; if the URL hash is `#data`, open it.
- Benefit 3 expands to the four-line timeline (03:07 Opened, 03:11 Update, 03:16 Fix detected, 03:21 Resolved after 14 minutes) with the sentence `kwatch waits for failures to settle, merges what belongs together and speaks when there is news.`

### 3.5 Community and Pro (`#editions`)

H2: `Free. And Pro is free too.`
Lede: `Pro is free during early access. No payment details.`
(No "trial", no prices. License terms and numbers live on `/pro`, not here.)

Two Panels (existing Panel spec, `5fr 7fr`):
- **Community**, sub `Free forever. No account, no key.` Body: `Apps that keep crashing (crash loops, out-of-memory kills), pods stuck waiting and servers that go down (NotReady nodes), explained in one line and sent to your channel.` Button `.btn-line`: `Install kwatch`.
- **Pro**, sub `Free during early access.` Body: `Every detector. The full proof and who made the change. Unlimited channels with routing and threads. History, audit log, maintenance windows and runbooks.` Buttons: `Get a free Pro license` (to app.kwatch.dev, `.btn-solid`), link `Compare editions →`.
- Footnote under both, 15px `--text-muted`: `Licenses are managed in the installer: License / Pro > Add or replace key.`

Rule: each panel says only what its edition gives; no sentence compares the editions. Detail lives on `/pro`.

### 3.6 What is sent

Covered by benefit 2 (3.4). No separate full-width table above the fold.

### 3.7 Trust

Eyebrow `Read it before you run it`. Three equal facts in a divided row (same grid as benefits):
- `Source available.` `Read every line on GitHub, under ELv2.` (link: repository)
- `One small pod.` `A small volume for state, nothing else to run.`
- `Your data stays in your cluster.` `kwatch analyzes events and logs where they live.`

Do not add logos, testimonials, star counts or user numbers unless a real one is provided by the lead; fabricated social proof is not allowed. If a GitHub star count is wanted, fetch it at build time from the GitHub API and show it as text `Star on GitHub` with the number in mono; hide the number if the fetch fails.

### 3.8 FAQ

H2 `Fair questions`. Keep only questions whose answers are pure benefits. Drop "Does it replace Prometheus?", "What leaves my cluster?", "What permissions does it need?" and "Why is Pro free?" from the landing FAQ (they admit a gap, state a requirement or hedge; the approved data wording stays in benefit 2, the rest lives in docs). Final five:
1. Do I need to be a Kubernetes expert? (answer as on main)
2. Will it work on my cluster? (answer as on main)
3. Where do alerts go? `Slack, Teams, Discord, PagerDuty, email, webhooks and 50+ other channels.`
4. How do I get Pro? `Pro is free during early access. Get a key at app.kwatch.dev, then open the installer and choose License / Pro > Add or replace key.`
5. Can I install with Helm? `Yes. The chart guide walks you through it; the installer is the quickest way.`

FAQ JSON-LD must list the same five. `<details>` rows, summary 19px, min-height 44px, `+`/`-` drawn with 2px strokes (`currentColor`).

### 3.9 Final CTA (Signal)

The only Signal fill on the page (the logo point is exempt as brand chrome).
H2 `Sleep through the noise.` Beside it, the same install field as the hero (command plus Copy, on `--signal` ground, text `--on-signal`, field border `--on-signal` 1.5px, button `.btn-solid`).
Under it, 15px: `Prefer Helm? See the chart guide.`
Light and dark: Signal swaps to `#B5DE3C` through the token; contrast of `--on-signal` on it is above 4.5:1 in both.

### 3.10 Header and footer

Header: logo lockup (mark 26px + "kwatch" 800, -0.05em), links `Docs`, `Pro`, `Get help`, then `Sign in` (as text), and one pill `Install` (`.btn-line`, 44px) that scrolls to the hero command (`#install` anchor now lands on the hero field). Mobile (<=700): brand left, `Install` pill right, links in a second row at 15px, no hamburger (4 links fit at 375px).
Footer: the single shared line, `kwatch · source available under ELv2`, then Docs, GitHub, Get help, Privacy, Terms.

## 4. Copy rules applied

- One primary label: `Install kwatch`. The hero field replaces the "Install free" button. "free" appears only in "Pro is free during early access" and "Free forever" (Community).
- No "trial", prices, "open source", "free forever" for Pro.
- Licenses only through the installer's License / Pro menu; app.kwatch.dev issues keys, the installer applies them.
- Channels: always `50+`.
- Strengths only (see the rule at the top). The approved data small print and ELv2 line are the only disclosures kept on the landing page, verbatim.
- Claims verified in code by the lead: one replica with small requests/limits, state on a small volume, installer checks cluster version and permissions before applying. Keep "one small pod", "a small volume for state" and "checks your cluster before it changes anything".

## 5. Responsive behaviour

Breakpoints 960 / 700 / 480 only.
- >960: hero 7fr/5fr; benefits 3x2; editions 5fr/7fr.
- 700-960: hero stacks (text, command, proof); benefits 2x3; editions stack.
- <700: one column; section padding 64px (48px at <=480); header second row for links.
- Hero order on phone: mono line, H1, subhead, command field and Copy (full width, Copy under the field), Helm/Pro links, proof pair. The command is visible within 700px height at 375 wide with the 16px gutter.
- No horizontal scroll on the page; only the command field text wraps.
- Touch targets 44px (`--hit`).

## 6. Dark mode

Everything through tokens; no hard-coded colors (replace `#000` terminal, `#fff` skip-link text, `rgba` shadow stays via `--shadow-output`). Ink blocks (strip, terminal, alert card, never-sent strip) have a 1px `--ink-line` edge on dark `--bg`. Status colours appear only inside the alert card and trace chips. Signal flips to `#B5DE3C`, still one fill.

## 7. Accessibility

- One `h1`; sections use `h2`, cards `h3`; no skipped levels.
- Skip link first in tab order, targets `main`.
- Copy button: real button, `aria-live` status, never the only way to get the command (the text is selectable).
- Disclosures are native `<details>`/`<summary>`; focus ring visible; hash opens benefit 2 for `#data`.
- Color contrast 4.5:1 body, 3:1 for control borders (`--control-border`), checked in both modes.
- `prefers-reduced-motion`: no marquee anymore; copy feedback has no animation.
- Alert card has `role="group"` and a label; the "Without kwatch" noise list is `aria-hidden` and its caption is read as text.
- Signal never used as text on white.

## 8. Acceptance for the implementer

1. Install command and Copy are visible without scrolling at 1440x900 and within the first 700px at 375 wide.
2. Exactly one Signal fill (final CTA); no Signal in hero, strip, editions or trust.
3. Section order and copy as above; MESSAGING wording verbatim where quoted.
4. Lighthouse accessibility 100 in light and dark; keyboard-only run through every control.
5. Screenshots at 1440, 768 and 375, light and dark, attached to the PR (designer reviews).
