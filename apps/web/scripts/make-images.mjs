// Regenerates the committed PNG images in public/ from the brand mark.
// Run manually: node scripts/make-images.mjs (needs a system sans-serif font for the og text).
import { Resvg } from '@resvg/resvg-js';
import { writeFileSync } from 'node:fs';

const mark = (fill, stroke) => `
  <path d="M17 5.5v53" stroke="${stroke}" stroke-width="8.5" fill="none"/>
  <path d="M47.5 6.5 32.2 27.6" stroke="${stroke}" stroke-width="7.5" fill="none"/>
  <path d="M33.4 36.8 48.5 57.5" stroke="${stroke}" stroke-width="8" fill="none"/>
  <circle cx="28.6" cy="32.2" r="8.6" fill="${fill}" stroke="${stroke}" stroke-width="3.2"/>`;

const render = (svg, width) =>
  new Resvg(svg, { fitTo: { mode: 'width', value: width }, font: { loadSystemFonts: true, defaultFontFamily: 'Helvetica Neue' } }).render().asPng();

// Favicon tiles (same design as public/favicon.svg)
const tile = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><rect width="64" height="64" rx="13" fill="#0E1116"/>
<path d="M21 11v42" stroke="#F4F5F2" stroke-width="8.5"/><path d="M45 12 32.5 29" stroke="#F4F5F2" stroke-width="7.5"/><path d="M33.4 36 46 52.5" stroke="#F4F5F2" stroke-width="8"/><circle cx="29" cy="32.4" r="8.4" fill="#C8F542"/></svg>`;
for (const [name, w] of [['favicon-16.png', 16], ['favicon-32.png', 32], ['apple-touch-icon.png', 180]]) {
  writeFileSync(new URL(`../public/${name}`, import.meta.url), render(tile, w));
}

const og = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
<rect width="1200" height="630" fill="#FFFFFF"/>
<rect y="0" width="1200" height="14" fill="#C8F542"/>
<g transform="translate(96 96) scale(3.2)">${mark('#C8F542', '#0E1116')}</g>
<text x="330" y="262" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="800" font-size="120" letter-spacing="-6" fill="#0E1116">kwatch</text>
<text x="96" y="440" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="800" font-size="76" letter-spacing="-3" fill="#0E1116">Kubernetes incidents,</text>
<text x="96" y="530" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="800" font-size="76" letter-spacing="-3" fill="#0E1116">explained.</text>
<rect x="96" y="548" width="372" height="14" rx="3" fill="#C8F542"/>
</svg>`;
writeFileSync(new URL('../public/og.png', import.meta.url), render(og, 1200));
