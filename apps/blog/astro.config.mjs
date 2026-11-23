import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';
import { readdirSync, readFileSync } from 'node:fs';

// lastmod per post comes from its frontmatter: `updated`, else `date`.
// Other pages (home, tags, authors) use the newest post date.
const postsDir = new URL('./src/content/posts/', import.meta.url);
const postDates = new Map();
for (const file of readdirSync(postsDir).filter((f) => f.endsWith('.mdx'))) {
  const fm = readFileSync(new URL(file, postsDir), 'utf8').split(/^---\s*$/m)[1] ?? '';
  if (/^draft:\s*true\s*$/m.test(fm)) continue;
  const field = (name) => fm.match(new RegExp(`^${name}:\\s*['"]?([^'"\\n]+?)['"]?\\s*$`, 'm'))?.[1];
  const d = new Date(field('updated') ?? field('date'));
  if (!Number.isNaN(d.getTime())) postDates.set(file.replace(/\.mdx$/, ''), d);
}
const newest = new Date(Math.max(...postDates.values()));

// The CSP forbids inline style attributes (style-src 'self'), so Shiki's
// per-token colours are turned into classes. Code is monochrome by design
// (BLOG_SPEC): classes map to weight and --text-* tokens in global.css.
const classOnlyTokens = {
  name: 'kwatch-class-only-tokens',
  pre(node) {
    delete node.properties.style;
  },
  span(node) {
    const style = String(node.properties.style ?? '');
    const m = style.match(/--astro-code-token-([a-z-]+)/);
    delete node.properties.style;
    if (m) node.properties.class = `tok-${m[1]}`;
  },
};

export default defineConfig({
  site: 'https://blog.kwatch.dev',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file', inlineStylesheets: 'never' },
  integrations: [
    mdx(),
    sitemap({
      serialize(item) {
        const slug = new URL(item.url).pathname.replace(/^\/|\/$/g, '');
        item.lastmod = (postDates.get(slug) ?? newest).toISOString();
        return item;
      },
    }),
  ],
  markdown: {
    shikiConfig: { theme: 'css-variables', transformers: [classOnlyTokens] },
  },
});
