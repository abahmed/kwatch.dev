# Blog spec (blog.kwatch.dev)

Owner: kwatch-blog (`apps/blog`, Astro + MDX, static). Copy follows
`MESSAGING.md` section 9. Designer review before merge.

Mockups (light, dark, mobile 375): `specs/blog/Blog-Home.dc.html`,
`Blog-Post`, `Blog-Tag`, `Blog-Author`, `Blog-404`, `Blog-Search`. The same
files are in `kwatch.dev-design/project/`. Launch post outlines:
`specs/blog/launch-post-outlines.md`.

## Principle: same identity as every kwatch site

The blog has no look of its own. It reuses what kwatch.dev and docs already
ship. Do not define new colours, radii, buttons or code styles. Only the
blog-specific pieces below are new, and each is built from existing parts.

## Shared elements: use these, do not redefine

| Element | Source of truth |
| --- | --- |
| Tokens (colour, space, radius, type sizes, `--measure`, breakpoints 960/700/480) | `packages/brand/tokens.css`, `fonts.css` |
| Logo | `apps/web/src/components/Logo.astro`, 26px in the header |
| Header | `apps/web/src/components/Header.astro` pattern: logo + `kwatch`, nav on the right, wraps under the logo at <=640px |
| Footer | `apps/web/src/components/Footer.astro` pattern |
| Buttons | web `.btn`, `.btn-solid`, `.btn-line` (pill, 44px, 1.5px border, hover fills) |
| Cards | 1px `--line`, `--radius-card`, hover `--text-muted` border (docs `.pagination-nav__link`) |
| Code blocks | docs `.theme-code-block`: `--surface`, 1px `--line`, `--radius-card`, Geist Mono 14px, monochrome syntax (status colours stay out of code) |
| Callouts | docs `.alert`: `--surface`, 3px `--text` left border, `--radius-card` |
| kwatch output panel | web Demo/Panel: ink surface, mono, `--radius-output` |
| Eyebrow | web `.eyebrow` (mono 13px, `--text-muted`) |
| Focus, hover | `:focus-visible` 3px `--text` outline; links underline on hover; buttons per `.btn-*` |
| Chips and tags | `--radius-chip` (4px), never pills |
| Glossary links | https://docs.kwatch.dev/glossary |

### Header and footer links

- Header nav (same order on every site, with Blog added): `Docs`
  (docs.kwatch.dev), `Blog` (blog.kwatch.dev, `aria-current` on the blog),
  `Pro` (kwatch.dev/pro), `Get help` (kwatch.dev/support), `Sign in`
  (app.kwatch.dev). The logo links to kwatch.dev.
- Blog-only header parts: a search field (opens search, Ctrl/Cmd K) in the
  docs position, and the theme toggle shared across sites (see mismatches).
  At <=640px the search field becomes a 44px icon button.
- Footer: `kwatch · source available under ELv2`; links `Docs`, `Blog`,
  `GitHub`, `Get help`, `Privacy`, `Terms`. Add `Blog` to the web, docs and
  app footers and navs too.
- Back to kwatch.dev, docs and app are all reachable from the header.

## Blog-specific components

1. **Post list item**: date column (mono 13px, 132px) and a body column:
   title (Bricolage 800, 24px, `--h3-card`), one-sentence dek (16px,
   `--text-soft`, max 60ch), tags, reading time. Rows divided by 1px `--line`.
   Mobile: one column.
2. **Featured post card**: one card, uneven 7fr / 5fr. Left: eyebrow
   `FEATURED`, title at `--h2-section`, dek 19px, meta. Right: the post's
   kwatch output in the output panel. Whole card is one link target on the
   title (stretched), hover border `--text-muted`.
3. **Tag filter**: row of chips with count (mono). Current = filled
   `--text`/`--bg`. Each chip is a link to the tag page (static site, no JS).
   Mobile: single scrolling row.
4. **Post header**: breadcrumb eyebrow `Blog / Tag`, H1 at `--h1-product`,
   dek 19px, byline row (author tile, name link, date, reading time).
