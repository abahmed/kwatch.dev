import fs from 'node:fs';
import path from 'node:path';

const buildRoot = path.resolve('build');
const sitemapPath = path.join(buildRoot, 'sitemap.xml');
const robotsPath = path.join(buildRoot, 'robots.txt');
const noIndexRoutes = new Set([
  '/404',
  '/charts',
]);

function isExcluded(route) {
  return noIndexRoutes.has(route);
}

function fail(message) {
  console.error(`SEO verification failed: ${message}`);
  process.exitCode = 1;
}

function read(file) {
  if (!fs.existsSync(file)) {
    fail(`missing ${file}`);
    return '';
  }
  return fs.readFileSync(file, 'utf8');
}

function htmlFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    return entry.isDirectory() ? htmlFiles(entryPath) :
      entry.name.endsWith('.html') ? [entryPath] : [];
  });
}

function routeFor(file) {
  const relative = path.relative(buildRoot, file).replaceAll(path.sep, '/');
  if (relative === 'index.html') return '/';
  if (relative.endsWith('/index.html')) {
    return `/${relative.slice(0, -'/index.html'.length)}`;
  }
  return `/${relative.slice(0, -'.html'.length)}`;
}

function urlsFromSitemap(sitemap) {
  return new Set(
    [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]),
  );
}

function htmlTags(html, name) {
  const pattern = new RegExp(`<${name}\\b[^>]*>`, 'gi');
  return [...html.matchAll(pattern)].map(([tag]) => tag);
}

function hasTag(html, name, predicate) {
  return htmlTags(html, name).some(predicate);
}

// Every source doc must set its own description and title in front matter,
// so no page falls back to an auto-generated snippet.
function markdownFiles(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const entryPath = path.join(directory, entry.name);
    return entry.isDirectory() ? markdownFiles(entryPath) :
      /\.mdx?$/.test(entry.name) ? [entryPath] : [];
  });
}
for (const file of markdownFiles(path.resolve('docs'))) {
  const front = fs.readFileSync(file, 'utf8').match(/^---\n([\s\S]*?)\n---/)?.[1] ?? '';
  const name = path.relative(process.cwd(), file);
  const description = front.match(/^description:\s*(.+)$/m)?.[1]?.trim();
  if (!description) fail(`${name} has no description in its front matter`);
  else if (description.length < 40) fail(`${name} description is too short`);
  if (!/^title:\s*\S/m.test(front)) fail(`${name} has no title in its front matter`);
}

const sitemap = read(sitemapPath);
const robots = read(robotsPath);
const sitemapURLs = urlsFromSitemap(sitemap);
const pages = htmlFiles(buildRoot);
const indexablePages = pages.filter((file) => !isExcluded(routeFor(file)));
const excludedPages = pages.filter((file) => isExcluded(routeFor(file)));
const titles = new Map();
const descriptions = new Map();
const searchIndex = JSON.parse(read(path.join(buildRoot, 'search-index.json')));
const searchURLs = new Set(searchIndex.map((entry) => entry.url));

if (!robots.includes('Sitemap: https://docs.kwatch.dev/sitemap.xml')) {
  fail('robots.txt does not declare the production sitemap');
}

