// Static SEO checks on the built site (run after `yarn build:web`).
// With LIVE=1 it also follows every redirect on https://kwatch.dev and checks
// that each lands in one hop on a 200.
import { readFileSync, existsSync } from 'node:fs';

const dist = new URL('../dist/', import.meta.url);
const fail = [];
const rules = readFileSync(new URL('../public/_redirects', import.meta.url), 'utf8')
  .split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#')).map((l) => l.split(/\s+/));

// /sitemap.xml must not be a stale urlset: either absent or a 301 to the index.
if (existsSync(new URL('sitemap.xml', dist))) {
  const body = readFileSync(new URL('sitemap.xml', dist), 'utf8');
  if (!/<sitemapindex/.test(body)) fail.push('dist/sitemap.xml is a urlset; only sitemap-index.xml may exist');
}
const sm = rules.find((r) => r[0] === '/sitemap.xml');
if (!sm || sm[1] !== '/sitemap-index.xml' || sm[2] !== '301') fail.push('_redirects must send /sitemap.xml to /sitemap-index.xml with a 301');
if (!existsSync(new URL('sitemap-index.xml', dist))) fail.push('dist/sitemap-index.xml is missing');

// Blog: one redirect per post, no splat, /blog goes home.
if (rules.some((r) => r[0] === '/blog/*')) fail.push('_redirects still has a /blog/* splat');
if (!rules.some((r) => r[0] === '/blog' && r[1] === '/')) fail.push('_redirects needs /blog -> /');

// No redirect chains: a target that is itself a redirect source is a second hop.
const sources = new Set(rules.map((r) => r[0]));
for (const [from, to] of rules) if (sources.has(to)) fail.push(`${from} -> ${to} is a chain`);

if (process.env.LIVE === '1') {
  for (const [from, to, status] of rules) {
    if (from.includes('*')) continue;
    const res = await fetch(`https://kwatch.dev${from}`, { redirect: 'manual' });
    const loc = res.headers.get('location') ?? '';
    const abs = new URL(loc, 'https://kwatch.dev').href;
    const want = new URL(to, 'https://kwatch.dev').href;
    if (String(res.status) !== status || abs !== want) { fail.push(`live ${from}: ${res.status} ${loc}`); continue; }
    const end = await fetch(abs, { redirect: 'manual' });
    if (end.status !== 200) fail.push(`live ${from} -> ${abs} returns ${end.status}`);
  }
}

if (fail.length) { console.error(fail.join('\n')); process.exit(1); }
console.log(`web SEO checks passed (${rules.length} redirect rules)`);
