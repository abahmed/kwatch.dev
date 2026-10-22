# Landing redesign: one system for index and Pro

Owner: kwatch-designer. Implementer: kwatch-web (`apps/web/src/pages/index.astro`,
`pro.astro`, `styles/global.css`, `components/`). Layout and hierarchy only.
Approved copy (MESSAGING.md) is reused verbatim; copy issues are listed
separately at the end. Existing tokens only, no new colours. Status: proposed.
Supersedes the earlier data-section-only draft; that section is now case 1 of
the shared card pattern.

## Audit: what is inconsistent today

| Area | Today | Problem |
|---|---|---|
| Section padding | 110 (`.section`), 100 (`.section-tight`), 90 (faq), 120 (cta), Pro page 72/80/90/96/100 | Seven vertical rhythms |
| H2 size | `h2-lg` 36-60, `h2-md` 34-52, faq 40, Pro 30-44, cta 48-104 vs 44-80 on Pro | Four to five scales for the same role |
| Radii | 4, 6, 8, 10, 14, 999 | Cards 10 (editions, Pro cards), 8 (glossary), 6 (facts, trace) |
| Cards | `.edition` (2px border), Pro `.card` (surface, 1px), `.facts`, `.grid` cells, data table | Five card looks |
| Tables | Landing `.sends` (scroll wrapper), Pro compare (min-width 640, scroll) | Landing one goes away; Pro compare keeps scroll but needs a mobile fallback |
| Buttons | `.btn-primary` (Pro page hero) vs `.btn-solid` (landing) vs `.btn-line` | Same role, two fills; `.big` defined twice |
| Section headers | Eyebrow + H2 on some sections, none on Pro, icon inside the H2 on Pro data section only | Icon use inconsistent |
| Dark mode | `.terminal` hard-codes `#000`; `.item i` uses `--text-muted` on ink | Off-token |
| Mobile | Several grids collapse at 960 and 480 independently | Breakpoints differ per section |

## System

### Scales (use these only)
- **Space:** 4, 8, 12, 16, 24, 32, 48, 64, 96. Section vertical padding:
  96px desktop, 64px at <=960px, 48px at <=480px (one `.section` class; drop
  `.section-tight`, faq-inner and Pro's ad-hoc values). Hero and CTA keep their own.
- **Type:** display H2 two sizes only. `h2-lg` = clamp(36px, 3vw+24px, 60px) for
  the section's lead statement (how, install, pro). `h2-md` = clamp(30px,
  1.6vw+24px, 44px) for everything else (data, catches, quiet, faq, and every Pro
  page section). Card title (h3) = Bricolage 700 24px. Body 17px, small 15px,
  micro 13px. Mono labels 13px.
