# Merge License and Clusters into one page (app.kwatch.dev)

Status: FINAL (approved decisions applied). Design only. Scope: `apps/app` routes `/licenses` and `/clusters`.

## 1. Current state

**Routes** (`App.tsx`): `/` goes to `/licenses` when signed in. `/licenses` and `/clusters` are separate sidebar items ("Licenses", "Clusters"), then "Get help", "Account". Other links: Help has "Back to clusters" (`/clusters`).

**Licenses** (`pages/Licenses.tsx`, data from `GET /account`): one card per license. Shows Pro + status badge (active / not activated / expired / revoked), masked key and end date, and the attached cluster (name, version, nodes, last check) or "Add it with the installer". Actions: Copy key (primary), Show/Hide key, Move to another cluster (only when attached; limited by `transfers_left` per month), Replace key (quiet; hidden when revoked). Header: "Free Pro clusters: N of 2 used" (account or company-domain scope). Empty + eligible: "Get your free Pro license." with `Get a free Pro license` and 3 installer steps. At limit: `LimitNotice`.

**Clusters** (`pages/Clusters.tsx`, `useClusters`, `GET /account/clusters`): table (cards on mobile) with Cluster (name + short id), License (lid), Last seen, Status pill with detail text (Checking in, Waiting, Silent since, Stopped, Back at, Check-ins off, Not attached), Version, Nodes. Refresh link, reloads on tab focus, no polling. "How this works" panel (30 min check-in, silent after 60 min, no messages sent). No actions. Empty: "No clusters yet..."

**Overlap and problems**
- Cluster rows carry a `license` column, so every cluster is already a child of a license. Users bounce between pages to answer "is my key working?"
- The licence card shows `last_renew` and node count; the Clusters page shows `last_seen` and state. Two sources for the same fact, with different wording.
- Inactive/stopped warnings live only on Clusters, but the fix (Replace key, Move) lives only on Licenses.
- Data model: one license runs exactly one cluster, up to 2 licenses per account or company. So the relation is 1 license : 0 or 1 cluster. "Seat usage" is therefore not a per-license bar; it is the account-level "N of 2 free Pro licenses used". Clusters exist only tied to a license; a moved or replaced license's old cluster is deleted or overwritten, never tracked or shown.

## 2. Proposal: one page, "Licenses" at `/licenses`

Principle: the license is the object; its cluster is the license's live state. One card per license, the cluster is the second half of the card, not a separate list.

### Desktop (content column, sidebar unchanged except one fewer item)

```
Licenses                          2 of 2 free Pro licenses used  [Refresh]
                                               kwatch.example (shared by your domain)
+----------------------------------------------------------------------------------+
| PRO   active                                   Key  kw_pro_...a91f  [Show] [Copy]|
| Free during early access · ends 14 Jan 2027                                      |
|----------------------------------------------------------------------------------|
| Cluster                                                                          |
| prod-eu-1        Checking in        Last seen 4 min ago    v0.15.2    6 nodes    |
| 7f3a9c1e                                                                         |
|----------------------------------------------------------------------------------|
| [Copy key] [Show key]                      [Move to another cluster] Replace key |
+----------------------------------------------------------------------------------+
+----------------------------------------------------------------------------------+
| PRO   active                                   Key  kw_pro_...c02d  [Show] [Copy]|
| Free during early access · ends 14 Jan 2027                                      |
|----------------------------------------------------------------------------------|
| Cluster                                                                          |
| staging          Inactive since 10:01    Last check-in 09:00   v0.15.1   2 nodes  |
| a21b0d44         kwatch stopped talking. Your apps may be fine, but kwatch       |
|                  cannot alert you while it is inactive. Run                        |
|                  kubectl -n kwatch get pods                                      |
|----------------------------------------------------------------------------------|
| [Copy key] [Show key]                      [Move to another cluster] Replace key |
+----------------------------------------------------------------------------------+
How cluster check-ins work   (small panel, unchanged copy)
```

