# Dashboard phase 2 spec (read-only UI and installer Dashboard menu)

Owner: kwatch-core (Go, embedded assets) for the UI; the installer
(`apps/web/public/kwatch.sh`, kwatch-web) for the menu. Copy follows
`../MESSAGING.md`. Designer review before merge. Source of truth for data:
`kwatch/internal/dashboard/responses.go` and `handlers.go` as merged in #579.
Anything the screens need that the API does not return is in section 5 and
marked **[GAP n]** where it is used.

Facts to respect everywhere: the dashboard is Pro (free during early access),
off by default, read-only. No prices, no "trial". No write action, no
settings editing, no license activation anywhere in the UI.

## 0. Shared rules

### Shell

- One page app, embedded assets, no CDN, no third-party requests. Fonts are
  the brand woff2 files (Bricolage Grotesque 800, Instrument Sans, Geist
  Mono), latin subset, embedded and served from the same origin.
- CSP (engineers may tighten, not loosen):
  `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'`.
  So: no inline script or style, no `style=""` attributes (use classes), no
  `innerHTML` for API text (always `textContent`), no inline SVG event handlers.
- Content width `--max-app` (1000px). Body 16px (`--text-body-product`).
  Breakpoints exactly 960 / 700 / 480. Gutter 24px, 16px at <=640px.
- Shell is the same as app.kwatch.dev (`apps/app/src/styles.css`): a 220px
  left sidebar (kwatch mark + wordmark, nav links `Active issues`,
  `Resolved`, `kwatch status`, and at the bottom `Read-only dashboard` +
  `Sign out` text button), content `--max-app` wide. At <=700px the sidebar
  becomes a top bar (brand, then the links wrapping, then the who row).
  The current link has `aria-current="page"` and weight 600. Active issues
  carries a count badge (see 1.2).
- Page title in the tab: `Active issues - kwatch`, `<issue title> - kwatch`,
  etc. Favicon: `logo/favicon.svg`.

### Signal rule

The kwatch mark carries the lime point; that is the **one Signal element per
view**. Nothing else uses Signal in the dashboard. Primary buttons are Ink
(`--text` fill, `--bg` text, hover `--primary-hover`). Never Signal text.

### Status colours

Status colours appear only inside alert-like elements: severity chips, the
"keeps failing" banner, channel failure rows, error banners. Use the
`--failing`, `--degraded`, `--resolved`, `--success` tokens with their
`-bg` pairs (they already switch for dark). Every status has a word as well
as colour; colour is never the only signal.

### Light and dark

Follow the system only (`prefers-color-scheme`), no toggle, tokens from
`packages/brand/tokens.css`. Page bg `--bg`, cards `--surface`, lines
`--line`. Mono blocks (log lines, commands) sit on `--ink` with `--ink-text`
in both modes (the "stays dark" surface), with `--ink-line` borders. Check
contrast of chips in dark with the dark `-bg` tokens.

### Type

- Page title (H1): Bricolage Grotesque 800, `--h1-product`.
- Section labels: Instrument Sans 600, 15px, `--text-muted`, sentence case.
- Anything that comes from the cluster is Geist Mono: namespace, workload,
  log lines, commands, error messages from channels, timeline `entity`.
  Issue titles and root-cause sentences are kwatch's own words: Instrument
  Sans.

### Consistent hover, focus, press (one set for every control)

- Rows and cards that are links: hover `background: var(--surface)`, 120ms
  (inside `prefers-reduced-motion: no-preference`), cursor pointer, title text
  underlined.
- Primary button: hover `--primary-hover`. Secondary button (outline,
  `--control-border`): hover `--surface` fill. Text button / link: hover
  underline thickness 1px to 2px, no colour change.
- Focus: 3px outline in `--text`, offset 3px, on every interactive element
  including whole-row links. Never remove it.
- Hit area at least 44px (`--hit`) high for rows, buttons, selects, nav.
- No hover-only information. Every tooltip (`title`) text is also visible
  or reachable by keyboard.

### Time

- Relative text, `<time datetime="ISO">`: `just now`, `4 min ago`,
  `3 h ago`, `yesterday at 14:02`, then `12 Oct, 14:02`. The full local
  date-time plus UTC is the `title` and also shown in the detail timeline
  and on the status screen as plain text (keyboard and touch can read it).
- Local time zone of the browser. Relative times tick every 30s without
  refetching. Use the response `Date` header to correct for clock skew.
- Duration (resolved screen): `lasted 12 min`, `lasted 3 h 10 min`,
  `lasted 2 days`.

### Refresh

- Active issues and kwatch status poll every 30s while the tab is visible;
  stop when hidden, refetch on becoming visible. Resolved and Issue detail
  fetch on open and have a `Refresh` text button. Footer line on list pages:
  `Updated 12 s ago` + `Refresh` button (`aria-live="polite"` region updates
  the "Updated" text at most every 30s so screen readers are not spammed).
- Never clear the list during a refetch; keep the old rows until the new ones
  arrive (no flicker, no layout jump).

### Loading

Skeleton rows (3, `--surface` blocks, no shimmer; a slow 1.2s opacity pulse
only under `prefers-reduced-motion: no-preference`) shaped like the final
rows, plus visually hidden text `Loading`. Show after 300ms, not before.

### Shared error states (every data screen)

Rendered as one banner/panel component with a heading, one sentence, and an
action. Do not show raw status codes or JSON to the user; show the code in
small mono text (`Error 500`) only on the 500 variant.

| Case | Heading | Body | Action |
|---|---|---|---|
| 401 / 403 on any API call | `Your session ended` | `Sign in again to keep going.` | Redirect to Sign in, keep the page (`?next=` path only, same-origin path validated) |
| 503 `unavailable` | `kwatch is starting` | `kwatch has just started and is still loading what it knows. This page refreshes by itself.` | Auto-retry every 5s, then back off to 15s; `Try now` button. Page chrome stays; only the content area is replaced. |
| Network failure / timeout | `Can't reach kwatch` | `The connection dropped. We'll keep trying.` If older data exists: keep it, grey it, add `Showing what we had 2 min ago.` | `Try now` |
| 429 | `Too many tries` | `Wait a minute, then try again.` | none (retry automatically after 60s) |
| 500 | `Something went wrong inside kwatch` | `This is not your cluster. Check kwatch's own logs for the reason:` + mono block `kubectl -n kwatch logs deploy/kwatch --tail=50` with Copy button (namespace from `status`, else `kwatch`; see decision D6) | `Try again` |
| 400 (should not happen) | same as 500 | | |

The `kwatch is starting` panel must never read as an outage of the user's
cluster. It is about kwatch only.

### Accessibility

- Landmarks: `header` (nav), `main` (one `h1` per screen), `footer` line.
- Skip link `Skip to content`, first focusable.
- Lists are real `<ul>`/`<li>` (rows) or a `<table>` with `scope` headers on
  desktop; on mobile the same markup restyled, no hidden duplicates.
- Chips: text inside the chip; `aria-label` not needed. Icons are decorative
  (`aria-hidden`).
- Dynamic regions: error/starting banners `role="status"`; the sign-in error
  `role="alert"` and focus moves to the password field.
- Copy buttons: label `Copy`, then `Copied` for 2s, announced via
  `aria-live="polite"`. Fallback when clipboard API is blocked: select the
  text.
- Contrast: AA for text, 3:1 for control borders (use `--control-border`).
- Zoom to 200% and 320px width without horizontal scroll (code blocks scroll
  inside themselves, `tabindex="0"` and a visible focus ring).
- Respect `prefers-reduced-motion` (no pulse, no transitions).

### Namespace filter (shared by Active issues and Resolved)

- A native `<select>` labelled `Namespace`, first option `All namespaces`,
  then namespaces sorted A to Z in mono. Value is in the URL
  (`?namespace=payments`) so it is shareable and survives refresh; it is
  sent to the API as `namespace=`. Switching tab (Active / Resolved) keeps it.
- Options come from **[GAP 3]**. Until then, build the list from namespaces
  seen in the two loaded lists (active + resolved) and say nothing about
  completeness.
- If the URL names a namespace with no issues, still show it as selected and
  show the filtered empty state (below), not an error.

### Truncated-list behaviour

The API returns `{incidents, total, truncated}`. Rules:

- Show `Showing 100 of 214` above the list **only** when `truncated` is true,
  in `--text-muted`. Otherwise show the count: `3 issues`.
- Under the last row, when truncated: a boxed note (surface bg):
  `Showing the newest 100 of 214. Pick a namespace to narrow it down.` Never
  offer "Load more" (the API has no paging; see **[GAP 9]**).
- The count badge in the nav uses `total`, not `incidents.length`.

---

## 1. Screens

Paths (hash-free, served by the Go binary, SPA fallback to the shell):
`/signin`, `/` (Active issues), `/issues/{id}`, `/resolved`, `/status`.

### 1.1 Sign in (`/signin`)

Purpose: one shared password (no usernames) to get a cookie session.

Layout: centered single column, max 400px, uneven vertical rhythm (more space
above than below). Mark (large Junction mark, the one Signal element) above
the H1.

```
        [k mark]

        Sign in to kwatch

        Password
        [__________________] [Show]

        [ Sign in ]

        Forgot it? Open the installer, choose Dashboard, then
        "Show my access link and password".
        bash <(curl -fsSL https://kwatch.dev/kwatch.sh)   [Copy]
```

Fields and source: none from the read API. Needs the login endpoint
**[GAP 1]**.

- H1 `Sign in to kwatch`. Label `Password`. `Show` / `Hide` toggle button
  (`aria-pressed`). Input `type=password`, `autocomplete="current-password"`,
  `autofocus`, plus a visually hidden prefilled username input
  (`value="kwatch"`, `autocomplete="username"`) so password managers save it.
- Button `Sign in` (Ink primary, full width on mobile). Enter submits. Button
  shows `Signing in...` and is disabled while the request runs.
- Help text uses mono for the command, with Copy.
- No "remember me", no "create account", no email.

States:

| State | Copy |
|---|---|
| Wrong password (401) | `That password isn't right. Check it and try again.` Inline under the field, `role="alert"`, field keeps its text, focus returns to it. No hint whether it exists. |
| Too many tries (429) | `Too many tries. Wait a minute, then try again.` Button disabled for 60s with a visible countdown `Try again in 42 s`. |
| 503 | the `kwatch is starting` panel replaces the form; auto-retry. |
| Network | `Can't reach kwatch. Check your connection and try again.` |
| Plain HTTP on a shared dashboard (core refuses) | Full-page: `This address must use https` / `kwatch only signs you in over https. Open https://<same host> instead.` with that link. **[GAP 2]** |
| Already signed in | Redirect to `/`. |
| Session ended (arrived with `?reason=expired`) | Notice above the form: `Your session ended. Sign in again.` |

Dark: same layout. Mobile: padding 16px, input 48px high, 16px font minimum
(prevents iOS zoom).

### 1.2 Active issues (`/`, home)

