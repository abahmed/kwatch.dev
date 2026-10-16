# @kwatch/brand

Shared brand assets for the kwatch sites: colour and font tokens plus the
Junction logo.

- `tokens.css` defines CSS variables. Light is the default and dark applies
  through `prefers-color-scheme`. Fonts are Bricolage Grotesque (display),
  Instrument Sans (body) and Geist Mono (code); the tokens only name them, so
  each app self-hosts the font files.
- `logo/mark.svg` is the large Junction mark.
- `logo/app-icon-64.svg`, `app-icon-32.svg` and `app-icon-16.svg` are the
  dark-ground app icon, with stroke weights tuned per size.
- `logo/favicon.svg` is the app icon with a `prefers-color-scheme` rule that
  tones the tile and Signal down in dark mode.

## Rules (from the Brand board)

- Signal is never text on white. It is a fill; text on it uses `--on-signal`.
- One Signal element per view.
- No gradients, glows, emoji or stock icons. One flat accent.
- Use real material (real alerts and screens), not made-up dashboards.
- Square corners on structure, round only on actions such as buttons.
- Keep the small imperfections in the mark: stem 8.5, arm 7.5, leg 8.
