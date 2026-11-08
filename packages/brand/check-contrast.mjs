// Contrast check over tokens.css (BLOG_SPEC row 28). Fails when a pair drops
// below its WCAG minimum, or when the two dark blocks drift apart.
// Run: node packages/brand/check-contrast.mjs
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const css = readFileSync(fileURLToPath(new URL('./tokens.css', import.meta.url)), 'utf8');

function vars(block) {
  const out = {};
  for (const m of block.matchAll(/--([\w-]+):\s*(#[0-9a-fA-F]{6})\b/g)) out[m[1]] = m[2];
  return out;
}
function body(startRe) {
  const i = css.search(startRe);
  if (i < 0) throw new Error(`tokens.css: missing ${startRe}`);
  const open = css.indexOf('{', css.indexOf('{', i) + (startRe.source.startsWith('@media') ? 1 : 0));
  let depth = 0;
  for (let j = open; j < css.length; j++) {
    if (css[j] === '{') depth++;
    if (css[j] === '}' && --depth === 0) return css.slice(open + 1, j);
  }
  throw new Error('unbalanced braces');
}

const light = vars(body(/^:root \{/m));
const darkMedia = vars(body(/@media \(prefers-color-scheme: dark\)/));
const darkAttr = vars(body(/:root\[data-theme="dark"\]/));
const dark = { ...light, ...darkAttr };

let failed = false;
for (const k of new Set([...Object.keys(darkMedia), ...Object.keys(darkAttr)])) {
  if (darkMedia[k] !== darkAttr[k]) {
    console.error(`dark blocks differ on --${k}: media ${darkMedia[k]} vs data-theme ${darkAttr[k]}`);
    failed = true;
  }
}

const lum = (hex) => {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const ratio = (a, b) => {
  const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};

// [foreground token, background token, minimum, what it is]
const pairs = [
  ['text', 'bg', 4.5, 'body text'],
  ['text', 'surface', 4.5, 'text on surface'],
  ['text-soft', 'bg', 4.5, 'soft text'],
  ['text-soft', 'surface', 4.5, 'soft text on surface'],
  ['text-muted', 'bg', 4.5, 'muted text'],
  ['text-muted', 'surface', 4.5, 'muted text on surface'],
  ['bg', 'text', 4.5, 'solid button label'],
  ['bg', 'primary-hover', 4.5, 'solid button label on hover'],
  ['control-border', 'bg', 3, 'control border on page'],
  ['control-border', 'surface', 3, 'control border on surface'],
  ['text', 'bg', 3, 'focus ring on page'],
  ['on-signal', 'signal', 4.5, 'label on Signal band'],
  ['ink-text', 'ink', 4.5, 'text on ink'],
  ['ink-muted', 'ink', 4.5, 'muted text on ink'],
  ['ink-text', 'on-signal', 4.5, 'solid button label on Signal band'],
  ['ink', 'signal', 3, 'solid button fill on Signal band'],
  ['failing', 'failing-bg', 4.5, 'failing status'],
  ['degraded', 'degraded-bg', 4.5, 'degraded status'],
  ['resolved', 'resolved-bg', 4.5, 'resolved status'],
  ['success', 'success-bg', 4.5, 'success status'],
];

for (const [name, set] of [['light', light], ['dark', dark]]) {
  for (const [fg, bg, min, what] of pairs) {
    if (!set[fg] || !set[bg]) {
      console.error(`${name}: missing --${fg} or --${bg}`);
      failed = true;
      continue;
    }
    const r = ratio(set[fg], set[bg]);
    const ok = r >= min;
    if (!ok) failed = true;
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${name.padEnd(5)} ${r.toFixed(2).padStart(5)}:1 (min ${min}) --${fg} on --${bg}  ${what}`);
  }
}
process.exit(failed ? 1 : 0);