5. **Article body**: 17px / 1.65 (`--text-body`), `--measure` 62ch, h2 26-32px
   Bricolage 800, scroll-margin 24px, inline code on `--surface`. Layout is
   an uneven 2 / 8 / 2 grid: the article in the middle column, TOC right.
6. **TOC**: sticky "ON THIS PAGE" (mono eyebrow), 2px left rule, current item
   `--text` bold with a `--text` rule. Mobile: `<details>` disclosure above
   the article, 44px rows.
7. **Author tile**: 40px (88px on the author page) `--ink` square,
   `--radius-input`, initial in Bricolage 800. No photos required.
8. **End-of-post CTA**: ink panel per `MESSAGING.md` section 9: eyebrow,
   heading, line, command with Copy, `.btn` `Get a free Pro license` and a link
   to the install guide. Stacks on mobile.
9. **Previous / next**: two cards (docs pagination pattern).
10. **Search (Pagefind)**: modal dialog 680px (full screen on mobile),
    input, grouped results, footer hints. See states below.

## Pages and states

- **Home**: intro (H1 `Notes on finding the cause.`), featured card, tag
  filter, list + side rail (tags with counts, authors, RSS), pager
  (`Older posts`). Empty list (never at launch): `No posts yet.`
- **Post**: header, TOC, body, CTA, previous/next.
- **Tag**: H1 is the tag name in Geist Mono (it is a cluster term), lede
  from the glossary, count, link `Glossary: <tag>`, filtered list, related tags.
- **Author**: tile, name, one-line bio, links (GitHub, kwatch.dev), post count, list.
- **404**: H1 `This post isn't here.`, line, `Latest posts` (btn) and
  `Search the blog` (btn line), details panel showing the address and next step.
- **Search**: states are idle (latest posts + tags), results (selected row has
  a 1.5px `--text` border, matches underlined 2px, not highlighted in colour),
  no results (`No posts match "<query>".` plus a symptom hint). Esc closes and
  returns focus to the trigger; Up/Down move; Enter opens. Index only post
  title, dek, headings and body (`data-pagefind-body` on the article).

## Type and spacing

Use the shared scale: H1 `--h1-product`, featured H2 `--h2-section`, card H3
`--h3-card` (24px), body 17px, small 15px, mono labels 13px. Spacing only
from `--space-*`; section rhythm 96px (64px <=960px, 48px <=480px); gutter 24px
(16px <=640px); max width `--max`. Blog adds no tokens.

## Dark mode, responsive, accessibility

- Light and dark come from the shared tokens (`prefers-color-scheme`, plus
  the shared toggle once it exists). Ink panels stay dark in both.
- Breakpoints 960 / 700 / 480. Under 960px the TOC moves into the disclosure
  and the list rail drops below the list.
- Targets are 44px; contrast per tokens (`--text-muted` on `--bg` is >=4.5:1;
  never put `--text-muted` on `--surface` under 15px).
- One `<h1>`, landmarks `header`, `main`, `nav`, `footer`; `Skip to content`
  link first; TOC and tag filters are `nav` with labels; `aria-current` on the
  current tag, TOC item and nav link. Dates use `<time datetime>`. Code blocks
  are focusable (`tabindex=0`) with a labelled Copy button that announces
  `Copied`. Search is a `dialog` with focus trap and labelled input; results
  use `listbox`/`option`.
- Signal appears once per view (the logo point). Status colours appear only
  inside real alert output.
- Motion: only 120ms hover transitions inside `prefers-reduced-motion: no-preference`.

## og-image template (1200x630)

Static, generated at build, Ink `#0E1116` background in all modes.
Grid: 72px margins. Top-left: Junction mark (80px) and `kwatch` wordmark in
Bricolage 800, Paper. Left column (width 700, vertical center): eyebrow
`blog.kwatch.dev` in Geist Mono 26px `#9AA0AA`; title in Bricolage 800 76px,
line-height 1.02, letter-spacing -0.035em, Paper, max 3 lines (shrink to 64px
past 70 characters). Right column (width 330): a 6-line excerpt of the post's
kwatch output in Geist Mono 22px `#ECEDEA` on `#15171B`, 14px radius, 28px
padding; use the shared trace sample when the post has none. Bottom-left:
author and date, Geist Mono 24px `#9AA0AA`. No gradients, no emoji, Signal only
in the mark's point. Alt text = post title.

