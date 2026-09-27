import fs from 'node:fs';
import path from 'node:path';

const buildRoot = path.resolve('build');
const sitemapPath = path.join(buildRoot, 'sitemap.xml');
const robotsPath = path.join(buildRoot, 'robots.txt');
const noIndexRoutes = new Set([
  '/404',
  '/blog/archive',
  '/blog/authors',
  '/blog/tags',
  '/charts',
  '/search',
]);

function isExcluded(route) {
  return noIndexRoutes.has(route) || route.startsWith('/blog/tags/');
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

if (!robots.includes('Sitemap: https://kwatch.dev/sitemap.xml')) {
  fail('robots.txt does not declare the production sitemap');
}

for (const file of indexablePages) {
  const route = routeFor(file);
  const html = read(file);
  const canonical = `https://kwatch.dev${route === '/' ? '/' : route}`;
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
  const canonical = `https://kwatch.dev${route}`;
  if (sitemapURLs.has(canonical)) {
    fail(`${route} is excluded but appears in sitemap.xml`);
  }
}

for (const url of sitemapURLs) {
  if (!url.startsWith('https://kwatch.dev/')) {
    fail(`sitemap contains a non-production URL: ${url}`);
  }
}

const searchableRoutes = indexablePages.map(routeFor).filter((route) =>
  route === '/docs' || route.startsWith('/docs/') ||
  (route.startsWith('/blog/') && !route.startsWith('/blog/tags/')),
);
for (const route of searchableRoutes) {
  if (!searchURLs.has(route)) fail(`${route} is absent from search index`);
}
if (searchURLs.size !== searchIndex.length) {
  fail('search index has duplicate URLs');
}
if (searchURLs.size !== searchableRoutes.length) {
  fail('search index includes unexpected pages');
}

if (process.exitCode) process.exit(1);
console.log(
  `SEO verification passed: ${indexablePages.length} indexable pages, ` +
  `${sitemapURLs.size} sitemap URLs.`,
);