for (const file of indexablePages) {
  const route = routeFor(file);
  const html = read(file);
  const canonical = `https://docs.kwatch.dev${route === '/' ? '/' : route}`;
  const title = html.match(/<title\b[^>]*>([^<]+)<\/title>/i)?.[1];
  const description = htmlTags(html, 'meta')
    .find((tag) => /\bname="description"/i.test(tag))
    ?.match(/\bcontent="([^"]+)"/i)?.[1];
  const hasCanonical = hasTag(html, 'link', (tag) =>
    /\brel="canonical"/i.test(tag) && tag.includes(`href="${canonical}"`),
  );
  const hasOpenGraph = ['og:title', 'og:description', 'og:image']
    .every((property) => hasTag(html, 'meta', (tag) =>
      tag.includes(`property="${property}"`) &&
      /\bcontent="[^"]+"/i.test(tag),
    ));
  const headingCount = htmlTags(html, 'h1').length;
  const imagesWithoutAlt = htmlTags(html, 'img')
    .filter((tag) => !/\balt="[^"]*"/i.test(tag));
  const noIndex = html.includes('content="noindex');

  const jsonLd = [...html.matchAll(/<script[^>]*application\/ld\+json[^>]*>([^<]+)<\/script>/g)]
    .map((match) => match[1]);
  const wantsType = route === '/' ? 'SoftwareApplication' : 'TechArticle';
  if (!jsonLd.some((block) => block.includes(`"@type":"${wantsType}"`))) {
    fail(`${route} lacks ${wantsType} structured data`);
  }
  if (route !== '/' && !jsonLd.some((block) => block.includes('"@type":"BreadcrumbList"'))) {
    fail(`${route} lacks BreadcrumbList structured data`);
  }
  if (route.startsWith('/guides/')) {
    for (const type of ['HowTo', 'FAQPage']) {
      if (!jsonLd.some((block) => block.includes(`"@type":"${type}"`))) {
        fail(`${route} lacks ${type} structured data`);
      }
    }
  }
  if (title && title.length > 80) fail(`${route} title is longer than 80 characters`);
  if (!hasTag(html, 'meta', (tag) => /\bname="twitter:card"/i.test(tag))) {
    fail(`${route} lacks a twitter:card`);
  }
  if (!title) fail(`${route} has no non-empty title`);
  if (!description) fail(`${route} has no meta description`);
  if (!hasCanonical) fail(`${route} has no canonical URL for ${canonical}`);
  if (!hasOpenGraph) fail(`${route} lacks complete Open Graph metadata`);
  if (headingCount !== 1) fail(`${route} has ${headingCount} h1 headings`);
  if (imagesWithoutAlt.length) fail(`${route} has images without alt text`);
  if (title && titles.has(title)) {
    fail(`${route} repeats the title on ${titles.get(title)}`);
  }
  if (description && descriptions.has(description)) {
    fail(`${route} repeats the description on ${descriptions.get(description)}`);
  }
  if (title) titles.set(title, route);
  if (description) descriptions.set(description, route);
  if (!noIndex && !sitemapURLs.has(canonical)) {
    fail(`${route} is indexable but absent from sitemap.xml`);
  }
}

for (const file of excludedPages) {
  const route = routeFor(file);
  const html = read(file);
  if (!html.includes('content="noindex')) {
    fail(`${route} is excluded but does not declare noindex`);
  }
  const canonical = `https://docs.kwatch.dev${route}`;
  if (sitemapURLs.has(canonical)) {
    fail(`${route} is excluded but appears in sitemap.xml`);
  }
}

const lastmods = (sitemap.match(/<lastmod>[^<]+<\/lastmod>/g) ?? []).length;
if (lastmods !== sitemapURLs.size) {
  fail(`sitemap has ${lastmods} lastmod entries for ${sitemapURLs.size} URLs`);
}

for (const url of sitemapURLs) {
  if (!url.startsWith('https://docs.kwatch.dev/')) {
    fail(`sitemap contains a non-production URL: ${url}`);
  }
}

// Every indexable page on the docs host is searchable.
const searchableRoutes = indexablePages.map(routeFor);
for (const route of searchableRoutes) {
  if (!searchURLs.has(route)) fail(`${route} is absent from search index`);
}
if (searchURLs.size !== searchIndex.length) {
  fail('search index has duplicate URLs');
}
if (searchURLs.size !== searchableRoutes.length) {
  fail('search index includes unexpected pages');
}

// Docs are served from the root of docs.kwatch.dev; /docs/* is a redirect.
if (!pages.some((file) => routeFor(file) === '/')) fail('home page / is missing');
const legacy = pages.filter((file) => routeFor(file).startsWith('/docs'));
if (legacy.length) fail(`${legacy.length} pages are still built under /docs`);
if (!pages.some((file) => routeFor(file) === '/404')) fail('404 page is missing');
for (const name of ['_headers', '_redirects']) {
  if (!fs.existsSync(path.join(buildRoot, name))) fail(`build is missing ${name}`);
}
if (!read(path.join(buildRoot, '_redirects')).includes('/docs/* /:splat 301')) {
  fail('_redirects does not map /docs/* to /:splat');
}
for (const file of pages) {
  if (/href="\/docs[\/"]/.test(read(file))) {
    fail(`${routeFor(file)} still links to /docs/...`);
  }
}

if (process.exitCode) process.exit(1);
console.log(
  `SEO verification passed: ${indexablePages.length} indexable pages, ` +
  `${sitemapURLs.size} sitemap URLs.`,
);