## Mismatches between web, docs and app (to fix later)

1. **Header**: web has logo + 4 links, no search; docs has search left and
   links right; app has no top header (sidebar only). Logo size differs
   (web 26px, docs 1.7rem logo + 1.1rem title, app brand in the sidebar).
2. **Theme toggle**: none of the sites has one; all follow the system only.
   The shared header should add one (needs a decision; the brand says
   "follow the system", so default stays System).
3. **Nav links**: web and docs share Docs / Pro / Get help / Sign in, but docs'
   `Docs` goes to `/`, web has no `Blog`, app lacks all of them. `Sign in`
   is plain in web and bold in docs.
4. **Footer**: web is one text row, docs is a `--surface` band, app is a small
   unlinked line. Docs builds the links as an HTML string in config.
5. **Buttons**: three systems: web `.btn-solid/.btn-line`, docs
   `.button/.button--outline`, app `.btn-primary/.btn-action`. Solid hover is
   `--ink-line` on web, `--primary-hover` on docs and app. Padding differs
   (11px 22px vs 0 18px).
6. **Body size**: web 17px, docs and app 16px (documented). The blog follows
   web (17px) for reading.
7. **Code blocks**: web shows code on ink panels; docs uses `--surface` with a
   border; app has none. The blog uses the docs block for code and the ink
   panel only for kwatch output.
8. **Callouts**: docs `.alert` exists; web and app each roll their own.
9. **Link hover**: docs sets `text-underline-offset: 2px`, web 3px.
10. **Signal use**: docs pairs the Signal logo point with a Signal `PRO` badge in
    the same view, which breaks "once per view".
11. **CTA button on ink**: no shared rule for a button on an ink band; the blog
    uses Paper fill with Ink text and `#ECEDEA` hover. Confirm and add to web.

## Unified design changes

Every row changes all four sites to the same result. Route: web = kwatch-web,
docs = kwatch-docs, app = kwatch-app, blog = kwatch-blog. Source: a read of
`global.css`, `custom.css`, `styles.css`, `Header.astro`, `Footer.astro` and
`docusaurus.config.ts`; nothing here was measured in a browser, so verify
before building. Do the shared pieces once in `packages/brand` (a shared
`site-chrome.css` plus the nav and footer link lists as data) and import it
everywhere.

