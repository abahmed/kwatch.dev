# Landing: "What kwatch sends to kwatch.dev"

Owner: kwatch-designer. Implementer: kwatch-web (`apps/web/src/pages/index.astro`,
section `.band` / `.privacy`, replacing `.sends-wrap` + table + `.privacy-small`).
Layout and hierarchy only. Copy is approved in `../MESSAGING.md` and is reused
verbatim; do not reword. Status: proposed.

## Goal

Scannable and trustworthy: two data flows as two cards (When / Contains /
Control), config keys as code, and a distinct "Never sent" strip. No table, no
horizontal scroll.

## Structure (inside the existing `.privacy` grid, spanning `1 / -1`)

1. `<ul class="flows">` with two `<li class="flow">` cards.
2. `<p class="never">` strip below the cards.
The existing heading, lede, small print, link and `.facts` list stay as they are.

## Cards (`.flow`)

- Surface `--surface`, 1px `--line` border, radius 4px (match `.grid`/`.card`), padding 24px (20px at <=480px).
- Header: title as `<h3>` (Instrument Sans 600, 17px, `--text`). Optional small
  tag right of it in Geist Mono 13px `--text-muted`: none needed; keep the title only.
- Body is a `<dl>` with three rows, each a small label (`<dt>`, 13px, 600,
  `--text-muted`, uppercase not required) over its value (`<dd>`, 15px, `--text-soft`).
  Row gap 14px; rows separated by 1px `--line` top border (not the first).
- Use `dl`, not `table`, so each card reads as one unit to screen readers.

### Card 1: Anonymous usage stats
- When: At most once a week
- Contains: An anonymous ID derived from your cluster (a one-way hash that can't be traced back to the cluster or linked to your license) and the kwatch version
- Control: On by default; turn off with `telemetry.enabled: false` or `KWATCH_TELEMETRY=false`

### Card 2: Pro license check
- When: Once a day, Pro only
- Contains: License ID, hashed cluster ID, kwatch version, node count
- Control: Part of Pro; Community sends none

Labels are the current column headers: When, Contains, Control. The
"What" header becomes the card title.

## Code styling

Config keys: `<code>` in `--font-mono` (Geist Mono), 13.5px, `--text`,
background `--bg`, 1px `--line` border, radius 4px, padding 1px 6px,
`white-space: nowrap` above 480px; allow `overflow-wrap: anywhere` at <=480px so
`KWATCH_TELEMETRY=false` never forces scroll. Separate the two keys on their own
lines in the Control row if they do not fit; keep the word "or" between them.

## "Never sent" strip (`.never`)

- Full width under the cards, margin-top 16px.
- Background `--ink` (`--ink-text` text, `--ink-muted` for none), radius 4px, padding 16px 24px.
  Same ink in light and dark, so it stays the one inverted, calm block. Add
  `class="on-ink"` so focus rings invert.
- Content: a bold lead-in "Never sent:" (600) followed by the approved text
  "cluster names, namespaces, pod names, logs or events." Sentence: **Never sent:**
  cluster names, namespaces, pod names, logs or events.
- Optionally, the existing line "Alerts go only to the channels you set up." may follow in
  `--ink-muted` (it is already approved and used above).
- No icon, no Signal. Signal stays reserved for the page's one use.
- Font 16px, line-height 1.5.

## Responsive

- >960px: cards side by side, `grid-template-columns: repeat(2, minmax(0, 1fr))`, gap 16px.
  Card 1 is the longer one; let it be the same height via grid stretch.
- <=960px: still two columns down to 700px; below that stack, single column, gap 12px.
- <=480px: card padding 20px 18px, code wraps, strip padding 14px 18px. Nothing scrolls horizontally.
- Remove `overflow-x: auto` from the wrapper (no longer needed).

## Dark mode

Uses only tokens that already switch: `--surface` (#1E2126), `--line`, `--text`,
`--text-soft`, `--text-muted`. Code chips use `--bg` so they sit one step darker
than the card. The strip stays `--ink` (#0E1116) on `--bg` #15171B: confirm it
still reads as a distinct block; if it looks flat, add a 1px `--ink-line` border.
No new colours.

## Accessibility

- Heading order: `h2` section title, then `h3` per card.
- Each card is a list item; the `dl` pairs give label/value semantics.
- Contrast: `--text-muted` on `--surface` is 5B6270 on F2F3F0 (about 5.3:1);
  `--text-soft` on `--surface` is higher. In dark, check muted labels on #1E2126.
- Strip text `--ink-text` on `--ink` is well above 4.5:1.
- Keep the "What is sent" link (focus ring unchanged).
- No colour-only meaning: the strip is labelled in text.

## Not changing

Section heading, lede, small print, link, `.facts`, and every word of the
approved data copy.