Rules:
- Card top = license (plan, status badge, end date, masked key). Card middle = its cluster row (same fields and state pills as today's table). Card footer = the existing action footer from `license-card-actions.md`, unchanged hierarchy (Copy key solid Ink, Show outline, Move outline, Replace quiet). Signal is not used on cards.
- Status badge and cluster pill stay separate: the badge is about the license (active, expired, revoked), the pill about the cluster (status colours only inside alerts, as today).
- Order: licenses needing attention first (Inactive, Expired, then Stopped), then newest first.
- Header right: account-level usage "2 of 2 free Pro licenses used" replaces the old "Free Pro clusters" line. With scope `organization`, add the domain.
- The standalone Cluster table is removed. Detail text under the pill is unchanged (existing `clusterView` copy).

### Mobile (under 640px)

```
Licenses
2 of 2 free Pro licenses used
[Refresh]
+------------------------------+
| PRO  active                  |
| ends 14 Jan 2027             |
| kw_pro_...a91f  [Show]       |
|------------------------------|
| prod-eu-1        7f3a9c1e    |
| Checking in                  |
| Last seen 4 min ago          |
| v0.15.2 · 6 nodes            |
|------------------------------|
| [Copy key]  (full width)     |
| [Show key]  (full width)     |
| [Move to another cluster]    |
| Replace key                  |
+------------------------------+
```
Cards stack; actions stack full width, 44px targets, Copy key first. The table and `cluster-cards` list are both removed.

### States of the cluster half

| License state | Cluster half shows |
|---|---|
| Active, no activation, no cluster | "Not attached yet." + "Add the key in the installer: License / Pro > Add or replace key. It appears here after the cluster's first check-in." Move is hidden. |
| Cluster state waiting | Pill "Waiting" + existing detail |
| ok (Active) / back / Inactive / stopped / off | Existing `clusterView` pill, last seen, detail |
| License expired | Cluster row stays, pill unchanged; line above: "This license ended on {date}. kwatch is on Community; alerts still work." Actions: Replace key hidden only when revoked (as today). |
| Revoked | As today, plus no cluster actions |
| Cluster load failed | Cluster half shows "Cluster status unavailable. Try again." with a `Try again` button that reloads clusters. The license half still renders. No fallback to stale `/account` activation data. |
| Loading | License half renders from `/account`; cluster half shows a one-line skeleton |

### Empty states (no license)
- Eligible: keep the current screen. H1 "Get your free Pro license." Body unchanged. Button `Get a free Pro license` is the page's one Signal element. Steps 1-3 unchanged.
- At limit with no license: `LimitNotice` as today.
- Has licenses and is under the 2-license limit: "Get another free Pro license" button (quiet outline, not Signal) after the last card, with "You can have 2. One license runs one cluster."

### Multiple licenses
The model allows up to 2 (by account or company domain), so the page is a list of cards, never tabs. Each card is independent. Anchors per license `#lic-{lid}` so Help and emails can deep link. Help's "Back to clusters" becomes "Back to licenses".

## 3. Navigation and routes

- Sidebar: "Licenses" and "Clusters" become one item: **Licenses** (`/licenses`). Order: Licenses, Get help, Account, Docs.
- Keep `/licenses` as canonical (the API and docs already say "license"; `/` already goes there).
- `/clusters` redirects to `/licenses` (`<Navigate replace>`; query kept). Old bookmarks and any email links keep working. No `_redirects` change needed (SPA fallback).
- `/clusters#<anything>` also lands on `/licenses`; no separate anchor mapping needed.
- Page title: "Licenses".
- `useClusters` still feeds Help; the merged page joins clusters to licenses by `cluster.license === license.lid`. Help's selector logic is unchanged.

## 4. Copy

| Where | Copy |
|---|---|
| Sidebar, H1, title | Licenses |
| Usage line | `{used} of {limit} free Pro licenses used` (+ ` · {domain}` when shared) |
| License line | `Free during early access · ends {date}` / `ended {date}` when expired |
| Cluster section label | Cluster |
| No cluster | Not attached yet. Add the key in the installer: License / Pro > Add or replace key. It appears here after the cluster's first check-in. |
| Expired line | This license ended on {date}. kwatch is on Community; alerts still work. |
| Refresh | Refresh |
| Buttons | Copy key / Show key / Hide key / Move to another cluster / Replace key / Try again / Get a free Pro license / Get another free Pro license |
| Empty H1 | Get your free Pro license. |
| Empty body | Pro is free during early access. Each license is free for 3 months and we may renew it. One license runs one cluster. You can have 2. |
| Check-ins panel | Unchanged ("How this works", renamed "How check-ins work") |

No prices, no "trial", no emoji. Licenses are managed only through the installer; the page only issues and replaces keys, as today. "Move" copy and dialogs are unchanged.

## 5. Tokens and accessibility

- Existing tokens only; no new colours. Card = existing `.license` surface; cluster half separated by a hairline using `--line`-strong (3:1 per the actions spec). Signal at most once per view (the empty-state button only).
- Each card is a `section` labelled "License {lid}"; the cluster half is a `role="group"` labelled "Cluster for license {lid}". Status pills keep text, never colour alone.
- Inactive/stopped detail is announced with `role="status"` only on change after Refresh; initial load is not announced.
- Focus order per card: key actions, manage actions. Dialogs unchanged.
- Dark: same tokens as today; Signal #B5DE3C.
- Touch targets 44px on mobile.

## 6. Engineering notes (no code here)

- Join in the page, not in the API: `licenses` from `/account` plus `clusters` from `/account/clusters`.
- Move `clusterView`/Pill into a shared module so the card can use it; delete `Clusters.tsx` and its table/card CSS after the redirect lands. Tests in `clusters.test.tsx` and `licenses.test.tsx` merge.

## 7. API dependency

kwatch-api must delete or replace the old activation/cluster record when a license is moved (`/transfer`) or its key is replaced (`/regenerate`). Otherwise the old cluster would linger as a `detached` row. The UI shows no detached state: `GET /account/clusters` must not return clusters without an active license, and the app should ignore any `detached` row defensively.

## 8. Decisions (final)

1. Page and nav name: "Licenses". The cluster is part of each license card.
2. Cluster request fails: license card stays, cluster half shows "Cluster status unavailable. Try again." with a retry button. No stale fallback.
3. No unlicensed clusters.
4. "Get another free Pro license" shows while the user is under the 2-license limit.
5. One cluster per license. Move or replace overwrites it; kwatch-api enforces that.
6. Sort attention-first (Inactive or Expired, then Stopped), then newest.
7. No "within 30 minutes" promise; copy says "appears after the cluster's first check-in".

## 9. Visual design (shared brand system)

Source of truth: `packages/brand/tokens.css`. The mockup `license-clusters-merge.html` (same folder) renders every value below in light and dark, desktop and mobile. Cross-site gaps are in `cross-site-consistency.md`; this section assumes those fixes (shared control tokens, one font set).

### Tokens (no new colours)

| Role | Light | Dark |
|---|---|---|
| Page `--bg` | #FFFFFF | #15171B |
| Cluster half and quiet fills `--surface` | #F2F3F0 | #1E2126 |
| Hairlines, card outline `--line` | #DADDE2 | #2A2E35 |
| Text `--text` / muted `--text-muted` | #0E1116 / #5B6270 | #ECEDEA / #9AA0AA |
| Control outline `--control-border` (3:1) | #7C828E | #6B7280 |
| Primary hover `--primary-hover` | #2A2F38 | #FFFFFF |
| Signal `--signal` / `--on-signal` | #C8F542 / #0E1116 | #B5DE3C / #0E1116 |
| failing / degraded / resolved (+ `-bg`) | tokens.css | tokens.css |
| **Proposed** `--success` / `--success-bg` (no green exists in tokens.css; add it) | #1E6B3A / #E6F4EA (5.7:1) | #7FD99A / #1A3326 (8.0:1) |

Type: H1 Bricolage Grotesque 800, 30px (mobile 26), -0.03em, line 1.1; empty H1 40px (mobile 32), -0.035em, line 1. License name Instrument Sans 600 18px. Body 15px; small 14px. Everything from the cluster in Geist Mono: key (13px), cluster id (13px), version (14px), `kubectl` command (13px). Section label "Cluster" Geist Mono 12px, `--text-muted`.

### Components

- **Page head:** H1 left; usage line right, 14px `--text-muted`, the count in Geist Mono 500 `--text` ("2 of 2"); Refresh is an underlined text button, 14px. Wraps under the H1 on mobile.
- **Card:** 1px `--line`, radius 10px, overflow hidden, gap 12px between cards (22px above the first). No shadow, no fill, no gradient. Three bands separated by 1px `--line`: license head (padding 20 22; mobile 16), cluster row (`--surface` fill, padding 16 22; mobile 14 16), action footer (padding 16 22).
- **License header:** "Pro" 600 18px + badge (12px 500, radius 6, padding 2 8). Badge colour: `active` is neutral (`--text` on `--bg`, `--line` border); `expired` and `revoked` use failing/-bg; `suspended` uses degraded/-bg. The license badge `active` stays neutral; green appears only on the cluster's Active pill. Sub line 14px `--text-muted`: "Free during early access · ends 14 Jan 2027". Masked key right-aligned, Geist Mono 13px, left-aligned on mobile.
- **Cluster row:** grid 3fr 3fr 3fr 2fr 1.4fr (name+id, pill, last seen, version, nodes), gap 12 16. Detail text spans all columns, 14px, max 62ch. Mobile: 2 columns, name spans both.
- **Status pills** (13px 600, radius 999, padding 2 10). State comes from the API (`state` plus `last_ping`, `last_state`); the app does not keep history, only the latest signal:
  - **Active:** last check-in within 60 minutes. `--success` on `--success-bg`, no border. Text "Active".
  - **Inactive:** last check-in more than 60 minutes ago. `--degraded` on `--degraded-bg`, text "Inactive since 10:01 UTC" (cutoff plus one minute).
  - **Stopped:** the cluster sent state "stopping" (clean shutdown). Neutral: `--text` on `--surface`, `--line` border, not a warning. Text "Stopped at 14:05 UTC". Detail: "kwatch was shut down cleanly. It shows Active again when it starts."
  - **Expired:** unchanged (`--degraded` line on the license).
  - **Check-ins off:** API state `off` (the user turned check-ins off in the installer). Neutral pill (`--text` on `--surface`, `--line` border), text "Check-ins off", no warning. Detail: "Check-ins are off for this cluster." No last check-in is shown.
  - **Waiting:** neutral pill, text "Waiting", detail as today.
  - **Mapping from API state:** ok and back -> Active; silent and inactive -> Inactive; stopped -> Stopped; off -> Check-ins off; waiting -> Waiting. The old "Back at" pill is retired (back is Active).
  - **API filtering:** clusters whose license is revoked or expired are filtered out by the API, so the app never shows a cluster for those; the license card then shows its own state with no cluster row.
  - "Last check-in 14:00 UTC" sits next to the pill in Geist Mono 13px `--text-muted` (tooltip holds the full UTC stamp). A neighbouring line reads "Inactive after 15:00".
  - Colour never carries state alone.
  - **Check-in window note:** kwatch checks in every 30 minutes with about +/-2 minutes of random timing, so one or two late check-ins are normal. That is why the Inactive cutoff is 60 minutes, not 30. One config value, `INACTIVE_AFTER_MINUTES = 60`, in `apps/app/src/config.ts` feeds the pill and the "Inactive after" line. kwatch-core owns the interval.
  - **Sort order:** Inactive and Expired first, then Stopped, then Waiting and Check-ins off, then Active; newest first within each.
- **Buttons** (pill radius 999, 44px min height, 1.5px border, 15px): Copy key = solid `--text` fill, `--bg` text, 600, min 112px; hover `--primary-hover`; active translateY(1px). Show key, Move, Try again, Get another = outline `--control-border`, hover `--surface` + `--text` border. Replace key = quiet text, `--text-muted`, underline on hover. Danger red only inside the Replace dialog. Disabled opacity .5.
- **Empty state:** 7fr/5fr grid, gap 40, min-height 280. H1 big, lead `--text-muted`, steps list 15px `--text-muted` with the installer command in Geist Mono 13px. The "Get a free Pro license" pill is the one Signal element (`--signal` fill, `--on-signal` text, 600).
- **Spacing:** 4-based scale: 8, 12, 16, 20, 22, 28, 40. Content padding 32 36 desktop, 20 16 mobile. Sidebar 200px.
- **Radius:** 10px cards and panels, 999px pills and buttons, 6px badges, 8px inputs.
- **Focus:** 2px `--text` outline, offset 2px (shared value to be 3px/3px per cross-site doc).
- **Motion:** only 120ms background/border-colour transitions on buttons; skeleton is static; all motion under `prefers-reduced-motion: no-preference`. No page transitions.
- **Mobile (<=640px):** sidebar becomes a top bar (mark + wordmark, then links wrapped); cards stack; key actions two-up; Move and Replace full width stacked; empty button full width.
- **Dark:** swap tokens only; Signal becomes #B5DE3C; no other values change.
- **Signal rule:** the logo point is brand chrome shared by all three sites. The only content Signal on this page is the empty-state button; licensed views use none, so "Get another free Pro license" is an outline button.

### Open item for kwatch-core
kwatch-core confirms the 30-minute interval with about +/-2 minutes of jitter and that the app sees state "stopping" as `stopped`. If the interval changes, update the one config value; the "How check-ins work" panel follows.