Purpose: what is wrong right now, newest first. Answers "is anything on fire".

Data: `GET /api/incidents?state=active&namespace=&limit=` (default limit,
100) for rows; `GET /api/status` for `lastScan` and the all-clear check.

Layout (desktop, inside the sidebar shell): H1 `Active issues` left, filter right, count line under.
Rows are a table-like grid with uneven columns
`minmax(0,6fr) minmax(0,3fr) minmax(0,2fr)` (what / where / when), each row
a single link to the detail.

```
Active issues                                   Namespace [All namespaces v]
3 issues

[Urgent]  payments-api keeps crashing: it ran out of memory
          Happening now · failed again 4 times      payments / payments-api    18 min ago
[Needs attention]  checkout can't reach its database
          Looking into it                           shop / checkout            2 min ago
[Low]  3 certificates expire within 14 days
          Happening now · you acknowledged (ana)    infra / cert-bundle        1 h ago

                                   Updated 12 s ago  [Refresh]
```

Row fields:

| Shown | API field | Notes |
|---|---|---|
| Severity chip | `severity` | words in section 2.2 |
| Title (the link text) | `title` | kwatch's last message headline. Wraps up to 2 lines then ellipsis; full text on detail |
| State line | `state` | words in 2.1 |
| Repeats | `repeatCount` | `failed again 4 times`; hidden when 0 |
| Acknowledged | `ackedBy` | `Acknowledged by ana`; hidden when empty |
| Where | `namespace`, `workload` | mono, `namespace / workload`; empty namespace (cluster-wide, e.g. a node) shows `whole cluster` in text-muted, not mono |
| When | `lastSeen` (relative), `firstSeen` in title | `Last seen 2 min ago`; the `title` has `Started 14:02` |

Sorting: API order (newest `firstSeen`). Do not re-sort client side by
severity, but pin `Urgent` rows above the rest **only if** core agrees
(decision D4); default is API order.

Nav badge: `total` of active, shown as a number chip next to the nav link;
hidden at 0. Badge colour: `--failing` only if at least one Urgent, else
`--surface` (needs the count by severity: **[GAP 4]**; until then neutral).

Namespace filter: see section 0. Count line with filter:
`2 issues in payments`.

#### All clear (empty state)

Show only when ALL are true: list is empty, request succeeded, and
`lastScan` is recent (**[GAP 5]** for the threshold; until then: non-zero and
within 5 minutes).

- Display H2 (Bricolage 800, large, left aligned, not centered): `All clear.`
- Line: `kwatch checked your cluster 20 seconds ago and nothing is failing.`
- Second line (text-muted): `Watching every namespace except kube-system.`
  built from `watchedNamespaces` / `excludedNamespaces` (`["*"]` = `every
  namespace`; list of up to 3 names, then `and 4 more`).
- Link row: `See what was resolved this week` (to `/resolved`).
- No illustration, no checkmark art. One quiet rule line above, uneven
  whitespace.

Other empty states (must not claim "all clear"):

| Case | Copy |
|---|---|
| `lastScan` is zero | `kwatch hasn't finished its first check yet.` / `Issues will show up here as soon as it has.` |
| `lastScan` is old | `kwatch hasn't checked in a while.` / `Last check: 14 min ago. See kwatch status.` link. Banner uses `degraded` tokens. |
| Filter has no issues | `Nothing failing in payments.` / `Try All namespaces.` (button resets the filter) |
| Status call failed but list OK | Show the list/empty state without the "checked X ago" line; never say all clear. Use `Nothing is listed as failing.` |

States: loading skeleton, error banners from section 0 (kept above the
list so stale rows stay visible), 503 panel.

Mobile (<=700): rows stack as cards: chip + title on top, state line, then
`namespace / workload` and time on one line (wraps). Filter goes full width
under the H1. The sidebar is a top bar with one wrapping row of links, no hamburger.

### 1.3 Issue detail (`/issues/{id}`)

Purpose: what broke, why, and what to do. Same order as a kwatch alert.

Data: `GET /api/incidents/{id}` only.

Layout (desktop): breadcrumb-free; a back link `Active issues` or `Resolved`
(depends on `state`) above the H1. Two columns, uneven `7fr / 4fr`, gap
32px. Left: story. Right: facts card.

Left column order:

1. Chips row: severity chip, state chip.
2. H1 = `title` (Bricolage 800, up to 3 lines).
3. **Why it happened** (label) + `rootCause` as a paragraph (Instrument Sans,
   `--measure`). If empty: `kwatch hasn't found a single cause yet. It is
   still collecting what failed around it.` (for `settling` state), else
   omit the section.
4. **What to do** + `suggestedFix`. Render as paragraph text; any line that
   starts with `kubectl ` or `helm ` renders as a mono command block with
   Copy (heuristic until **[GAP 6]**). If empty, omit the section (do not
   print "no fix").
   `docsLink`: link row `Your runbook for this` (label from messaging: it is
   the configured runbook link) opens in a new tab, `rel="noopener
   noreferrer"`, only `https:` or `http:` URLs are rendered as links; any
   other scheme is shown as plain text.
5. **What kwatch saw** + `capturedLogLines` in a mono block on Ink, one line
   per row, line wrap off, horizontal scroll inside, max-height 320px
   scrollable (`tabindex=0`), `Copy all` button. Caption (text-muted):
   `Last lines kwatch captured when this started. Secrets are removed.` If
   empty: `No log lines were captured for this issue.` Lines are already
   redacted by core; the UI must still render them as text only.
6. **What happened, in order** + `timeline` (see below).

Right column "Facts" card (`--surface`, 10px radius), definition list:

| Label | Value | Source |
|---|---|---|
| Where | `namespace / workload` (mono) | `namespace`, `workload` |
| Started | `14:02, 18 min ago` | `firstSeen` |
| Last seen | | `lastSeen` |
| Failed again | `4 times` (or `Not yet`) | `repeatCount` |
| Acknowledged | `By ana` / `No one yet` | `ackedBy` |
| Resolved | `12 Oct, 14:40 (lasted 38 min)` (resolved only) | `resolvedAt`, `firstSeen` |
| Issue ID | mono, small, Copy | `id` |

Under the card, text-muted, one line: `This page is read-only. To acknowledge
or change anything, use kubectl or your alert channel.` Check with core what
acknowledgement path is true: ack is the `kwatch.dev/ack` annotation, so the
sentence can be made specific (decision D7).

Timeline: vertical list, newest at the bottom (reads like a story), each
item: time (mono, 13px, `HH:MM`, date separator rows when the day changes),
a 2px vertical line with a 8px node, then text. Wording map in 2.3.
`entity` (when present) shown under the text in mono, text-muted, small.
Timeline is capped at the last 100 entries by the API; if exactly 100 are
shown add a top row `Earlier events are not shown.`

State banners on detail (above the H1, status colours):

| Condition | Banner |
|---|---|
| `state=flapping` | `degraded`: `This keeps failing and recovering. kwatch stays quiet about it unless it changes.` (check wording is true: D8) |
| `state=recovering` | `resolved` tokens: `It looks fixed. kwatch is waiting a little to be sure before it calls it resolved.` |
| `state=resolved` | `resolved` tokens: `Resolved 12 Oct, 14:40. kwatch keeps resolved issues for 7 days.` |

States:

| State | Copy |
|---|---|
| Loading | skeleton: title bar, 3 text lines, mono block |
| 404 | H1 `We can't find that issue` / `kwatch only keeps resolved issues for 7 days, and the ID may be mistyped.` / links `Active issues`, `Resolved` |
| 503 | `kwatch is starting` panel |
| Issue resolved while you read | next poll/refresh updates the banner; do not navigate away |

Detail does not auto-poll for active issues in v1.2 except a 30s refresh
while visible (same refresh rule as the list) so the state and timeline
stay right; preserve scroll and the log block's scroll position.

Mobile: single column; the Facts card moves directly under the H1 (before
"Why it happened"), all rows shown (no disclosure; it kept duplicate markup).
Command blocks wrap instead of scrolling; the log block scrolls inside
itself. Copy buttons stay visible (not hover-only).

### 1.4 Resolved, last 7 days (`/resolved`)

Purpose: what was fixed this week, for the "did that really stop" question.

Data: `GET /api/incidents?state=resolved&namespace=&limit=`.

Layout: same shell as Active issues. H1 `Resolved`, sub-line
`Issues from the last 7 days. kwatch keeps them for a week.` Rows are the
same component as active, with columns `what / where / when`, but:

- chip is `Resolved` (blue tokens) instead of severity; severity shows as
  small text `was Urgent` in text-muted.
- when column: `Resolved 3 h ago` and under it `lasted 38 min`.
- repeat count shown: `failed again 4 times`.
- Title and row link as on Active.

Sort: API order is newest `firstSeen`. Resolved is better by resolution
time; request that core sorts resolved by `resolvedAt` (D5). Until then,
sort client side by `resolvedAt` desc within the returned set and note that
a truncated set may miss newer-resolved older-started issues (rare; accept).

Empty states:

| Case | Copy |
|---|---|
| No resolved issues | `Nothing resolved this week.` / `When kwatch sees an issue go away, it is listed here for 7 days.` |
| Filter empty | `Nothing resolved in payments this week.` / `Try All namespaces.` |
| kwatch restarted without a persistent volume | cannot be detected today; see **[GAP 8]**. Do not guess. |

Truncated behaviour, filter, loading, errors, 503: section 0. Mobile: as
Active.

### 1.5 kwatch status (`/status`)

Purpose: is kwatch itself working, and are its alerts getting out. Includes
"which message channel is broken".

Data: `GET /api/status`.

Layout: H1 `kwatch status`. Summary sentence under it (plain language), then
two uneven cards (`5fr / 7fr`): "About this kwatch" and "Where alerts go".
Namespaces card full width underneath.

Summary sentence (first match wins):

1. Any channel with a failure newer than its last success (or never
   succeeded and failed): `kwatch is running, but at least one channel isn't
   delivering.` (`degraded` tokens)
2. `lastScan` zero: `kwatch is starting and hasn't finished its first check.`
3. `lastScan` older than threshold: `kwatch hasn't checked in a while.`
   (`degraded`) **[GAP 5]**
4. otherwise `kwatch is running and delivering.` (`success` tokens)

About card (definition list):

| Label | Value | Source |
|---|---|---|
| Version | mono, `v1.2.0` | `version` |
| Plan | `Pro` / `Community` | `edition` (Community cannot see the dashboard, but show whatever it says) |
| Last check | `20 seconds ago`; full time in text | `lastScan` |

Where alerts go card: a list, one row per `perChannelHealth` entry.
Row = channel name (display name, 2.4) + health words + detail.

Namespaces card: `Watching` and `Not watching`:
`watchedNamespaces == ["*"]` shows `Every namespace`; otherwise the names as
mono chips (wrap). `excludedNamespaces` shows under `Not watching` (hidden
when empty). If `["*"]` and excluded exist: `Every namespace except:` then
chips.

