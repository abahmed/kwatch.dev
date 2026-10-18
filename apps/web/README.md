# @kwatch/web

The kwatch.dev marketing site: Home, Pro, Privacy, Terms and the 404 page. Astro, static output, no client JavaScript.

```
yarn dev:web      # dev server
yarn build:web    # static build into apps/web/dist
yarn typecheck:web  # astro check
```

## Layout

- `src/pages` holds the pages. `privacy.md` and `terms.md` are the legal text rendered through `src/layouts/Legal.astro`.
- Colours and font families come from `packages/brand/tokens.css`. Light and dark follow `prefers-color-scheme`; there is no toggle.
- Fonts are self-hosted variable fonts (latin subset) from `@fontsource-variable/*`, with `font-display: swap`.
- `scripts/make-images.mjs` regenerates the committed PNGs in `public/` (favicons, apple touch icon, 1200x630 `og.png`). It is run by hand and needs a system sans-serif font.

## public/

- `kwatch.sh` and `charts/` are the source of truth, written by the kwatch release workflow. These URLs must keep working: `https://kwatch.dev/kwatch.sh` and `https://kwatch.dev/charts/index.yaml`.
- `_headers`: security headers with a strict CSP (`'self'` only, no inline script or style).
- `_redirects`: `/pricing`, `/community`, `/blog/*`, `/search`, the old account paths and `/docs/*`. These are not added to `apps/docs`.
