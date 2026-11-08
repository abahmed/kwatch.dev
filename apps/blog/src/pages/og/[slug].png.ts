import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import satori from 'satori';
import { Resvg } from '@resvg/resvg-js';
import type { APIContext } from 'astro';
import { formatDate, getAuthors, getPosts } from '../../lib/posts';
import { sampleTrace } from '../../lib/sample';

const require = createRequire(import.meta.url);
const font = (p: string) => readFileSync(require.resolve(p));
const bricolage = font('@fontsource/bricolage-grotesque/files/bricolage-grotesque-latin-800-normal.woff');
const mono = font('@fontsource/geist-mono/files/geist-mono-latin-400-normal.woff');

const INK = '#0E1116';
const PAPER = '#ECEDEA';
const MUTED = '#9AA0AA';

// Junction mark as a data URI (Paper strokes, Signal point).
const mark = `data:image/svg+xml;utf8,${encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none"><path d="M17 5.5v53" stroke="${PAPER}" stroke-width="8.5"/><path d="M47.5 6.5 32.2 27.6" stroke="${PAPER}" stroke-width="7.5"/><path d="M33.4 36.8 48.5 57.5" stroke="${PAPER}" stroke-width="8"/><circle cx="28.6" cy="32.2" r="8.6" fill="#C8F542" stroke="${PAPER}" stroke-width="3.2"/></svg>`,
)}`;

type Node = { type: string; props: Record<string, unknown> };
const h = (type: string, style: Record<string, unknown>, children?: unknown, extra: Record<string, unknown> = {}): Node => ({
  type,
  props: { style: { display: 'flex', ...style }, children, ...extra },
});

export async function getStaticPaths() {
  const posts = await getPosts();
  return [
    { params: { slug: 'index' }, props: { title: 'Notes on finding the cause.', output: sampleTrace, byline: 'kwatch blog' } },
    ...(await Promise.all(
      posts.map(async (p) => {
        const authors = await getAuthors();
        const a = authors.find((x) => x.id === p.data.author);
        return {
          params: { slug: p.id },
          props: { title: p.data.title, output: p.data.output ?? sampleTrace, byline: `${a?.data.name ?? p.data.author} · ${formatDate(p.data.date)}` },
        };
      }),
    )),
  ];
}

export async function GET({ props }: APIContext) {
  const { title, output, byline } = props as { title: string; output: string; byline: string };
  const size = title.length > 70 ? 64 : 76;
  const excerpt = output.split('\n').slice(0, 6).map((l) => h('div', { whiteSpace: 'pre' }, l.slice(0, 26)));

  const tree = h('div', { width: 1200, height: 630, background: INK, padding: 72, flexDirection: 'column', justifyContent: 'space-between', fontFamily: 'Geist Mono' }, [
    h('div', { alignItems: 'center', gap: 20 }, [
      h('img', { width: 80, height: 80 }, undefined, { src: mark, width: 80, height: 80 }),
      h('div', { fontFamily: 'Bricolage', fontSize: 64, letterSpacing: '-0.05em', color: PAPER }, 'kwatch'),
    ]),
    h('div', { gap: 48, alignItems: 'center' }, [
      h('div', { width: 700, flexDirection: 'column', gap: 24 }, [
        h('div', { fontSize: 26, color: MUTED }, 'blog.kwatch.dev'),
        h('div', { fontFamily: 'Bricolage', fontSize: size, lineHeight: 1.02, letterSpacing: '-0.035em', color: PAPER }, title),
      ]),
      h('div', { width: 330, flexDirection: 'column', background: '#15171B', borderRadius: 14, padding: 28, fontSize: 22, color: PAPER, gap: 4 }, excerpt),
    ]),
    h('div', { fontSize: 24, color: MUTED }, byline),
  ]);

  const svg = await satori(tree as never, {
    width: 1200,
    height: 630,
    fonts: [
      { name: 'Bricolage', data: bricolage, weight: 800, style: 'normal' },
      { name: 'Geist Mono', data: mono, weight: 400, style: 'normal' },
    ],
  });
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: 1200 } }).render().asPng();
  return new Response(new Uint8Array(png),{ headers: { 'Content-Type': 'image/png' } });
}