Empty/other states:

| Case | Copy |
|---|---|
| `perChannelHealth` empty | `No alert channels are set up yet.` / `Add one in the installer: choose "Edit notification providers".` (the real menu label) |
| Channel never tried | `Nothing sent yet` (neutral) |
| Loading, error, 503 | section 0 |

Mobile: cards stack; channel rows wrap the detail under the name.

---

## 2. Plain-language wording

Rules: say what is true, then what it means. No Kubernetes jargon in labels
(the glossary terms may appear inside kwatch's own sentences, which already
explain themselves). Sentence case. No exclamation marks, no emoji, no
"oops". Short.

### 2.1 State (`state`)

| API | Label (chip) | Longer line (detail banner or tooltip text, also in the row) |
|---|---|---|
| `settling` | Looking into it | kwatch is still collecting what failed around this, so the cause may change. |
| `open` | Happening now | This is failing right now. |
| `recovering` | Looks better | It stopped failing. kwatch is waiting a little to be sure. |
| `flapping` | Keeps coming back | It keeps failing and recovering. |
| `resolved` | Resolved | It stopped failing and stayed fixed. |
| anything else | Unknown | (render the raw word in mono; never crash) |

Chip colours: Looking into it = neutral surface; Happening now = neutral
(severity carries the colour); Looks better and Resolved = `resolved`
tokens; Keeps coming back = `degraded` tokens.

### 2.2 Severity (`severity`, from the incident tier)

| API | Label | Meaning line (title attribute and detail sidebar) | Chip |
|---|---|---|---|
| `page` | Urgent | kwatch sent this as a page. Someone should look now. | `failing` tokens |
| `notify` | Needs attention | kwatch notified your channels. Look at it soon. | `degraded` tokens |
| `digest` | Low | Not urgent. It goes into the digest, not a page. | neutral (`--surface`, `--text-soft`) |
| `silent` | Quiet | kwatch is tracking this but is not sending it. | neutral, dashed border |
| other | the raw word | | neutral |

Do not call them "critical/high/medium". They mirror the Slack/email words
(page / notify / low) in simpler form. Confirm with core that `digest` means
"low" in the messages users receive (D8). Whether `silent` incidents should be
listed at all is a question for core (D4).

### 2.3 Timeline items

The API gives free-text `text` written by kwatch (`internal/incident`). Until
**[GAP 7]** adds a `kind`, the UI shows `text` with only the first letter
upper-cased and applies this display map by prefix (case-sensitive match on
the API string; unknown text is shown unchanged, never dropped):

| API text starts with | Shown as |
|---|---|
| (synthetic first row from `firstSeen`) | `kwatch noticed this` |
| `failing again: ` | `Failed again: ` + rest |
| `happened again (` | `Happened again (` + rest, e.g. `Happened again (3rd time this week)` |
| `acknowledged on ` | `Acknowledged on ` + rest (add `by <ackedBy>` when it is the latest ack) |
| `acknowledgement removed` | `Acknowledgement removed` |
| `cause revised: ` | `kwatch found a different cause: ` + rest |
| `flapping: ` | `Keeps failing and recovering: ` + rest |
| `still failing: paging again` | `Still failing, so kwatch alerted again` |
| `announced with a page for the same moment` | `Sent with the urgent alert for the same moment` |
| `same outage as ` | `Same outage as ` + rest (the API text already ends `, already paged`; show as given) |
| `resolved: ` | `Resolved: ` + reason map below |

Resolved reasons (rest of `resolved: `): `settled` is not a resolution;
`recovered unheard` shows `It recovered before kwatch had to alert anyone.`;
`superseded` shows `Folded into another issue with the same cause.`;
`acknowledged` is not a resolution. Unknown reasons are shown as given.
Exact current strings must be confirmed by core, who owns them; copy changes
there go through designer review.

Icons: none in the timeline (no stock icons); the node colour follows kind
when **[GAP 7]** exists (resolved = `resolved` token, repeat/flapping =
`degraded`, others `--control-border`).

### 2.4 Channel health

Display name: title-case the API `channel` (`slack` becomes `Slack`,
`msteams` stays as the product's own name per a small override table kept
next to the provider list in core: **[GAP 10]**).

States are derived (no `ok` field exists):

| Condition | Row |
|---|---|
| `lastSuccess` set, no `lastError` or `lastSuccess` >= `lastError` | `Slack` — check icon + `delivering` — `Last sent 3 min ago` |
| `lastError` > `lastSuccess` (or no success) | `Email` — cross icon + `last failed 5 min ago` — mono `lastErrorMessage` — second line `Last delivered 2 days ago` / `It has not delivered yet.` — hint `Check the provider settings in the installer: "Edit notification providers".` |
| Both set, success newer than error | `Slack` — check icon + `delivering` — `Last sent 3 min ago` plus text-muted `Failed once 2 h ago` (only if the error is within the last 24 h) |
| Neither set | `Webhook` — dash icon + `nothing sent yet` |

The web UI uses drawn line icons (check, cross, dash: 2px strokes,
`currentColor`, no fill, 16px) with the word next to them, not emoji (brand
rule for kwatch.dev/app surfaces extends to the dashboard). The terminal
form from the brief, `Slack ✅ delivering` / `Email ❌ last failed ...`, is
what the **installer** prints (section 3.9), where emoji are already the
house style.

`lastErrorMessage` is already short and redacted; render as text, wrap, max
3 lines then `Show more`.

---

## 3. Installer Dashboard menu

Conventions follow the existing installer (`kwatch.sh`): `ui_select`
with arrow keys and Enter (keys read with `read -rsn1`), one leading emoji per
menu label as in the current main menu, `ui_success` / `ui_warn` /
`ui_error`, `ui_detail` for dim hints, `ui_pause` ("Press Enter to return to
the menu") after a result. Commands shown to the user are copyable plain
lines. Namespace in examples is the installer's `$NAMESPACE` (default
`kwatch`).

### 3.1 Placement

New main-menu entry in `show_supported_menu`, after `🔑 License / Pro`:
`🖥️  Dashboard`. Hidden in Community? No: show it, and when the edition is
Community the screen says why (3.2). This keeps it discoverable and links to
Pro, the same way `License / Pro` is.

Main menu caption on the entry (the existing `ui_select_captioned` style, dim):

| Dashboard state | Caption |
|---|---|
| off | `off` |
| on, local only | `on, local only` |
| shared | `shared at https://kwatch.example.com` |
| unknown (cluster unreachable) | `unknown` |

### 3.2 Dashboard screen

Header (`ui_screen "dashboard"`), then one status line and the choices.
Choices depend on state; labels are exact:

State off:
```
Dashboard: off

  Turn on, local only
  Share with my team
  Back
```

State on, local only:
```
Dashboard: on, local only

  Open the dashboard
  Share with my team
  Show my access link and password
  Reset password
  Turn off
  Back
```

State shared:
```
Dashboard: shared at https://kwatch.example.com

  Show my access link and password
  Reset password
  Switch to local only
  Turn off
  Back
```

(`Open the dashboard` and `Switch to local only` are the only two items beyond
the five named in the brief; both are the same flows as below. If core prefers
exactly five, drop them and re-run Turn on to reopen: decision D9.)

Community edition (no valid Pro license): do not show the choices. Print:

```
The dashboard is part of Pro, which is free during early access.
Add your key first: choose "License / Pro" in the main menu.
Get a free key at https://app.kwatch.dev
```
then `ui_pause`.

kwatch older than v1.2 (no dashboard support, detected from the installed
version): `This version of kwatch doesn't have the dashboard yet. Upgrade
kwatch from the main menu first (it needs v1.2 or newer).`

### 3.3 Turn on, local only

Steps:

1. Preflight, silent unless it fails: cluster reachable, kwatch installed and
   ready, edition is Pro, version supports the dashboard. Failure copy in 3.8.
2. Show: `Turn on the dashboard on this computer only?` +
   dim `Nothing is exposed to the internet. The dashboard is reachable only
   while this window keeps the connection open.` Keys: `Enter` yes,
   `n` no (existing yes/no helper).
3. Busy line `Turning on the dashboard...` (`ui_busy`). Actions: create or
   keep the `kwatch-dashboard` Secret with a generated token and a
   generated password; set `dashboard.enabled` (and the local cookie mode,
   D2); roll out kwatch; wait for ready.
4. Print once (3.7 for the exact block): link, password.
5. Ask nothing more. Then:
   `Opening the dashboard in your browser. Keep this window open. Press
   Ctrl-C to close the connection.`
6. Run `kubectl -n $NAMESPACE port-forward svc/kwatch-dashboard <local>:<port>`
   in the foreground. `<local>` is the first free port from 8080 up (try
   8080 to 8090); the link printed uses the chosen port. Open the browser
   with `open` (macOS), `xdg-open` (Linux), `wslview` or `cmd.exe /c start`
   (WSL) when present; if none: `Open this link in your browser:` and the
   link.
7. On Ctrl-C: `Connection closed. The dashboard is still on. Choose "Open
   the dashboard" to connect again.` then back to the Dashboard screen.
   If the forward drops by itself: `The connection to the cluster dropped.
   Choose "Open the dashboard" to connect again.`

Success message (before step 5):
`Dashboard is on. Local only, nothing leaves your computer.`
Hold that: do not say "secure". Say what is true.

If rolling out takes more than 90s: warn
`kwatch is taking longer than usual to restart. Check it with "View status"
in the main menu, then try again.` and stop (no forward).

If the data volume is not persistent (emptyDir) the restart clears open and
resolved issues kwatch remembers; the installer already knows this setting.
Warn before step 3 only in that case:
`Turning this on restarts kwatch. Without a persistent volume it forgets the
issues it was tracking and finds them again on its next check.`

### 3.4 Share with my team

One question only: the address.

Steps:

1. Preflight (3.8): Pro, version, an ingress controller exists, a way to get
   a certificate exists. Silent when fine.
2. Question: `What address should your team use?` dim hint
   `For example kwatch.example.com. You need to control this name at your DNS
   provider.` Input rules: lowercase, trim spaces; strip a leading
   `https://` and any trailing `/`. Refuse and ask again (stay on the
   prompt, error under it):
   - starts with `http://`: `kwatch only shares the dashboard over https.
     Type just the address, like kwatch.example.com.`
   - an IP address: `Use a name, not an IP address. A certificate needs a
     name.`
   - contains `*`, a path, a port or spaces: `Type just the address, like
     kwatch.example.com.`
   - not a valid hostname: `That doesn't look like an address. Try
     kwatch.example.com.`
   Empty input or Esc goes back.
3. Confirm screen (the only other keypress), showing what will happen,
   no questions:
   ```
   Share the dashboard at https://kwatch.example.com

   - an Ingress using "nginx"
   - a certificate from "letsencrypt-prod" (cert-manager)
   - sign-in with a password; plain http is refused

   Enter to continue, n to cancel
   ```
   The ingress class and issuer are chosen automatically (3.8 rules); the
   screen only reports them.
