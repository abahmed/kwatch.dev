# Shared tokens: per-app checklist

`packages/brand/tokens.css` now carries the scale tokens (space, radius, type,
layout, shadow, motion) beside colours and fonts. All three apps import
`tokens.css` and `fonts.css` from `packages/brand` already; nothing else
should define colours, radii or fonts locally. Paths under `kwatch.dev/`.
Companion to `specs/cross-site-consistency.md` and `LANDING_REDESIGN.md`.

## Audit: what is inconsistent today

| # | Where | Finding |
|---|---|---|
| I1 | `apps/app/src/components.tsx:50` | Sidebar shows text only (`<span class="wordmark">kwatch</span>`); web and docs show the Junction mark with the wordmark. |
| I2 | `apps/app/src/styles.css:34` | `.btn` border uses `--line` (about 1.4:1, fails 1.4.11); `.btn-action` uses `--control-border`; padding gives about 40px height, not `--hit`. |
| I3 | `apps/app/src/styles.css:67`, `:53` | Login card radius 6, notices 6; cards elsewhere 10. |
| I4 | `apps/app/src/styles.css:161` | Mobile breakpoint 720; web 960/640/480 (becoming 960/700/480); `.content` padding 40/48 vs web gutter 24/16. |
| I5 | `apps/app` shell | No footer and no link back to kwatch.dev; docs and web have the shared footer line. |
| I6 | `apps/docs/docusaurus.config.ts:101` | Navbar title "kwatch docs" in display font vs lockup "kwatch" elsewhere. |
| I7 | `apps/docs/src/css/custom.css` | `--ifm-button-*` set but outline variant not mapped to `--control-border`; heading size 3rem vs `--h1-product`; body 100% vs 16px token. |
| I8 | `apps/docs/docusaurus.config.ts:116` | Footer line is one string of anchors; spacing and focus style depend on Infima, differ from web footer. |
| I9 | `apps/web/src/styles/global.css` | `:root` redefines `--max`, `--gutter` locally (now in tokens); `.btn` padding 11/22 vs docs/app padding; body 17px literal. |
| I10 | `apps/web/src/pages/index.astro` | Radii 4/6/8/10/14 mixed, `#000` terminal, hero shadow literal; covered in `specs/landing-redesign.md`. |
| I11 | Signal | Web uses `.signal` as a class name for ink-coloured text (misleading); only `.cta` is a real Signal fill. Rename to `.accent` in markup when touched. |
| I12 | Titles | App uses a single title "kwatch"; docs and web use "Page · kwatch". |

## web (`kwatch-web`)

- Header: add the `Install` pill (`.btn-line`) and keep Docs, Pro, Get help, Sign in; mobile second row at <=700 (see `LANDING_REDESIGN.md` 3.10).
- Footer: unchanged (the reference).
- Buttons: `.btn` min-height `var(--btn-height)`, border `var(--btn-border)`, radius `var(--radius-pill)`; one `.big` in `global.css`.
- Fonts: unchanged (shared `fonts.css`, preload kept).
- Colours: no local colours; replace `#000`, `#fff`, hero shadow with `--ink`, `--ink-text`, `--shadow-output`.
- Remove local `--max`, `--gutter` base values (keep the 16px mobile override); radii and section padding use the new tokens; breakpoints 960/700/480.
- Rename `.signal` text class to `.accent`; keep exactly one Signal fill.

## docs (`kwatch-docs`)

- Header: navbar title `kwatch` with a quiet `docs` label (Geist Mono 13px `--text-muted`) after the mark; links Docs, Pro, Get help, Sign in in that order, 15px `--text-muted`, `--text` on hover, 600 for current.
- Footer: keep the single line but render it with the web footer's flex layout, 14px `--text-muted`, 20px gaps, same order (Docs, GitHub, Get help, Privacy, Terms).
- Buttons: map `--ifm-button-min-height` to `var(--btn-height)`, outline variant border to `--control-border`, radius `--radius-pill`.
- Fonts: shared `fonts.css` (already). Body `var(--text-body-product)`; h1 `var(--h1-product)`.
- Colours: no `#hex` in `custom.css` or the Prism theme; code theme from `--surface`, `--text`, `--text-muted`, status colours only for diff add/remove.
- Radius: `--ifm-global-radius: var(--radius-input)`; cards and admonitions `--radius-card`.
- Install pages show the installer command first, Helm second, per MESSAGING section 6.

## app (`kwatch-app`)

- Header/shell: replace the text wordmark with the Junction mark (26px) plus "kwatch" 800 -0.05em; add `kwatch.dev` beside the existing Docs link at the sidebar foot; sidebar remains (product pattern).
- Footer: add the single shared line under `.content`, 14px `--text-muted`.
- Buttons: `.btn` border `--control-border`, min-height `var(--btn-height)`, `.btn-sm` keeps `--hit` as min; focus ring already 3px.
- Fonts: shared `fonts.css` (already); no per-weight imports.
- Colours: `.badge-neutral` for healthy; only failing, degraded, resolved-after-incident use status colours.
- Radius: login card and notices to `--radius-card` / `--radius-chip` per use; inputs `--radius-input`.
- Breakpoint 720 to 700; content padding `var(--space-6) var(--space-6)` desktop, `var(--space-5) var(--space-4)` mobile; max width `var(--max-app)`.
- Page titles `Page · kwatch`.

## Done when

Grep for `#[0-9A-Fa-f]{3,6}` in each app's CSS returns only `tokens.css`; `border-radius:` values come from tokens; the three headers show the same lockup; screenshots at 1440, 768 and 375, light and dark, in each PR.
