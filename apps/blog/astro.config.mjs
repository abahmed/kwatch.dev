import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import sitemap from '@astrojs/sitemap';

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
  integrations: [mdx(), sitemap()],
  markdown: {
    shikiConfig: { theme: 'css-variables', transformers: [classOnlyTokens] },
  },
});