4. Busy `Sharing the dashboard...`: create/keep the Secret (token, password),
   set enabled and shared mode with the address, create the Ingress with TLS
   and http-to-https redirect, roll out, wait.
5. Wait up to 60s for the Ingress to get an external address
   (`status.loadBalancer.ingress`). If it appears, print DNS instructions
   (3.5). If not: print DNS instructions with the line
   `Your cluster hasn't reported its address yet. Find it with:` and
   `kubectl -n $NAMESPACE get ingress kwatch-dashboard`.
6. Print once the password block (3.7) with the https link.
7. Check the certificate once: if `Ready`, `The certificate is ready.`;
   otherwise `The certificate is issued after your DNS record exists. This
   usually takes a few minutes. Check with "Show my access link and
   password".` (do not promise a time).
8. Success: `Dashboard shared at https://kwatch.example.com` and `ui_pause`.

Remember: share mode also needs the kwatch binary to refuse sign-in over
plain HTTP (**[GAP 2]**), not only the Ingress redirect.

### 3.5 DNS instructions (printed in Share)

When the Ingress address is an IP:
```
Now point your address at the cluster. At your DNS provider, add:

  Type   A
  Name   kwatch.example.com
  Value  203.0.113.10

Until that exists, the link won't open. DNS changes can take a while to
spread; the certificate is issued once they have.
```
When it is a hostname (load balancer name): same block with `Type  CNAME` and
`Value  abc123.elb.example.com`.

Name column: the full address as typed. If the user's DNS tool wants the
short name, the dim line under says `Some providers want just "kwatch" for
this field.` (only when the address has 3+ labels).

### 3.6 Show my access link and password

1. Print the link: `Dashboard link: https://kwatch.example.com` (shared) or
   `Dashboard link: http://localhost:8080 (works while "Open the dashboard"
   is running)` (local).
2. `Press Enter to show the password, or Esc to go back` (so it is never
   shown by accident; reading the Secret happens only after Enter).
3. Print `Password: <value>` in mono-looking plain text, then dim:
   `Anyone with this link and password can read your issues. Share it only
   with people who should see them.`
4. If the password can't be read (Secret missing or unreadable):
   `I can't read the password from the cluster. Choose "Reset password" to
   make a new one.`
5. For shared: add `Certificate: ready` or `Certificate: still being issued`.

Decision D1 (stored plain vs hashed): see section 6. The copy above assumes
the password is readable from the Secret by the installer.

### 3.7 What is printed once

Printed at Turn on and Share, and again only through "Show my access link and
password" (Enter to reveal) or "Reset password". Exact block:

```
Your dashboard is ready.

  Link      https://kwatch.example.com
  Password  7K4M-QX9P-2HVD-T6RE

Save the password now, in your password manager.
You can show it again from Dashboard > Show my access link and password.
```
(Replace the last line with `Choose Dashboard > Reset password if you lose
it.` if decision D1 resolves to hashed storage.)

Password format: 16 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no
0/O/1/I/l), shown in 4 groups of 4 with dashes; the sign-in field accepts it
with or without dashes and any case. About 80 bits of entropy.

Never print the password or token in: the busy line, a log file, diagnostics
output (`Save diagnostics to file` must redact them; check), or shell
history (no command-line argument carries it). The bearer token is never
shown; it is internal. Terminals keep scrollback: the installer prints a dim
line `Clear your terminal when you've saved it.` only when stdout is a
terminal.

### 3.8 Failure copy

Format: what is wrong, then what to do. Each ends the flow with `ui_pause`.
Use `ui_error` for the first line, `ui_detail` for the rest.

| Case | Message |
|---|---|
| Community edition | (3.2 Community block) |
| kwatch too old | (3.2) |
| Cluster unreachable | `I can't reach your cluster.` / `Check that kubectl works: kubectl get nodes` |
| kwatch not installed or not ready | `kwatch isn't running yet.` / `Install or repair it from the main menu, then try again.` |
| No ingress controller (Share) | `Your cluster has no ingress controller, so kwatch can't share the dashboard yet.` / `An ingress controller is what lets traffic from outside reach your cluster. Install one (ingress-nginx is a common choice), then try again.` / `You can still use "Turn on, local only" now.` |
| Ingress controller found but several, none default | `Your cluster has more than one ingress controller and none is the default.` / `Mark one as the default class, then try again: kubectl annotate ingressclass <name> ingressclass.kubernetes.io/is-default-class=true` |
| No way to get a certificate (Share) | `kwatch won't share the dashboard without https, and I couldn't find a way to get a certificate.` / `The easiest way is cert-manager with a ClusterIssuer. Set that up, then try again.` / `Until then, use "Turn on, local only".` |
| Several ClusterIssuers | not a failure: choose `letsencrypt-prod` if it exists, otherwise the first by name; the confirm screen names the choice. (D3) |
| Plain HTTP address typed | prompt error from 3.4 |
| Name already used by another Ingress | `Another Ingress already uses kwatch.example.com (namespace shop).` / `Pick a different address, or remove that one first.` |
| Rollout timeout | `kwatch is taking longer than usual to restart.` / `Check it with "View status" in the main menu, then try again.` |
| Secret/permission error | `Kubernetes said no: <first line of the error>` / `Your kubectl user needs permission to edit Secrets and Ingresses in the "kwatch" namespace.` |
| Certificate failed | `The certificate request failed: <reason from the Certificate status>` / `Check that your DNS record points to the address shown, then choose "Show my access link and password".` |
| Cancelled (Esc, n) | silent return to the Dashboard screen |

Interrupted flows (Ctrl-C mid-way): the installer must leave the cluster
either fully on or unchanged; on the next open the Dashboard screen reports
the real state. Say nothing alarming.

### 3.9 Reset password

1. `Make a new password? Everyone signed in will be signed out.`
   `Enter` yes, `n` no.
2. Busy `Resetting the password...`: generate, write to the Secret, make
   kwatch pick it up (a rollout is fine) and end all sessions (**[GAP 1]**).
3. Print the "printed once" block (3.7), same format.
4. `ui_success`: `Password reset. Old sessions are signed out.`
5. Failure: `I couldn't reset the password: <reason>. Nothing changed.`

### 3.10 Turn off

1. `Turn off the dashboard?` dim
   `The link stops working and the password is deleted. Your issues and alerts
   are not affected.` + for shared: `The Ingress and its certificate are
   removed.` Enter yes, `n` no.
2. Busy `Turning off the dashboard...`: set disabled, remove Ingress (and the
   certificate it created), delete the password and token Secret, roll out,
   stop any port-forward the installer started.
3. `ui_success`: `Dashboard is off.`
4. Failure: `I couldn't turn it off: <reason>` / `Run this to see what's left:
   kubectl -n kwatch get ingress,secret` and say what stays on.
5. The DNS record is not touched; say `You can remove the DNS record for
   kwatch.example.com whenever you like.` (shared only).

### 3.11 Channel health lines (terminal form, for "View status")

If core's `View status` adds channel health later, the exact terminal lines
are:
`Slack ✅ delivering` and `Email ❌ last failed 5 min ago: <message>`.
Not part of the dashboard menu itself; included here so the two surfaces use
the same words.

---

## 4. Responsive and dark summary for engineers

- >960: two-column detail (7fr/4fr), table-like rows (6fr/3fr/2fr).
- 700 to 960: detail stays two columns at 8fr/5fr; rows drop the third column
  into the second line.
- <=700: single column, cards, nav row stays (3 links), filter full width.
- <=480: gutter 16px, buttons full width, chips wrap, badge hides if it would
  wrap the nav (count then appears in the H1 line only).
- Dark: tokens switch automatically; mono blocks unchanged (Ink).
  Do not use `#fff`/`#000` literals. Skeletons use `--surface`/`--line`.
- Print: not designed. No special handling.

---

## 5. API gaps for kwatch-core

Needed for the screens as designed. Ordered by importance. Everything else
in this spec uses fields that exist in #579.

1. **Password login and session (blocks the whole UI).**
   `POST /login` (JSON `{"password": "..."}`) sets the cookie (HttpOnly,
   Secure, SameSite=Strict, Path=/, no Domain) and returns 204; wrong
   password 401 with no detail; failures share the existing per-host rate
   limit and return 429. `POST /logout` clears it. `GET /api/session` returns
   204 or 401 so the shell can decide Sign in vs app without hitting data
   endpoints. `/api/*` accepts the session cookie OR the bearer token.
   Sessions end when the password is reset (key rotation) and on a fixed
   lifetime (D10). Password comes from the `kwatch-dashboard` Secret
   (key `password`). Static assets and the HTML shell are served without
   auth; only `/api/*` needs it.
2. **Refuse sign-in over plain HTTP in shared mode.** When shared mode is on,
   `POST /login` and the shell reject requests where the connection is not
   TLS and `X-Forwarded-Proto` is not `https` (trusted only from the Ingress).
   Return 403 `{"error":"https_required"}`; the UI shows the "must use https"
   page (1.1).
3. **Namespace list for the filter.** Either `namespaces` in the list
   response (all namespaces that have incidents of that state, ignoring the
   `namespace` filter) or `GET /api/namespaces`. Today the filter would be
   built from a possibly truncated list.
4. **Active counts by severity.** In the list response:
   `counts: {"page":1,"notify":2,"digest":0}` (ignoring the limit), for the nav
   badge colour.
5. **Scan health.** In `/api/status`: `scanEverySeconds` (or `lastScanLate`
   boolean decided by core) so the UI can say "hasn't checked in a while"
   without hard-coding 5 minutes. `lastScan` zero is already usable.
6. **Fix as structured data.** `suggestedFix` is one string. Add
   `fixCommands: []string` (the commands only) so Copy buttons are exact
   instead of a `kubectl `/`helm ` prefix heuristic.
7. **Timeline event kind.** Add `kind` to `Event`:
   `opened|repeated|worsened|cause_revised|acknowledged|ack_removed|flapping|paged_again|resolved`
   and, for `resolved`, `reason`: `recovered|superseded|recovered_unheard`.
   Today the UI would parse English prefixes (section 2.3), which breaks the
   day a message is reworded. Also confirm the shape of `entity` (what string
   `EntityID.String()` returns) so it can be shown or hidden.
8. **Persistence flag.** `/api/status`: `storage: "volume" | "memory"` so
   the Resolved screen can say `kwatch forgets issues when it restarts
   (no persistent volume)` and not mislead.
9. **Paging for long lists.** Optional: `before=<firstSeen or id>` cursor.
   Not needed for v1.2 because truncation copy tells the user to filter.
10. **Channel display name and kind.** `perChannelHealth[].channel` is a
    string; add `name` (what the user called it, e.g. `#alerts`) only if
    it is safe (never a URL/token) and `type` (`slack`, `email`) so the UI
    can show `Slack (#alerts)`. Without it, title-casing the type is used.