- **Radius:** 4px for chips, code and inline controls; 10px for every card and
  panel (replace 6px and 8px on `.facts`, `.glossary`, `.trace`, `.noise`, `.cmd`);
  999px for buttons and the Pro badge only. Hero alert card keeps 14px (it is the
  product's output, not site chrome).
- **Lines:** 1px `--line` for dividers and card borders; 2px `--text` for one
  emphasis (the "How" step rule, comparison header). The `2px solid` borders on
  `.edition` become 1px `--line` (Community) and 1px `--control-border` (Pro).

### Shared component: `Panel` (specify once, reuse everywhere)
`components/Panel.astro`, props: `title` (string), `as` (`li`|`div`),
`tone` (`default`|`soft`), slot for body. Replaces `.edition`, Pro `.card`,
the data-flow cards and the `.facts` items.
- Box: radius 10px, 1px `--line`, padding 24px (20px at <=480px). `default` =
  `--bg` fill; `soft` = `--surface` fill. Use `soft` on `--bg` sections and
  `default` inside `.band` (which is `--surface`), so a panel always differs from
  its ground in both themes.
- Title: `h3`, Bricolage 700 24px, line-height 1.2, `--text`. Optional sub line
  under it 15px `--text-muted`.
- Rows: a `<dl class="rows">`, label (`dt`, 13px 600 `--text-muted`) over value
  (`dd`, 15px `--text-soft`), 12px between rows, 1px `--line` hairline above rows
  2+. Rows never become columns inside a panel; the panel stays one reading unit.
- Code chip (`<code>`): Geist Mono 13.5px, `--text`, `--bg` fill when the panel is
  `soft` and `--surface` fill when `default`, 1px `--line`, radius 4px, padding
  1px 6px. Wraps with `overflow-wrap: anywhere` at <=480px.
- Footer slot: 24px above, holds the panel's button/link.
- Grid helper `.panels`: `repeat(auto-fit, minmax(min(320px, 100%), 1fr))`, gap 16px
  (editions use `5fr 7fr` above 960px, gap 16px). Stacks to one column below 700px.
No other card variants. `.grid` cells and `.benefits` stay as a divided grid
(1px gaps on `--line`), already consistent; give them the same 10px outer radius.

### Buttons
One hierarchy everywhere: `.btn-solid` (primary on `--bg` sections and on ink/signal
bands), `.btn-line` (secondary), text link with arrow (tertiary,
`link-strong`). Retire `.btn-primary` on `pro.astro` hero in favour of `.btn-solid`
(same look in light; in dark it flips, which `.btn-solid` already avoids by
using ink). Move `.big` (18px, 18/32 padding) to `global.css` once. Min height
44px stays.

### Section header pattern
Eyebrow (mono 13px `--text-muted`) -> H2 (`display`, 12px above) -> optional lede
(18px `--text-soft`, 16px above, max 60ch). Every section uses it; Pro page adds
eyebrows ("Early access", "Get Pro", "Compare", "Data", "License"). Icons never
sit inside an H2: remove `BenefitIcon` from the Pro data H2; icons live only in
the benefits grid and as the 20px mark in a panel header when a panel needs one.
Left-aligned, never centred; faq H2 aligns to the same left edge as the others.

## Sections (index)

1. **Header/hero:** keep layout. Align h1 clamp across index and Pro to one
   value (`clamp(48px, 4vw+32px, 92px)`). Buttons: solid + line.
2. **Failure strip:** token fix only: `.item i` uses `--ink-muted`. Respect reduced
   motion (already).
3. **Data band** (case 1 of Panel): `.band`. Heading, lede, small print and link as today; `.facts` stay a quiet list with 10px radius. Full width below: two `Panel tone=default`, then the Never-sent strip. Table, `.sends-wrap` and horizontal scroll removed.
4. **Quick steps + benefits:** shared header pattern; benefits grid radius 10px;
   steps h3 24px (already). `.glossary` uses Panel box (10px).
5. **How:** keep the 4/5/3 uneven grid and 2px rule (the one emphasis); step h3 28px
   becomes 24px to match card titles. Trace chips radius 4px.
6. **Catches (`.band`):** header pattern with H2 `h2-md`; grid unchanged, radius 10.
7. **Quiet:** unchanged layout; `h2-md`.
8. **Install (`on-ink`):** replace `#000` terminal with `--ink` on `--ink-line` border
   (stays distinct in both themes); radius 10px.
9. **Editions:** two `Panel`s, `5fr 7fr`. Community = `default`, Pro = `soft` with
   `--control-border` outline. Both get the same row structure, so Support lines
   line up: row label **Support**, values exactly: Community "Support on GitHub.";
   Pro "Dedicated support." (current approved strings). Rows under Pro also
   keep the existing body paragraph above them. Buttons in the footer slot, aligned
   to the bottom of both panels (panels stretch; footer `margin-top:auto`).
10. **FAQ:** header pattern, `h2-md`; details rows keep 1px dividers; summary 19px.
11. **CTA (Signal band):** the one Signal use on the page. Same H2 clamp as Pro CTA
    (`clamp(44px, 4.4vw+24px, 80px)`) and 96px padding on both pages; `.btn-solid.big`.

## Data section content (Panel instances)

Panel "Anonymous usage stats": When "At most once a week"; Contains "An anonymous
ID derived from your cluster (a one-way hash that can't be traced back to the
cluster or linked to your license) and the kwatch version"; Control "On by default;
turn off with `telemetry.enabled: false` or `KWATCH_TELEMETRY=false`".
Panel "Pro license check": When "Once a day, Pro only"; Contains "License ID,
hashed cluster ID, kwatch version, node count"; Control "Part of Pro; Community
sends none". Row labels are the old column headers (When, Contains, Control);
"What" becomes the panel title.

**Never-sent strip:** full width, margin-top 16px, `--ink` fill, `--ink-text`,
radius 10px, padding 16px 24px (14px 18px at <=480px), `class="on-ink"`, 16px text:
"**Never sent:** cluster names, namespaces, pod names, logs or events." Optional
second sentence in `--ink-muted`: "Alerts go only to the channels you set up." No icon,
no Signal. If it reads flat on dark `--bg`, add 1px `--ink-line`.

## Pro page (pro.astro) alignment

- Hero: `.btn-solid` instead of `.btn-primary`; h1 clamp shared; badge stays pill.
- `.cards` become `Panel` (`soft`), same `5fr 7fr`, same row structure; `.label`
  stays as the mono eyebrow inside the panel.
- Sections use the shared padding (96/64/48) and `h2-md` (already 30-44; set the
  exact clamp). Add eyebrows per the header pattern.
- Data section: drop the inline icon; reuse the exact data band and the two Panels
  plus the Never-sent strip from index (extract to `components/DataFlows.astro`
  so both pages render one source; no separate copy to drift).
- Steps: keep numbered circles; step cards stay open (2px rule is the shared
  emphasis); `.cmd` radius 4px, mono 13px, matching the code chip.
- Compare table: keep it (a true matrix). Keep scroll wrapper on desktop; at
  <=640px render each row as stacked label + Community + Pro lines (`display:block`,
  data-label via `::before`), so no horizontal scroll on phones. Pro column header
  stays ink fill. Group rows keep mono 13px labels.
- Support block above the table: `h3` 24px (not 22 / 800), same body style.
- License `dl`: unchanged (stacks at 560); align breakpoint to 700.

## Breakpoints (single set)
>960 desktop; 700-960 tablet (two columns where it fits, hero and splits stack at
960); <700 single column; <=480 reduced padding as above. Replace the current
960/640/560/480 mix with 960, 700, 480.

## Dark mode
Only tokens that already switch. Panels differ from ground via `--bg`/`--surface`
swap (noted above). Ink blocks (strip, install, hero alert, Pro column header) are
same in both modes; verify each has a 1px `--ink-line` edge on dark `--bg`
(#15171B). Signal CTA uses `--signal` (#B5DE3C in dark) with `--on-signal`.
Check `--text-muted` on `--surface` (#1E2126) for 13px labels: it is #9AA0AA, about
6:1, passes.

## Accessibility
Heading order h1, h2 per section, h3 per Panel. `dl` rows give label/value
semantics; the stacked compare rows keep `th scope=row` or use `aria-label`
equivalents so the matrix is still announced. All buttons min 44px. Focus ring
unchanged (3px `--text`, inverted on ink/signal). Strip text and ink panels pass
4.5:1. Reduced-motion rule kept for the strip.

## Copy issues (flagged, not changed)
1. Pro editions card says "free for 3 months and we may renew them"; check against
   MESSAGING.md early-access wording before launch (no "trial").
2. Landing FAQ states "turn them off with telemetry.enabled: false" but omits
   `KWATCH_TELEMETRY=false`, which the table lists; align on next copy pass.
3. Landing small print omits "namespaces" ("Never cluster names, pod names, logs
   or events") while the table and FAQ include it; the longer list is the approved one.
4. Community card says "Support on GitHub." and Pro "Dedicated support." with no
   label; the new Support row label makes them read correctly, but MESSAGING.md
   should confirm "Support" as the label.
5. Pro "Compare editions →" uses an arrow glyph; fine, but check it is not an icon font.