| # | Issue | Proposed change | Sites | Priority |
| --- | --- | --- | --- | --- |
| 1 | Four headers: web 4 links no search, docs search left, app sidebar only, blog new | One header: logo 26px + `kwatch`, nav `Docs`, `Blog`, `Pro`, `Get help`, `Sign in`, theme toggle. Search field only where there is content to search (docs, blog), same position. App keeps its sidebar for in-product pages and adds the same header above it | web, docs, app, blog | high |
| 2 | No `Blog` link anywhere | Add `Blog` to header nav and footer on all sites | web, docs, app, blog | high |
| 3 | Three button systems and two hover behaviours (`--ink-line` on web, `--primary-hover` on docs and app) | One spec: pill, 44px, 1.5px border, padding 11px 22px, solid = `--text` fill, hover `--primary-hover`; line = `--control-border`, hover fills `--text`. One class set (`.btn`, `.btn-solid`, `.btn-line`) exported from brand | web, docs, app, blog | high |
| 4 | Footers differ (text row, `--surface` band, unlinked line); docs builds links as an HTML string | One footer: `kwatch · source available under ELv2` + `Docs`, `Blog`, `GitHub`, `Get help`, `Privacy`, `Terms`, no band. Docs uses a swizzled footer component | web, docs, app, blog | med |
| 5 | Breakpoints drift: web 480/700/900/960, app 440/480/560/700, docs none (Docusaurus 996) | Only 960, 700, 480 (tokens spec). Remap odd values; override Docusaurus's 996 to 960 | web, docs, app, blog | med |
| 6 | No theme toggle anywhere, so a person cannot override the system | Add a 44px icon button with System, Light, Dark; default System; store the choice in `localStorage` guarded by try/catch; set `data-theme` before paint to avoid a flash. Tokens gain a `[data-theme]` block that mirrors the media query | web, docs, app, blog | med |
| 7 | Body size 17px (web) vs 16px (docs, app) | Keep: 17px for marketing and blog reading, 16px for docs and app. Write it once in the shared tokens README so it stops looking like a bug | all | low |
| 8 | Skip link only on web; docs and app have none found in CSS | Same `Skip to content` link on every site (web `.skip-link`). Docusaurus ships one: confirm it is visible on focus and uses the same style | docs, app, blog | high |
| 9 | Focus styles written four times (`focus-visible` counts: web 5, docs 1, app 3) | One shared rule: 3px `--text` outline, 3px offset, 4px radius; on ink bands `currentColor` | all | high |
| 10 | `prefers-reduced-motion` only handled in app; no `--motion-fast` use found in web or docs | Wrap every transition and transform in `no-preference`; use `--motion-fast` only | web, docs, blog | low |
| 11 | Link underline offset 2px (docs) vs 3px (web) | 3px everywhere; 4px for `.link-strong` | docs, app, blog | low |
| 12 | Code: ink panels on web, `--surface` block on docs, none on app | Code blocks = docs style. Ink panel reserved for kwatch output. Copy button on every block (pill, 32px) | web, docs, app, blog | med |
| 13 | Callouts defined separately (docs `.alert`, ad hoc in web and app) | One callout: `--surface`, 3px `--text` left rule, `--radius-card`, mono eyebrow label | all | med |
| 14 | App has a Signal button (`.btn-signal`) while the logo already shows Signal: breaks "once per view" | Retire `.btn-signal`; primary stays `--text` fill. Docs `PRO` badge next to the logo point: keep the badge, make it the only Signal use on docs pages by switching the logo mark to the Ink point inside docs content views, or drop the badge fill to `--surface` with an Ink border | app, docs, web | med |
| 15 | Hover on cards inconsistent (docs border to `--text-muted`, others none) | Every linked card: border to `--text-muted` on hover, 3px focus ring | web, docs, app, blog | low |
| 16 | Mobile header: web wraps nav under the logo, docs uses a drawer, app side nav collapses at its own width | One pattern at <=640px: logo + toggle + search icon on row one, nav wraps to row two (web pattern), 44px targets | web, docs, app, blog | med |
| 17 | `--text-muted` is used on `--surface` bands and small labels (31 uses in app) | Contrast check each use: below 15px or on `--surface` use `--text-soft`. Add a checklist item to `shared-tokens-checklist.md` | web, docs, app, blog | med |
| 18 | Inline `Sign in` is plain on web and bold on docs | Bold `Sign in` everywhere; it is the one account action | web | low |
| 19 | Copy drift: sites word the install and edition lines on their own | Pull the install line, editions line and the data small print from `MESSAGING.md` verbatim; add a one-time copy check to the PR template for web, docs, app and blog | all | med |
| 20 | Docs `Docs` link points to `/` and has no current state outside docs | `aria-current="page"` on the nav item of the current site on all four | web, docs, app, blog | low |
| 21 | **Dark mode buttons.** Web `.btn-solid` is `--ink` (#0E1116) fill with `--ink-text` label on every theme. In dark the fill is 1.05:1 against `--bg` (#15171B): the button shape disappears, and its focus outline (`outline-color: var(--ink)`) is 1.05:1, so focus is invisible. The blog mockups had the same bug class (link buttons inherited the page text colour, so the label matched the fill in light mode); fixed in the mockups | One solid button, token pairs below. Focus outline is always `--text`, never `--ink` | web, docs, app, blog | **high** |
| 22 | Signal bands (`.on-signal`) let any `--text`-coloured element through: `--text` on dark Signal (#B5DE3C) is 1.33:1, so a `.btn-line`, link or icon dropped in a band would vanish in dark | Inside `.on-signal` force labels, borders and icons to `--on-signal` (#0E1116, 14.95:1 on light Signal, 10:1+ on dark Signal). Buttons there use `.btn-solid` with the pair below. Add a lint check | web, app, blog | high |
| 23 | Ink panels (hero card, terminal, 404 card, never-box, blog output and CTA) are `--ink` on `--bg`: 1.05:1 in dark, so the panel edge is lost | Add `1px solid var(--ink-line)` to every ink panel in dark (decorative, text inside is 16:1). Do not rely on the edge to convey anything | web, blog, app | med |
| 24 | Borders: `--line` is 1.32:1 in dark and 1.36:1 in light. Fine for dividers and cards, not for controls | Controls (inputs, outline buttons, chips, toggle) use `--control-border` (3.71:1 dark, 3:1 light on `--bg`); never `--line`. Verify every input and chip in the four sites | web, docs, app, blog | med |
| 25 | Docs and app solid buttons are already `--text` fill with `--bg` label (15.27:1 dark), but docs `a`/`:hover` link rules and Infima defaults can override the label on `<a class="button">` | Verify in a dark browser for every button variant (`.button`, `.button--outline`, `.btn-primary`, `.btn-action.is-primary`, `.btn-danger`, disabled) and add `color` explicitly on `:hover`, `:focus-visible` and `:visited` | docs, app | high |
| 26 | Docs `disableSwitch: true` and app have no toggle, so any site stuck in the wrong mode cannot be corrected by the reader | Covered by row 6; remove `disableSwitch` in docs when the shared toggle ships | docs | med |
| 27 | Fixed hex colours in `Demo.astro` (#1f6feb, #5865f2, #2b2d31 with white text) ignore tokens | Keep: they imitate Slack/Discord. Document them as illustration-only and keep every label there at 4.5:1 or better (white on #5865f2 is 4.7:1) | web | low |
| 28 | Contrast check is manual; the dark pairs were never tabulated | Add the table below to `shared-tokens-checklist.md` and run a contrast script over `tokens.css` in CI | web, docs, app, blog | med |

### Button token pairs (row 21)

| Variant | Light fill / label / border | Dark fill / label / border | Contrast label (light / dark) |
| --- | --- | --- | --- |
| Solid | `--text` #0E1116 / `--bg` #FFFFFF / `--text` | `--text` #ECEDEA / `--bg` #15171B / `--text` | 18.9:1 / 15.3:1 (AA) |
| Solid hover, focus | `--primary-hover` #2A2F38 / `--bg` / same | `--primary-hover` #FFFFFF / `--bg` #15171B / same | 14.6:1 / 17.9:1 (AA) |
| Line | none / `--text` / `--control-border` #7C828E | none / `--text` / `--control-border` #6B7280 | 18.9:1 / 15.3:1; border 3.9:1 / 3.7:1 (UI 3:1) |
| Line hover | `--text` fill / `--bg` | `--text` fill / `--bg` | 18.9:1 / 15.3:1 |
| On ink panel (CTA) | #FFFFFF / #0E1116 | #FFFFFF / #0E1116 | 18.9:1 both |
| On Signal band | `--ink` #0E1116 / `--ink-text` #ECEDEA | same | 16.1:1 both; fill on Signal 14.9:1 light, 10:1+ dark |
| Disabled | `--surface` / `--text-muted` #5B6270 | `--surface` #1E2126 / `--text-muted` #9AA0AA | 5.3:1 / 6.1:1 |
| Focus ring | 3px `--text`, offset 3px | 3px `--text`, offset 3px | 18.9:1 / 15.3:1 |

Rule: label colour is always the opposite token of the fill (`--text` fill
gets `--bg`; `--bg` fill gets `--text`). Never hard-code `#fff` or
`--ink-text` on a token fill that flips with the theme. Ratios computed from
`tokens.css`; confirm 3.9:1 for the light `--control-border` on a browser.