11. **Workload kind.** `workload` is the root's name only. Add
    `workloadKind` (`Deployment`, `Node`, `Pod`) so a node issue does not
    read as a workload and namespace-less items read right.
12. **Acknowledgement time.** `ackedAt` next to `ackedBy` for the facts card.
13. **Resolved sort.** Option `sort=resolved` or sort resolved lists by
    `resolvedAt` server-side (D5).
14. **Cookie `Secure` in local mode.** Safari does not store `Secure`
    cookies over `http://localhost` (Chrome and Firefox do). Need a
    `dashboard.mode: local|shared` setting: local omits `Secure`, shared
    requires it (D2).
15. **Fixed-length responses for the shell.** Add
    `Content-Security-Policy` (section 0) to `securityHeaders`; the current
    middleware sets nosniff/DENY/no-store/no-referrer only. `no-store` is
    fine for `/api`, but embedded static assets should use `max-age` with
    hashed filenames so the app doesn't refetch fonts every load.

Not asked for, on purpose: Kubernetes events and delivery attempts per
incident (phase 1 already says they are not held). Screens do not mention
them.

---

## 6. Decisions needed from the user

- **D1. Password readable again, or shown once?** The brief has both "print
  once" and "Show my access link and password". Recommended: store the
  password in the `kwatch-dashboard` Secret (readable by the installer,
  same exposure as the bearer token that is already stored there). Reveal
  needs an Enter keypress. Alternative: hash it, and the menu item becomes
  "Show my access link" (password shown only at creation and Reset).
- **D2. Cookie `Secure` over `http://localhost`.** Safari rejects it. Recommended: installer sets `dashboard.mode: local`
  for port-forward, which drops `Secure` only there; shared mode always
  Secure. Otherwise local mode does not work in Safari.
- **D3. Which certificate issuer, no question asked.** Recommended: use the
  one cert-manager ClusterIssuer, else `letsencrypt-prod` if present, else
  refuse with the failure copy. Printed on the confirm screen. Adding a
  second question ("which issuer?") would break the "one question" brief.
- **D4. Row order and `silent`.** Keep API order (newest first), or pin
  Urgent first? Recommended: pin Urgent first, then newest. And do `silent`
  incidents belong in Active issues? Recommended: no (hide, not "Quiet").
- **D5. Resolved sorted by resolution time** instead of start time
  (recommended; GAP 13).
- **D6. Namespace in the 500 help command.** `kubectl -n kwatch logs
  deploy/kwatch` assumes defaults. Recommended: core exposes the kwatch
  namespace and deployment name in `/api/status` (tiny addition), else we
  show the generic line `Check kwatch's own logs.`
- **D7. Acknowledging from the UI.** Read-only is firm. Is the line
  "To acknowledge, annotate the resource with kwatch.dev/ack" right to show
  on the detail page? Core to confirm the exact supported way.
- **D8. Claims to verify with core before copy ships.** (a) `digest` equals
  what users see as "low"; (b) flapping really means kwatch alerts quietly
  until something changes; (c) `recovering` waits "a little" (no number
  claimed); (d) secrets are removed from captured log lines (tests say
  yes, wording is "Secrets are removed", keep or soften to "Known secret
  patterns are removed").
- **D9. Menu has two items beyond the five named** (`Open the dashboard`,
  `Switch to local only`). Keep, or stay with exactly five?
- **D10. Session length.** Recommended: 12 hours from sign-in, no sliding,
  signed out on password reset. Shorter is safer, longer is friendlier for
  a wall-mounted screen. Pick one.
- **D11. Emoji in the web UI.** This spec uses drawn icons, not
  `Slack ✅`, on the web (brand rule), and keeps emoji only in the installer.
  Say if you want emoji in the dashboard too.

## 7. Changes made while building the mockup

Mockup: `dashboard-phase2-mockup.html` (static, tabs, light/dark/auto, states
per screen). Changes to this spec:

- Shell is the app's sidebar, not a top bar (section 0), so the dashboard
  and app.kwatch.dev read as one product.
- Mobile detail: Facts show every row, no "More details" disclosure.
- Command blocks wrap (`pre-wrap`) so a junior can read the whole command;
  only log lines scroll.
- Primary buttons use the app's pill buttons (`--radius-pill`, 1.5px border,
  hover `--primary-hover`); the app's `btn-signal` is not used (one Signal
  per view; the mark already has it).
- Redacted log marker is shown as `[redacted]`; core to confirm what
  `internal/redact` really prints.
- Example timeline sentences (`Failed again: 3 times in the last hour`) are
  illustrative; real strings come from `RepeatPhrase` and friends.
- Installer panels keep emoji for menu labels only (house style), none on
  the web.

### 7a. User review changes (2026-10-27)

- Issue rows get a 4px left stripe in their severity colour (Urgent `--failing`, Needs attention `--degraded`, Low `--control-border`); resolved rows use `--resolved`, with the old severity as a coloured "was …" chip and the resolved time in `--resolved`.
- No acknowledgement anywhere in the UI: remove "Acknowledged by …" from rows, the Facts card and the timeline. kwatch doesn't record who acknowledged. Supersedes D7.
- Sign in: the password Show/Hide text becomes an eye / eye-off line icon button (44px hit area, aria-label and title "Show password" / "Hide password").
- Resolved is green everywhere in the dashboard: chip, row stripe, resolved time, detail banner and timeline dot use `--success` / `--success-bg`. "Looks better" stays `--resolved` (blue).
- Filters on Active issues and Resolved: search (name, namespace, text), namespace, severity chips (multi-select; "Was" on Resolved), State on Active (happening now, looking into it, keeps coming back, looks better), Resolved window (24 h, 3 days, 7 days). "Showing N of M" plus "Clear filters"; "No issues match these filters." when empty. Filters live in the URL.
- API gap (core): server-side filters on `GET /api/incidents`: `q`, `severity` (repeatable), `state` (repeatable), `since`, plus a namespace list endpoint, so filters work past the list limit.
- Final review (2026-10-27): the detail page's read-only note is "This page is read-only. To change anything, use kubectl." (no ack mention). The "Was …" chip on a resolved issue uses its old severity colour, same as the Resolved list. Build rule for core: `[hidden]` must always win over component `display` rules.

### 7b. UX review changes (2026-10-27, accepted)

1. Filters: Search and the severity chips are always visible; Namespace, State and the Resolved window sit behind "More filters" (opens automatically when one of them is set in the URL). Hide the whole filter bar when the unfiltered list has fewer than 5 issues and no filter is set (the mockup shows it anyway, for review).
2. Live updates: lists and the status page refresh by themselves every 20 s (pause while the tab is hidden; refresh on focus). Show "Live · Updates by itself · checked N s ago" instead of a Refresh button. Rows that are new or changed since the last refresh get the `--degraded-bg` highlight and a "New" tag for one refresh cycle; announce new Urgent issues to screen readers (aria-live polite). When the connection drops, show "Last updated N min ago" with "Try now".
3. Back link on the detail page returns to the list the user came from: "Resolved" for a resolved issue, otherwise "Active issues".
4. Detail on phones: title, then the story (why, what to do, logs, timeline), then the Facts card.
5. Commands never wrap mid-word: one line, horizontal scroll inside the command box; Copy copies the exact command.
6. Browser tab title shows the active count: "(2) Active issues · kwatch"; "All clear · kwatch" when there are none; favicon gets a red dot when any Urgent issue is active.

### 7c. Installer: ways to share (2026-10-28)

Replaces section 3.4 ("one question only: the address"). Everything else in
section 3 stays (3.3 local, 3.6 to 3.10) except where this section says so.
Owner: kwatch-web (`kwatch.sh`). Chart and binary: kwatch-core (abahmed/kwatch
#581). User decisions of 2026-10-28 are applied (D12, D14 to D17 accepted,
D13 dropped).

**Scope split.** The Helm chart has no exposure options. It provides only
`dashboard.enabled`, the port, a ClusterIP Service `<release>-dashboard`
(port name `dashboard`) and the password/token Secret. kwatch (Go) adds only
`dashboard.mode` (`local` | `shared`), `dashboard.tls.secretName` (kwatch
serves https itself from that Secret) and `dashboard.trustProxy`. The
installer creates every Ingress, HTTPRoute, VirtualService, Route,
LoadBalancer or NodePort Service and cert-manager Certificate itself, and
labels each one `app.kwatch.dev/managed-by=installer` so cleanup touches
nothing else. Example names below use `kwatch-dashboard`, which is
`<release>-dashboard` for the default release name. Emoji are allowed here (installer only, D11); none on the web.

**Rules for every screen**

- Plain words. Any Kubernetes term gets a one-line explanation the first time
  it appears in the flow (glossary in MESSAGING.md section 4; extra terms
  are explained in the hints below).
- Each choice says what it does, then when to pick it, in one dim line.
- Order of every message: cause, then fix. Errors use `ui_error` for the
  first line and `ui_detail` for the rest, then `ui_pause`.
- Esc goes back one screen. Nothing is created on the cluster until the
  confirm screen (7c.7). Ctrl-C leaves the cluster unchanged or fully on.
- Plain HTTP is never offered. Option 7 is the one case where kwatch itself
  receives plain HTTP from your own proxy, and it has its own confirm.
- Never say "secure", "safe" or "private" about a setup. Say what is true.
- Defaults are shown as `[default]` after the question, and Enter takes them.
- Menus use `ui_select_captioned`: label is the line, the dim hint is the
  caption. Captions are one line, 90 characters at most (wrap on narrow
  terminals).

#### 7c.1 What the installer detects

Read-only `kubectl` calls, run once when "Share with my team" is chosen, with
the busy line `Looking at your cluster...`. Results are kept for the whole
flow.

| Signal | How it is found |
|---|---|
| ingress class | `IngressClass` objects; the controller type comes from `spec.controller` |
| default class | annotation `ingressclass.kubernetes.io/is-default-class=true` |
| Gateway API | CRDs `gateway.networking.k8s.io` and at least one `Gateway` |
| Istio | CRD `networking.istio.io` (Gateway / VirtualService) |
| OpenShift | API group `route.openshift.io` |
| cloud | node `providerID`: `aws`, `gce`, `azure`, other, or none |
| load balancer | cloud above, or MetalLB / kube-vip running, or a Service of type LoadBalancer that already has an address |
| node address | nodes have an ExternalIP, or (not on a managed cloud) an InternalIP |
| cert-manager | CRD `cert-manager.io` and its `ClusterIssuer` / `Issuer` objects |
| Tailscale | `IngressClass` `tailscale` |
| ngrok | `IngressClass` `ngrok` |

Controller type from `IngressClass.spec.controller`:

