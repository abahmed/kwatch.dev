# Pro page spec (kwatch.dev/pro)

Owner: kwatch-web (`apps/web/src/pages/pro.astro`). Copy follows
`../MESSAGING.md`. Designer review before merge.

## What is wrong today

- The page opens with what Pro shows, but never says what Community already
  gives. A reader has to infer it from the table.
- "How to get it" is split: the hero button goes to app.kwatch.dev, the
  installer step is the second row of a definition list near the bottom.
- The data point is a single row ("What's sent") at the very end.
- The closing line "Try the whole thing." leans toward "trial". Remove it.
- The table is long (four groups) before the reader knows the three facts
  they came for.

## Section order

1. Hero
2. Community and Pro in one glance (two cards)
3. Free during early access
4. How to get Pro (three steps, installer-first)
5. Comparison table
6. Data stays in your cluster
7. License details (definition list, trimmed)
8. Closing CTA

## Exact copy

### 1. Hero
- Badge: `Free during early access`
- H1: `Pro shows you the whole story.`
- Lede: `Community names what broke. Pro adds the full chain of cause, who made the change, what else is hit, and the logs that prove it.`
- Primary button: `Get a free Pro license` (https://app.kwatch.dev)
- Secondary link: `Already have a key? Add it in the installer` (anchor `#get-pro`)

### 2. Two cards (uneven: Community 5fr, Pro 7fr)
- Community, label `Community`, line `Free forever. No account, no key.`
  - One-line root-cause headline for every failure
  - Crash loops, OOM kills, Pending pods, Node NotReady
  - 1 alert channel, with quiet-by-default noise control
- Pro, label `Pro`, line `Free during early access.`
  - Full proof and confidence for each root cause
  - Recent changes and who made them
  - Affected services and log excerpts
  - Unlimited channels, routing, incident history, audit log
- Lists use BenefitIcon line icons only where a benefit name appears; plain
  list markers otherwise. No emoji.

### 3. Free during early access
- Heading: `Free during early access`
- Body: `Each Pro license is free for 3 months, and we may renew it. One license runs one cluster, up to 2 per account or company. No payment details. If that ever changes, you will hear well in advance.`
- Never: price, Price row, "trial", "free forever" for Pro.

### 4. How to get Pro (`id="get-pro"`)
- Heading: `Get Pro in three steps`
1. `Get a key` / `Sign in at app.kwatch.dev with your email and press "Get a free Pro license". Your key appears right away.`
2. `Run the installer` / `One command, and it walks you through it.` then the mono block `bash <(curl -fsSL https://kwatch.dev/kwatch.sh)` with a copy button. Note: `Already installed? Run it again.`
3. `Add the key` / `Choose License / Pro, then Add or replace key.`
- Helper line: `Licenses are managed only through the installer.` Do not show a
  helm values path for keys.

### 5. Comparison table
- Heading: `Community and Pro, side by side`
- Keep the existing four groups and rows from the current page (verified
  by kwatch-core). Make the first column header visible: `What you get`.
  No Price row.
- Pro column header filled Ink with Paper text; dash `—` for not included,
  text-muted. Table scrolls horizontally under 640px inside a focusable
  region (keep `tabindex=0`, aria-label).

### 6. Data stays in your cluster
- Heading (BenefitIcon lock, line style): `Root cause, without your data leaving the cluster.`
- Line: `kwatch analyzes events and logs where they live.`
- Small print: `Only optional anonymous usage stats and Pro license checks reach kwatch.dev. Never cluster names, pod names, logs or events. Alerts go only to the channels you set up.`
- Link: `What is sent` to docs data page.

### 7. License details (definition list)
Keep: One cluster, Offline (relabel `If it can't reach kwatch.dev`), When it ends.
Move "Getting one" and "Adding it" into section 4 and drop "What's sent"
(now section 6).
- `If it can't reach kwatch.dev`: `Pro keeps working for up to 7 days after its last successful license check, then falls back to Community features. Monitoring continues.`
- This row is about the license only. Never say "offline" in it or imply
  analysis needs a connection.

### 8. Closing CTA
- Heading: `Get your free Pro license.`
- Button: `Get a free Pro license`
- Signal band stays the only Signal on the page. The badge, cards and step
  numbers must not use Signal.

## Tokens and type
Bricolage Grotesque 800 for headings, Instrument Sans body, Geist Mono for
the install command and group labels. Use existing CSS variables
(`--text`, `--text-soft`, `--text-muted`, `--surface`, `--line`,
`--signal`, `--on-signal`). No gradients, no emoji.

## Responsive and dark
- Under 960px: hero, cards and steps stack to one column; cards order
  Community then Pro.
- Under 560px: definition list stacks; 16px side gutters; no horizontal page
  scroll (only the table region scrolls).
- Dark follows system: Signal becomes #B5DE3C on the CTA band; cards use
  `--surface`; check the Pro column header contrast.

## Accessibility
- One h1; sections are h2; steps are an ordered list.
- Copy button has an accessible name and announces "Copied" in a live region.
- Table keeps `scope` attributes and the labelled scroll region.
- Focus rings visible on all links and buttons; contrast AA in both themes.

## Acceptance checks for kwatch-web
1. Section order matches the list above.
2. All copy matches this file character for character.
3. No emoji, no gradients, no "trial", no price, no "open source".
4. Installer shown before any other install route; no key entry instructions
   outside the installer's License / Pro menu.
5. Signal appears once (closing band), never as text on white.
6. Data section uses the approved line and small print, names no
   competitor and never says "nothing leaves", "air-gapped" or "offline".
7. Table claims unchanged from the current page unless kwatch-core
   confirms.
8. Screenshots at 1440, 768 and 375 wide, light and dark, attached to the PR.
