# Homepage copy spec, v1.2.0 (kwatch.dev/)

Owner: kwatch-web (`apps/web/src/pages/index.astro`). Copy only. Designer review before merge.
Verified against `reports/v1.2.0-changes.md` and `kwatch/internal/dashboard` (browser notifications: `web/js/notify.js`, page-side `Notification`).

## 1. Benefits grid (lines 52-59): stays 6 tiles, 3 columns

Removed tile, stated explicitly: **"Who changed what"** is replaced by the dashboard tile. Reason: the Pro card already says "who made the change", so the tile repeated it. No 7th tile; the grid stays full.

| Tile | Before | After |
|---|---|---|
| who -> dashboard | `['who', 'Who changed what', 'See who changed what, and when.']` | `['dashboard', 'A dashboard in your cluster', 'Read-only, in your browser, with browser notifications.']` |
| next (item 3) | `['next', 'The next step', 'Every message ends with the command to run.']` | `['next', 'The next step', 'With Pro, every message ends with the command to run.']` |

Other four tiles unchanged. Marquee, no Install pill: untouched.


### Icon
`BenefitIcon.astro` has: root, quiet, who, next, channels, data. After this change `who` is unused on the homepage (keep it in the file, other pages may use it). **A new icon `dashboard` is needed**, same 24x24 stroke style as the others, no fill, no stock look:
`dashboard: 'M4 5h16v14H4zM4 10h16M10 10v9'` (a frame, a header bar, one column divider). Engineers may nudge the path to match stroke weight; designer to review the render.

## 2. Pro card body (line 262)

Before:
`Every detector. The full proof and who made the change. Unlimited channels with routing and threads. History, audit log, maintenance windows and runbooks.`

After:
`Every detector. The full proof and who made the change. A read-only dashboard with browser notifications. Unlimited channels with routing and threads. History, audit log, maintenance windows and runbooks.`

## 3. "The next step" tile
Covered in section 1. Fix commands are presented as a Pro benefit, no caveat words ("only", "not", "limited").

## 4. Community card body (line 257)

Before:
`Apps that keep crashing (crash loops, out-of-memory kills), pods stuck waiting and servers that go down (NotReady nodes), explained in one line and sent to one channel.`

After:
`Apps that keep crashing (crash loops, out-of-memory kills), pods stuck waiting and servers that go down (NotReady nodes), each with its type of cause named and sent to one channel.`

## Repetition check
- Dashboard appears in the tile (what it is: read-only, browser, notifications) and the Pro card (list item). The card is a feature list, the tile is the benefit; no third mention on the page.
- "who made the change" now appears once (Pro card); the old tile is gone.
- "command to run" appears once (tile).
- Hero card and trace example (lines 131-184) are unchanged; they show real output and should not be touched.

## Rules check
No prices, no "trial", no forecasting words, no emoji. "Pro" named only where the benefit is Pro (tile 3, card). "Source available" not touched.

## Notes for engineers
- Tile titles in sentence case; title max about 30 characters so it wraps cleanly at 3 columns, 2 columns (tablet) and 1 (phone).
- Icon uses `currentColor`, so dark mode follows automatically. Keep `aria-hidden` on the icon; the title carries the meaning.
- Check `og`/meta description (line 111) needs no change: it does not mention the next step command wording.

## Open flag
`apps/web/src/pages/pro.astro` currently has no mention of "dashboard" in a grep (only "kwatch fixes" queue wording). If the lead believes it already covers the dashboard, confirm the right file; homepage and Pro page must say the same thing (cross-site-consistency.md).