| Controller value | Type shown |
|---|---|
| `k8s.io/ingress-nginx` | nginx |
| `traefik.io/ingress-controller` | Traefik |
| `haproxy-ingress.github.io/controller`, `haproxy.org/ingress-controller` | HAProxy |
| `projectcontour.io/ingress-controller` | Contour |
| `ingress-controllers.konghq.com/kong` | Kong |
| `ingress.k8s.aws/alb` | AWS ALB |
| `k8s.io/ingress-gce` | GKE |
| `azure/application-gateway` | Azure AGIC |
| `tailscale.com/ts-ingress` | Tailscale |
| `ngrok.com/ingress-controller` | ngrok |
| anything else | "other": works if it follows the standard Ingress rules; no extra questions |

#### 7c.2 Which options appear, and which is recommended

| # | Option | Shown when |
|---|---|---|
| 1 | Local only | always |
| 2 | Ingress | at least one ingress class |
| 3 | Gateway API / Istio | Gateway API with a Gateway, or Istio CRDs |
| 4 | OpenShift Route | OpenShift API present |
| 5 | Load balancer | load balancer signal is true |
| 6 | NodePort | node address signal is true and cloud is not `aws`, `gce` or `azure` (nodes on those clouds are normally not reachable from outside) |
| 7 | Outside proxy | always (cannot be detected) |
| 8 | Service only | always |

Numbers are positions in this table, not renumbered when options are hidden;
the screen shows only the options that apply, in this order, with no
numbers on screen (arrow keys and Enter).

Recommended (tag ` · recommended` at the end of the label, one only), first
match wins:

1. OpenShift present: option 4.
2. A default ingress class, or exactly one class: option 2.
3. A Gateway: option 3.
4. Load balancer signal: option 5.
5. Otherwise no tag.

The cursor starts on option 1 (default), always. Enter on an untouched menu
therefore never shares anything. (Decision D12.)

If only options 1, 7 and 8 apply, add this dim line above the menu:
`I couldn't find an ingress, Gateway, load balancer or OpenShift route here,
so the shared choices below are the ones that need a bit of your own setup.`

#### 7c.3 Screen: how to share

`ui_screen "dashboard"`

```
Share the dashboard with your team

I looked at your cluster and show only the ways that will work here.
How should your team open the dashboard?

  💻 Local only  (default)
     Opens in your browser while this window stays open. Pick this to try it, or if only you need it.
  🌐 Ingress · recommended
     Your cluster's front door for web traffic, with a normal https address. Pick this if other apps there already have one.
  🚪 Gateway API / Istio
     The newer kind of front door, or Istio's. Pick this if your cluster uses Gateways or Istio.
  🛰️  OpenShift Route
     OpenShift's own way to publish an app. Pick this on OpenShift.
  ⚖️  Load balancer
     Your cloud (or MetalLB) gives kwatch its own address, and kwatch handles https itself. Pick this if you have no ingress.
  🔌 NodePort
     Opens one port on each machine in the cluster, and kwatch handles https itself. Pick this for a small cluster without a load balancer.
  ☁️  Outside proxy (Cloudflare Tunnel or similar)
     Something outside the cluster adds https for you. Pick this only if you already run one.
  🧰 Service only
     kwatch creates its internal address and shows it. Pick this if you will set up access yourself.
  Back
```

Variants of the caption (same line, only where the detection changes it):

- Ingress with one detected type: append ` Found: nginx.` (type names from
  7c.1; with several classes: `Found: nginx, Traefik.`).
- Gateway / Istio when only Istio: label `🚪 Istio`, caption `Istio's own front door (a VirtualService). Pick this if your cluster runs Istio.`
- Gateway / Istio when only Gateway API: label `🚪 Gateway API`.
- Load balancer on a cloud: append ` Found: AWS.` / `Google Cloud.` / `Azure.`;
  with MetalLB or kube-vip: ` Found: MetalLB.` / ` Found: kube-vip.`
- Back returns to the Dashboard screen. Esc does the same.

If the user picks 1, run 3.3 unchanged. For 2 to 8 continue below.

#### 7c.4 Screens: questions that depend on the cluster

Ask only when the answer is not obvious. Use `ui_select`, cursor on the
safest default.

**A. Several ingress classes (option 2)**

- One default class: use it, say so on the confirm screen. No question.
- No default and one class: use it.
- More than one and none default, or the user's cluster has a default and
  other classes too: ask.

```
Which ingress should carry the dashboard?

Your cluster has more than one. Each is a separate front door.

  nginx        (class "nginx", default)
  Traefik      (class "traefik")
  AWS ALB      (class "alb")
```
Labels: `<type>  (class "<name>"[, default])`. Cursor: the default class,
else the first. Esc goes back.

**B. Several Gateways (option 3)**

```
Which Gateway should carry the dashboard?

A Gateway is a front door set up once for the whole cluster.

  shared-gw      namespace gateways · https for *.example.com
  internal-gw    namespace gateways · https for *.corp.example.com
```
Show only Gateways that have an https listener and allow routes from the
`$NAMESPACE` namespace. Hidden ones are counted in a dim line:
`2 more Gateways don't allow kwatch to use them.` If one remains, use it
without asking.

**C. Both Gateway API and Istio (option 3)**

```
Which should I use?

  Gateway API  (an HTTPRoute)
     Pick this if your Gateway is a Kubernetes Gateway.
  Istio  (a VirtualService)
     Pick this if you route traffic with Istio's own Gateway.
```
Only when both exist. Cursor on Gateway API. Istio is used automatically,
with no question, when Gateway API is absent.

**D. Several address pools (option 5, MetalLB or kube-vip)**

```
Which address pool should the load balancer use?

A pool is the range of addresses MetalLB hands out.

  default-pool    192.168.1.240-192.168.1.250
  office-pool     10.0.5.10-10.0.5.20
```
Skipped when there is one pool.

**E. Several certificate issuers (certificate choice, 7c.5)**

An issuer is the thing in your cluster that gets certificates for you
(cert-manager). Use `letsencrypt-prod` if it exists; else the only issuer;
ignore issuers of type SelfSigned; else ask:

