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
