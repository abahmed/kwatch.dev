import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import { execFileSync } from 'node:child_process';

// lastmod is the date of the last commit that touched the page's source.
const sources = {
  '/': 'src/pages/index.astro',
  '/pro': 'src/pages/pro.astro',
  '/privacy': 'src/pages/privacy.md',
  '/terms': 'src/pages/terms.md',
};
function lastmod(path) {
  try {
    const out = execFileSync('git', ['log', '-1', '--format=%cI', '--', sources[path]], { encoding: 'utf8' }).trim();
    return out ? new Date(out) : undefined;
  } catch {
    return undefined;
  }
}

export default defineConfig({
  site: 'https://kwatch.dev',
  output: 'static',
  trailingSlash: 'never',
  build: { format: 'file', inlineStylesheets: 'never' },
  vite: { build: { assetsInlineLimit: 0 } }, // keep scripts external for script-src 'self'
  integrations: [
    sitemap({
      filter: (page) => !page.endsWith('/404'),
      customSitemaps: ['https://docs.kwatch.dev/sitemap.xml'],
      serialize(item) {
        const path = new URL(item.url).pathname.replace(/\/$/, '') || '/';
        const date = sources[path] && lastmod(path);
        if (date) item.lastmod = date.toISOString();
        return item;
      },
    }),
  ],
});