```
Which certificate issuer should I use?

  corp-ca        (ClusterIssuer, CA)
  acme-staging   (ClusterIssuer, ACME)
```
Cursor on the first. Never silently pick between several. (This replaces
D3's "first by name" for the ambiguous case.)

#### 7c.5 Screens: the common questions

Order of questions per option (a question not listed for an option is not
asked). `addr` = address, `tls` = certificate, `ips` = allowed addresses.

| Option | Questions, in order |
|---|---|
| 2 nginx, Traefik, HAProxy, Contour, Kong, other | addr, tls, ips (not Contour, Kong, other) |
| 2 AWS ALB | addr, 7c.6 ALB questions, ips |
| 2 GKE | addr, 7c.6 GKE questions |
| 2 Azure AGIC | addr, 7c.6 AGIC question, tls |
| 2 Tailscale | 7c.6 Tailscale question |
| 2 ngrok | 7c.6 ngrok question |
| 3 Gateway / Istio | pick (7c.4 B, C), addr |
| 4 OpenShift Route | addr, ips |
| 5 Load balancer | 7c.6 LB questions (public or inside, pool), addr, tls, ips |
| 6 NodePort | 7c.6 NodePort question, addr, tls |
| 7 Outside proxy | addr, then the confirm gate (7c.8) |
| 8 Service only | addr, tls |

**Address**

```
What address should your team use?
For example kwatch.example.com. You need to control this name at your DNS provider. (DNS is the phone book that turns a name into a machine's address.)
```
Rules and errors are exactly as in 3.4 step 2 (plain http, IP, wildcard,
path, port, spaces, invalid name), with these differences:

- Options 5 and 6: an IP is allowed, but only with the self-signed
  certificate. Hint: `A name like kwatch.example.com, or press Enter to use the IP address (then your browser will warn about the certificate).` Default: empty = IP. When an IP is used, the certificate screen shows only
  the self-signed choice.
- Option 4: default is the cluster's own `apps` address, shown:
  `[kwatch-kwatch.apps.example.com]`, hint `OpenShift gives every app an address like this and already has a certificate for it.`
- Option 7: hint `The https address people will open, the one your proxy shows. kwatch uses it to check that everything works.`
- Option 8: hint `The name you will point at kwatch. kwatch uses it for its certificate.`
- Duplicate: `Another Ingress already uses kwatch.example.com (namespace shop).` / `Pick a different address, or remove that one first.` (same for HTTPRoute, VirtualService, Route).

**Certificate** (the https lock)

```
How should kwatch get its https certificate?
A certificate is what lets browsers show the lock and trust the address.

  🪄 Automatic, from cert-manager (letsencrypt-prod)
     Free, trusted by browsers, renewed for you. Needs your address to be reachable so the issuer can check it.
  🔑 A certificate I already have
     Use a TLS Secret that is already in the cluster. Pick this if your company issues certificates.
  ⚠️  Make one myself (self-signed)
     Works right away, but every browser warns until it is told to trust it. Fine for a test, not for a team.
```

- First choice is shown only when cert-manager has a usable issuer (7c.4 E).
  Its label names the issuer chosen. Hidden otherwise, with a dim line:
  `I didn't find cert-manager, so automatic certificates aren't available.`
- Cursor: first choice if shown, else the second. Never the third.
- "A certificate I already have": list TLS Secrets in `$NAMESPACE`
  (`kubernetes.io/tls`) with `ui_select`, plus `Type a name`. Checks: the
  Secret exists, is of type TLS, the certificate covers the address and has
  not expired. Errors:
  - `That Secret isn't a TLS Secret.` / `It needs the keys tls.crt and tls.key.`
  - `That certificate doesn't cover kwatch.example.com.` / `It covers: <names>. Pick another Secret or change the address.`
  - `That certificate expired on <date>.` / `Renew it, or pick another.`
- Self-signed adds this line before moving on, in yellow:
  `Browsers will warn "not private" each time until you trust the certificate. Anyone you share the link with will see that.`
  and asks `Use a self-signed certificate? Enter yes, n no.`
- For an IP address only the self-signed choice is shown.

**Who can open it (allowed addresses)**

Asked only where the setup can really enforce it (the enforcement table
below). Otherwise not asked, and the confirm screen says
`Anyone who reaches the address can see the sign-in page.`

```
Limit it to certain IP addresses?
An IP address is the number a computer connects from. Leave empty to allow everyone with the password.
Example: 203.0.113.0/24, 198.51.100.7  [everyone]
```
- Comma or space separated. Accepts an IP or a range (CIDR, like
  `203.0.113.0/24`), IPv4 and IPv6.
- Errors: `"<x>" isn't an IP address or range. Try 203.0.113.0/24.`;
  `0.0.0.0/0 means everyone. Leave this empty instead.` (accept as empty
  after one confirm);
  `Private addresses (like 10.0.0.5) only work if people connect from inside your network.` shown as a warning, not an error, when
  all entries are private and the setup is public.
- Echo on confirm: `Only these addresses can open it: 203.0.113.0/24`.
- Reminder in the same screen, dim: `The password is still needed.`
- If the user's own public address is detectable and not in the list, add a dim
  line: `Your current address isn't in this list, so you won't be able to open it from here.` (only when detectable).

Enforcement per setup (mechanism for kwatch-core / kwatch-web):

| Setup | Enforced by |
|---|---|
| nginx | ingress annotation `nginx.ingress.kubernetes.io/whitelist-source-range` |
| Traefik | `IPAllowList` middleware on the route |
| HAProxy | ingress annotation allow-list |
| AWS ALB | `alb.ingress.kubernetes.io/inbound-cidrs` |
| OpenShift Route | `haproxy.router.openshift.io/ip_whitelist` |
| Load balancer | `loadBalancerSourceRanges` on the Service |
| everything else | not asked (Contour, Kong, other, GKE, AGIC, Tailscale, ngrok, Gateway/Istio, NodePort, outside proxy, Service only) |

There is no IP limit inside kwatch (D13 dropped). The question is asked only
for the setups in the table; everywhere else it is not asked and the confirm
screen says what is true.

#### 7c.6 Screens: questions that belong to one setup

All are `ui_select` or a prompt with a default, one per screen.

**AWS ALB** (an ALB is Amazon's own load balancer for web traffic)

1. ```
   Who should be able to reach the dashboard?

     🌍 Anyone on the internet  (internet-facing)
        The sign-in page is visible to everyone. Pick this for people outside your network.
     🏢 Only inside our network  (internal)
        Reachable only from your private network or VPN. Pick this for a team that works through a VPN.
   ```
   Cursor on internal. Maps to `alb.ingress.kubernetes.io/scheme`.
2. ```
   What is the ARN of the certificate in AWS Certificate Manager (ACM)?
   An ARN is the long ID AWS gives it. Find it in AWS: Certificate Manager > your certificate.
   Example: arn:aws:acm:eu-west-1:123456789012:certificate/abcd-...
   ```
   Check the shape (`arn:aws:acm:<region>:<12 digits>:certificate/<id>`).
   Errors: `That doesn't look like an ACM certificate ARN.` / `It starts with arn:aws:acm: and ends with certificate/ and an ID.`;
   `That certificate is in <region> but your cluster is in <region>.` (only when both are known; an ALB can only use certificates from its own region.)
   The certificate screen of 7c.5 is not shown for ALB: ACM is the
   certificate. The leg from the ALB to kwatch is https too: the installer
   makes a self-signed certificate Secret, sets `dashboard.tls.secretName`
   and tells the ALB to use https to the pod (D14). The same applies to GKE
   and AGIC. The ALB does not check that inner certificate; say nothing
   about it on screen.

**GKE** (Google's own load balancer for web traffic)

1. ```
   Google will create and renew the certificate for kwatch.example.com.
   It starts working after your DNS record exists, and can take a while.
   ```
   No question; shown as a notice, and the confirm screen says
   `a Google managed certificate`.
2. ```
   Do you have a reserved static IP in Google Cloud?
   Without one, the address can change if the load balancer is recreated. Type its name, or press Enter to skip.  [skip]
   ```
   Maps to `kubernetes.io/ingress.global-static-ip-name`. Error: `I can't find a global static IP named "<x>" ...` only if `gcloud` is present; otherwise no check.

**Azure AGIC** (Application Gateway, Microsoft's load balancer for web traffic)

```
Should the gateway use its public or its private address?

  🌍 Public address
     Reachable from the internet.
  🏢 Private address
     Reachable only from your Azure network or VPN.
```
Cursor on private. Then the certificate screen (7c.5) with the first two
choices only plus self-signed (a gateway with a self-signed certificate
warns browsers just the same).

**Tailscale** (a private network between your devices)

```
What should the dashboard be called on your Tailscale network?
People on your Tailscale network will open https://<name>.<your-tailnet>.ts.net. Tailscale handles the certificate.  [kwatch]
```
Valid: lowercase letters, digits, hyphens; up to 63. Tailscale decides the
final address; the installer reads it back from the Ingress status and shows
it on confirm after creation. Not offered: Funnel (public). No DNS step, no
certificate question, no IP list. Error if HTTPS is not enabled for the
tailnet: `Tailscale can't give kwatch a certificate yet.` / `Turn on HTTPS
certificates for your tailnet in the Tailscale admin console (DNS page),
then try again.`

**ngrok** (a service that gives your cluster a public address)

```
Which ngrok domain should the dashboard use?
For example kwatch.ngrok.app, or your own domain set up in ngrok.  [none]
```
Empty is not allowed (ngrok-operator needs a domain): `Type the domain
from your ngrok dashboard.` Notice, yellow, before the confirm:
`This makes the sign-in page reachable by anyone on the internet, and ngrok sees the traffic when it adds https. The password protects the dashboard.`
No DNS step, no certificate question, no IP list.

**Load balancer** (option 5)

Public or inside, only on AWS, Google Cloud and Azure (bare metal has no
such choice):

```
Who should be able to reach the dashboard?

  🌍 Anyone on the internet
     Pick this for people outside your network. The sign-in page is visible to everyone.
  🏢 Only inside our network
     Pick this for a team that works through an office network or VPN.
```
Cursor on inside. Maps to the cloud's internal-load-balancer annotation. For
MetalLB / kube-vip: pool question 7c.4 D, then
`Want a fixed address from that pool?` `[no, take any free one]` with an IP
validated to be inside the pool. After creating the Service wait up to 60 s
for an address (`status.loadBalancer.ingress`). If none:
`Your cluster hasn't given the load balancer an address yet.` / `Look at it with: kubectl -n kwatch get svc kwatch-dashboard` and `On MetalLB, check that the pool has free addresses.`

**NodePort** (option 6)

```
Which port should open on each machine?
Ports from 30000 to 32767. Press Enter to let the cluster choose.  [automatic]
```
Errors: `Pick a number from 30000 to 32767.`; `That port is already used by <svc> in <ns>.`
After creation, print the reachable addresses (first ExternalIP, else
InternalIP of up to 3 nodes) and:
`Anyone who can reach those machines on that port can open the sign-in page. If a machine goes away the link to it stops, so point your address at several machines.`

**Gateway / Istio**: no setup-specific question beyond the pick (7c.4). If
the chosen Gateway has no https listener: `That Gateway doesn't serve https.`
/ `Add an https listener with a certificate to it, or pick another.` If it
doesn't allow routes from `$NAMESPACE`: `That Gateway doesn't accept routes from the "kwatch" namespace.` / `Allow it in the Gateway's allowedRoutes, or pick another.` kwatch never edits a shared Gateway. Redirect from http to https is the Gateway's job; kwatch still refuses sign-in over plain http ([GAP 2]).

**OpenShift Route**: edge termination with the router's own certificate when
the address ends with the cluster's apps domain. For any other address:
certificate screen limited to `A certificate I already have` (the Secret's
certificate and key are copied into the Route; the dim line says so).
If the user picks another address and has no Secret:
`That address isn't under your cluster's apps domain, so OpenShift has no certificate for it.` / `Use the suggested address, or bring a TLS Secret.`

#### 7c.7 Confirm screen (nothing is created before this)

```
Share the dashboard at https://kwatch.example.com

  Way         Ingress (nginx, class "nginx")
  Certificate Automatic, from cert-manager ("letsencrypt-prod")
  Who         Only 203.0.113.0/24, with the password
  Sign-in     Password; plain http is refused

I will create:
  - an Ingress named kwatch-dashboard
  - a Certificate named kwatch-dashboard-tls

Enter to continue, Esc to go back, n to cancel
```

Lines per option:

| Option | "Way" line | Objects listed |
|---|---|---|
| 2 | `Ingress (<type>, class "<name>")` | Ingress; Certificate if automatic; ALB/GKE extras (ManagedCertificate, FrontendConfig) |
| 3 | `Gateway API (<ns>/<gateway>)` / `Istio (<ns>/<gateway>)` | HTTPRoute / VirtualService |
| 4 | `OpenShift Route` | Route |
| 5 | `Load balancer (<public/inside>[, <cloud>])` | Service of type LoadBalancer; Certificate if automatic |
| 6 | `NodePort <port>` | Service of type NodePort; Certificate if automatic |
| 7 | `Outside proxy` | Service (internal only) |
| 8 | `Service only` | Service (internal only); Certificate if automatic |

"Who" line: `Anyone who reaches the address, with the password` when there is
no list or it can't be enforced. "Certificate" line for the other cases:
`Your Secret "<name>"`, `Self-signed (browsers will warn)`, `AWS ACM`,
`Google managed`, `Handled by Tailscale` / `Handled by ngrok` / `Handled by
OpenShift`.

If an earlier setup exists, add (see 7c.10):
`This replaces the current setup. After the new one works I will remove: ...`

#### 7c.8 Option 7 gate: outside proxy

Shown after the address question and before the generic confirm. Title
`Before you continue` in yellow.

```
With this choice, kwatch itself does not use https.

Something outside your cluster (for example Cloudflare Tunnel) adds https and
forwards the traffic to kwatch as plain http. That part of the path is not
encrypted, and kwatch trusts whoever sends it traffic.

Only use this if all of these are true:
  - the proxy is the only way to reach kwatch from outside the cluster
  - the proxy sends people to https://kwatch.example.com
  - you manage who can reach the proxy

kwatch still asks for the password, and refuses sign-in unless the proxy
says the visit was over https.

Type yes to continue, or press Esc to choose another way:
```
- Only the typed word `yes` continues. Enter alone, `y` or anything else:
  `Type the word yes to continue, or press Esc.`
- Then the usual confirm screen (7c.7) with `Way  Outside proxy (you
  provide https)` and the objects: an internal Service only.
- No ingress or load balancer is created. After creating, print:
  `Point your proxy at this address inside the cluster:` `http://kwatch-dashboard.kwatch.svc.cluster.local:<port>` (copyable; use the real Service name, namespace and port) and `For Cloudflare Tunnel, set that as the service URL of your public hostname.`
- The installer sets `dashboard.trustProxy` so kwatch believes
  `X-Forwarded-Proto: https` and keeps the Secure cookie. [GAP 5] (core).
  Accepted (D15).

#### 7c.9 Create, wait, check

Busy lines (`ui_busy`), in this order, only those that apply:

1. `Setting up the dashboard...` (Secret with token and password kept or created, chart values set, kwatch restarted, 3.3 rollout rules and 90 s warning).
2. `Creating the Ingress...` (`the route`, `the load balancer`, `the NodePort`, `the Service`, as the option).
3. `Waiting for an address...` up to 60 s, as 3.4 step 5.
4. Print DNS instructions (3.5) when the address is a name that needs a record and the setup has one (not Tailscale, ngrok, OpenShift default address, or when the user typed an IP).
5. `Waiting for https at https://kwatch.example.com...` poll every 5 s for up to 120 s. Check made from the user's computer with a real https request to the sign-in page, with certificate checking on. The first line is replaced with the latest reason in dim: `waiting for DNS`, `waiting for the certificate`, `the cluster answered 503`.
   - Self-signed: the check ignores the certificate and tests only that kwatch answers; the success line says so.
   - Address resolves to a private IP and is unreachable from this computer: stop early with the "can't check from here" result below.

Results

Success (the check passed; only then):
```
✅ Ready at https://kwatch.example.com
```
then the password block (3.7), unchanged, then `ui_pause`.

Success, self-signed:
```
✅ Ready at https://kwatch.example.com
Your browser will warn about the certificate. That is expected: kwatch made it itself.
```
Success, couldn't check from here (private address):
```
Set up at https://kwatch.example.com
I can't open that address from this computer, because it is on a private network. Try it from a computer on that network or VPN.
```
(The word "Ready" is not used.)

Not ready after 120 s (yellow, then a menu):
```
The dashboard is set up, but https isn't answering yet.

<reason line>

  Check again
  Show how to set up DNS
  Leave it as it is
  Undo and go back
```
Reason lines (pick the first that is true):

| Case | Reason |
|---|---|
| name doesn't resolve | `kwatch.example.com doesn't point anywhere yet. Add the DNS record shown above; it can take a while to spread.` |
| name resolves elsewhere | `kwatch.example.com points to 198.51.100.4, but the cluster's address is 203.0.113.10. Update the DNS record.` |
| certificate pending | `The certificate isn't issued yet. It is issued after your DNS record exists. Check on it with "Show my access link and password".` |
| certificate failed | `The certificate request failed: <reason from the Certificate status>` / `Check that your DNS record points to the address shown, then choose "Check again".` |
| connection refused or timed out | `Nothing answered at https://kwatch.example.com.` / `Check that the address is open to you (firewall, security group) and try again.` |
| 404 / 502 / 503 from the front door | `The front door answered, but kwatch isn't behind it yet (error 503).` / `Check kwatch with "View status" in the main menu.` |
| certificate not trusted | `The address answered, but its certificate isn't trusted: <reason>.` / `Use a trusted certificate, or choose self-signed and accept the warning.` |
| ACM / Google certificate pending | `Google is still preparing the certificate. This can take a while after your DNS record exists.` / `AWS can't use that certificate yet: <reason>.` |

`Leave it as it is` ends with `Left as it is. Check later with "Show my
access link and password".` and prints the password block. `Undo and go
back` removes what this run created (7c.10 rules) and returns to the
Dashboard screen with the previous state.

#### 7c.10 Re-run, change, and cleanup

**Re-run.** The Dashboard screen for the shared state gets one more item,
`Change how it's shared` (decision D16), placed after `Reset password`:

```
Dashboard: shared at https://kwatch.example.com

  Show my access link and password
  Reset password
  Change how it's shared
  Switch to local only
  Turn off
  Back
```
The installer finds its own earlier objects by the label
`app.kwatch.dev/managed-by=installer` (or the chart values if core prefers).
`Change how it's shared` opens:

```
The dashboard is shared like this

  Link         https://kwatch.example.com
  Way          Ingress (nginx, class "nginx")
  Certificate  Automatic, from cert-manager ("letsencrypt-prod"), ready
  Who          Only 203.0.113.0/24, with the password

  Change it
  Keep it as it is
```
`Change it` runs the flow (7c.3 and on) with the cursor on the current way and every question prefilled with the current answer. `Keep it as it is` goes back.
If the cluster no longer matches (an object was deleted by hand), add a
yellow line under the table: `Something kwatch created is missing: <name>.`
and make `Change it` first and renamed `Repair or change`.

**Switching.** Anything created only by the installer, with its label, is
removed; anything else is never touched (a shared Gateway, an Ingress someone
made by hand, a Secret the user supplied). The new confirm screen lists
both sides:

```
This replaces the current setup.

  I will create:   a Load balancer Service
  I will remove, after the new one answers:
    - Ingress kwatch-dashboard
    - Certificate kwatch-dashboard-tls
```

Order:

1. Create the new objects.
2. Wait and check https (7c.9).
3. Only if the check passed, or the user chose `Leave it as it is`, delete
   the old ones. If the check failed and the user chose `Undo`, delete the
   new ones and leave the old setup untouched.
4. Exception: when the new setup would clash with the old one (same address,
   same kind of object), delete the old first and say beforehand:
   `The link will stop for a short while while I switch.`

After a successful switch: `Switched. The old setup is removed.` plus, if
the address changed: `You can remove the DNS record for kwatch.old.example.com whenever you like.` and the new DNS block.

**Switch to local only** (from shared, replaces nothing in 3.2 except the
confirm text):

```
Switch to local only?
The shared link stops working and what I created for sharing is removed. Your password stays the same.
```
Then 3.3 steps 3 to 7 (without the "Turn on" question).

**Turn off** (3.10 stays; the second dim line lists what goes, per option):
Ingress / HTTPRoute / VirtualService / Route / Service(s) / Certificate /
ManagedCertificate / FrontendConfig, only the labelled ones. For Tailscale
and ngrok: `The Tailscale device "kwatch" (or the ngrok endpoint) is
removed by the operator.` Does not touch DNS records, ACM certificates,
reserved Google IPs, user Secrets: say so in one dim line each when that was
used: `Your ACM certificate and your DNS record are not touched.`

**Show my access link and password** (3.6): the certificate line per way:

| Way | Line |
|---|---|
| cert-manager | `Certificate: ready` / `still being issued` / `failed: <reason>` |
| own Secret | `Certificate: from your Secret "<name>", expires <date>` |
| self-signed | `Certificate: self-signed (browsers warn)` |
| ACM | `Certificate: AWS ACM` |
| Google | `Certificate: Google managed (active)` / `(still being prepared)` |
| Tailscale, ngrok, OpenShift, Gateway | `Certificate: handled by <name>` |
| outside proxy | `https: added by your proxy` |
| Service only | link line is `Service: kwatch-dashboard in "kwatch", port <port> (https)` |

The Dashboard screen item `Open the dashboard` (D9) in shared state opens the link with the
system browser (`open` / `xdg-open` / `wslview`), or prints it.

**Reset password** (3.9): unchanged.

#### 7c.11 Service only: what is printed

```
Service created. kwatch serves https itself, with the certificate you chose.

  Service    kwatch-dashboard
  Namespace  kwatch
  Port       8443 (https)
  Address    kwatch-dashboard.kwatch.svc.cluster.local

Point your own ingress, gateway or proxy at that Service, and make sure it talks https to it.
To try it from this computer:
  kubectl -n kwatch port-forward svc/kwatch-dashboard 8443:8443
```
(The port is the chart's value. Do not show "Ready", there is nothing to
check. The password block follows. The Dashboard caption reads
`shared at your own address` when the address was left unknown.)

#### 7c.12 Errors (all flows)

| Case | Message |
|---|---|
| nothing applies | the dim line in 7c.2; menu still works for 1, 7, 8 |
| Secret missing for TLS | `The Secret "<name>" isn't in the "kwatch" namespace.` / `Create it there, or pick another.` |
| Ingress class vanished | `The ingress class "<name>" isn't in your cluster any more.` / `Pick another, or install a controller and try again.` |
| webhook refused (admission) | `Your cluster refused the Ingress: <first line of the error>` / `Some clusters have rules for which names or annotations are allowed. Ask whoever runs the cluster, then try again.` |
| permission | `Kubernetes said no: <first line of the error>` / `Your kubectl user needs permission to create Ingresses, Services and Certificates in the "kwatch" namespace.` (list only the kinds involved) |
| address taken | as 7c.5 |
| NodePort taken | as 7c.6 |
| cluster unreachable, kwatch not running, Community, too old | as 3.8 |
| rollout timeout | as 3.3 |
| half-created after a failure | `I couldn't finish: <reason>.` / `I removed what I had created, so nothing changed.` If removal failed too: list the leftovers with `kubectl -n kwatch get ingress,svc,certificate -l app.kwatch.dev/managed-by=installer`. |

#### 7c.13 Engineers' notes: layout, states, tokens, accessibility

- Installer only. Same `ui_*` helpers as the rest of `kwatch.sh`; no new
  colours. Yellow (`ui_warn`) only for the warnings quoted above; green only
  for `✅ Ready`.
- Menus: arrow keys, Enter, Esc back, `n` where the confirm says so. No
  mouse. Every screen is readable with colour off (`NO_COLOR`): the
  warnings start with a word (`Before you continue`, `The dashboard is set up,
  but...`), not only a colour. Emoji are decoration only; every label also
  reads on its own. If the terminal cannot show emoji (`TERM=dumb` or
  `NO_COLOR` with a non-UTF-8 locale), drop the emoji and keep the text.
- Narrow terminals (under 80 columns): captions wrap under the label; the
  confirm table becomes `Label: value` lines.
- Non-interactive stdin (piped): the Share flow refuses with `Sharing needs a
  terminal to ask you a few questions. Run the installer in a terminal.` It
  never picks a way by itself.
- Nothing prints the password except 3.7 and 3.6. The ACM ARN, Secret names
  and IPs are not secret and may be printed.
- Chart/binary values from the answers: `dashboard.enabled`, port,
  `dashboard.mode`, `dashboard.tls.secretName`, `dashboard.trustProxy`.
  Everything else (class or Gateway reference, address, certificate
  source, LB scheme and pool, NodePort, ALB ARN and scheme, GKE static IP
  name, AGIC frontend, Tailscale hostname, ngrok domain, allowed IPs) is
  an installer-created object, not a chart value.
- The installer applies the label `app.kwatch.dev/managed-by=installer` to
  every object it creates and removes only labelled objects (installer
  rule, not a core gap).

**Gaps for kwatch-core**

- **[GAP 2, repeated]** Refuse sign-in over plain http in shared mode.
- **[GAP 4]** `dashboard.tls.secretName`: kwatch serves https itself
  (user Secret, cert-manager Secret or a self-signed Secret the installer
  makes). Used for options 5, 6, 8 and the ALB, GKE and AGIC backends.
- **[GAP 5]** `dashboard.trustProxy`: accept `X-Forwarded-Proto: https`
  only when set (option 7).
- (GAP 3, kwatch-side allow-list: removed. GAP 6, label: now an installer
  rule above.)

**Claims to check with core before the copy ships:** "refuses sign-in
unless the proxy says the visit was over https" (GAP 5); "kwatch serves https
itself" for options 5, 6, 8 (GAP 4); "Only these addresses can open it" for
each row of the enforcement table (these are installer-created
annotations and Service fields, checked by kwatch-web, not by core).

#### Decisions (7c, answered 2026-10-28)

- **D12.** Yes: cursor on Local, one other way tagged recommended.
- **D13.** Dropped: no IP limit inside kwatch; asked only where the
  platform enforces it, never elsewhere.
- **D14.** Yes: cloud load balancers reach kwatch over https with kwatch's
  own certificate.
- **D15.** Yes: option 7 stays, with the warning and typed `yes`.
- **D16.** Yes: "Change how it's shared" is added to the shared state.
- **D17.** Yes: Tailscale and ngrok skip DNS, certificate and IP questions;
  no Funnel.
