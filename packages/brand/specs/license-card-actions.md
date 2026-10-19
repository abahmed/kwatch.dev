# License card actions (app.kwatch.dev)

Scope: `.license-actions` in `apps/app/src/pages/Licenses.tsx` and `styles.css`. Layout, tokens and states only. Dialogs are unchanged (Move uses `btn-primary`, Replace uses `btn-danger`; keep).

## Findings in the current code

- Four equal outline pills sit in the 2fr third column. They wrap unpredictably and nothing says which one you want.
- `btn-sm` is about 36px tall, under the 44px touch target.
- `--line` (#DADDE2) on white is 1.4:1, so the outlines fail WCAG 1.4.11 (3:1).
- Copy key takes `btn-signal` when no cluster is attached. That puts one Signal element on every such card, which breaks "Signal at most once per view".
- Replace key looks the same as safe actions, though it invalidates the old key.
- The brand has no icon set and forbids stock icons, so **actions are text only**. No icons.

## Hierarchy

| Tier | Action | Style | Why |
|---|---|---|---|
| Primary | Copy key | Solid Ink fill (`btn-primary`) | The job people come for: paste the key into the installer. One per card. |
| Secondary | Show key | Outline, ink text | Supports copying: lets you check the key. |
| Secondary | Move to another cluster | Outline, ink text | Rare, opens a confirm dialog. Only shown with a cluster attached. |
| Quiet | Replace key | Text button, `--text-muted`, underline on hover | Consequential but rare. It is confirmed in the dialog, where the red `btn-danger` lives. Red on every card would be noise. Hidden when revoked. |

Signal is not used on card actions. Remove the `btn-signal` branch on Copy key.

## Grouping and order

Actions move out of the third column into a footer row of the card spanning all columns, separated by a hairline.

1. **Key group** (left): Copy key, Show key.
2. **Manage group** (right, pushed with `margin-inline-start: auto`): Move to another cluster, Replace key.

DOM order matches visual order (Copy, Show, Move, Replace), so tab order follows reading order. The footer is `role="group"` with `aria-label="Key actions"` and `aria-label="Manage license"` on the two sub-groups.

The card grid becomes two columns (`3fr 3fr`: name and key, cluster). The third column is gone.

## Sizes and spacing

- Height 44px (`--hit`), pill radius 999px (round on actions, per brand).
- Padding 0 18px, font 15px/600 for primary, 15px/500 for the rest. Instrument Sans.
- Gap 8px inside a group, 16px between groups, 16px above the footer's hairline, 18px between the hairline and the buttons.
- Quiet button: no border, padding 0 12px, still 44px tall. Its hit area is the full 44px.
- Copy key and Show key keep `min-width: 112px` so "Show key" to "Hide key" and "Copy key" to "Copied" do not shift neighbours.

## States

All buttons: transition `background-color, border-color 120ms`, none under `prefers-reduced-motion`.

| State | Primary | Secondary | Quiet |
|---|---|---|---|
| Rest | bg `--text`, text `--bg` | bg transparent, border `--control-border`, text `--text` | text `--text-muted` |
| Hover | bg `--primary-hover` | bg `--surface`, border `--text` | text `--text`, underline |
| Focus-visible | 2px `--text` ring, 2px offset (existing global rule); on dark the ring is `--text` on `--bg`, which holds 3:1 | same | same, ring radius 999px |
| Active | `translateY(1px)`, no shadow | bg `--line` | text `--text` |
| Disabled | opacity 0.5, `cursor: not-allowed`, no hover change | same | same |
| Loading | n/a (copy is instant) | Show key only: label `Showing…`, `disabled`, `aria-busy="true"`. No spinner (no stock icons). | n/a |
| Done | Copy key reads `Copied` for 2s. Keep the existing `role="status"` announcement; do not change the colour. | `aria-pressed` true shows `Hide key` with bg `--surface` | n/a |

Disabled controls are exempt from contrast, but keep the label legible: opacity 0.5 on Ink is about 4:1 or better.

## Tokens (add to `styles.css`, not to the shared brand file unless the lead agrees)

```css
:root {
  --hit: 44px;
  --control-border: #7C828E;   /* 3.7:1 on #FFFFFF */
  --primary-hover: #2A2F38;
}
@media (prefers-color-scheme: dark) {
  :root {
    --control-border: #6B7280; /* 3.6:1 on #15171B */
    --primary-hover: #FFFFFF;  /* text is #ECEDEA, so hover lifts to white */
  }
}
```

Dark primary: `--text` #ECEDEA fill with `--bg` #15171B text is 14:1. Hover to `--primary-hover` #FFFFFF stays above 15:1.

## Classes

```css
.license-footer   { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 8px 16px;
                    padding-top: 18px; border-top: 1px solid var(--line); }
.license-group    { display: flex; flex-wrap: wrap; gap: 8px; }
.license-group-manage { margin-inline-start: auto; }

.btn-action       { min-height: var(--hit); padding: 0 18px; font-size: 15px; font-weight: 500;
                    border: 1.5px solid var(--control-border); border-radius: 999px;
                    background: transparent; color: var(--text); }
.btn-action:hover:not(:disabled)  { background: var(--surface); border-color: var(--text); }
.btn-action:active:not(:disabled) { background: var(--line); }
.btn-action[aria-pressed="true"]  { background: var(--surface); border-color: var(--text); }
.btn-action.is-primary            { background: var(--text); color: var(--bg); border-color: var(--text);
                                    font-weight: 600; min-width: 112px; }
.btn-action.is-primary:hover:not(:disabled)  { background: var(--primary-hover); border-color: var(--primary-hover); }
.btn-action.is-primary:active:not(:disabled) { transform: translateY(1px); }
.btn-quiet        { border-color: transparent; color: var(--text-muted); padding: 0 12px; }
.btn-quiet:hover:not(:disabled)  { background: transparent; border-color: transparent;
                                   color: var(--text); text-decoration: underline; }
@media (prefers-reduced-motion: no-preference) {
  .btn-action { transition: background-color 120ms, border-color 120ms; }
}
```

Mark-up: each button gets `btn-action`; Copy adds `is-primary`; Replace adds `btn-quiet`. Show key keeps `min-width: 112px` via its own modifier.

## Responsive

- **Desktop (above 720px):** footer is one row, key group left, manage group right. If a card is narrow (about 700px content), the manage group wraps under the key group and stays right-aligned.
- **375px** (content 343px, card padding 16px, inner width about 309px). Reduce card padding to 16px at this breakpoint.
  - `.license-group-key` becomes a 2-column grid: Copy key and Show key each `1fr` (about 150px each), 44px tall.
  - `.license-group-manage` is a column, `margin-inline-start: 0`, `width: 100%`. Move to another cluster is full width (label about 190px fits). Replace key is full width, quiet, left-aligned text.
  - Gaps stay 8px. Every target is at least 44px tall with 8px between.
  - No horizontal scroll; labels never truncate (`white-space: normal` is allowed, but the widths above fit).

## Light and dark

Both themes follow the system through the tokens. No component-level colour literals. Signal does not appear on the card. Status colours stay on `.badge` and `.alert` only (Replace is not red on the card).

## Accessibility

- Contrast: Ink on white 17:1; muted `#5B6270` on white 6:1 and on `--surface` 5.4:1; dark `#9AA0AA` on `#15171B` 6.5:1; control borders 3:1 or better (1.4.11).
- Targets 44px tall; gaps at least 8px; the quiet button's hit area is the whole 44px.
- Focus is always visible (2px `--text` ring, offset 2px) and never clipped: footer has no `overflow: hidden`.
- Show/Hide uses `aria-pressed` (exists). Do not also change the accessible name; either the label or the pressed state, not both. Recommendation: keep the label change and drop `aria-pressed` for a plain toggle button with `aria-label` unchanged. The lead may keep the current behaviour if screen-reader tests pass.
- Give each button an accessible name that includes context when several cards exist: `aria-label="Copy key, Pro license ending 2026-11-02"` is optional. At minimum the card is already a labelled section.
- `Copied` and errors announce through the existing `role="status"` and `role="alert"`; do not toast.

## Copy

Labels unchanged: Copy key, Show key, Hide key, Copied, Move to another cluster, Replace key. Loading label: `Showing…`. No new copy needs reviewing beyond that.

## Open questions for the lead

1. Is Replace key allowed to stay quiet on the card given it invalidates the old key? The dialog already confirms with the red button. Recommended yes.
2. Add `--control-border` and `--primary-hover` to `packages/brand/tokens.css` so the website can reuse them? That changes a shared contract and needs a notice to kwatch-web and kwatch-docs.
