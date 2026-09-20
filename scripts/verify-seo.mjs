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

if (!robots.includes('Sitemap: https://kwatch.dev/sitemap.xml')) {
  fail('robots.txt does not declare the production sitemap');
}

for (const file of indexablePages) {
  const route = routeFor(file);
  const html = read(file);
  const canonical = `https://kwatch.dev${route === '/' ? '/' : route}`;
  const hasTitle = /<title\b[^>]*>[^<]+<\/title>/i.test(html);
  const hasDescription = hasTag(html, 'meta', (tag) =>
    /\bname="description"/i.test(tag) &&
    /\bcontent="[^"]+"/i.test(tag),
  );
  const hasCanonical = hasTag(html, 'link', (tag) =>
    /\brel="canonical"/i.test(tag) && tag.includes(`href="${canonical}"`),
  );
  const noIndex = html.includes('content="noindex');

  if (!hasTitle) fail(`${route} has no non-empty title`);
  if (!hasDescription) fail(`${route} has no meta description`);
  if (!hasCanonical) fail(`${route} has no canonical URL for ${canonical}`);
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
}

for (const url of sitemapURLs) {
  if (!url.startsWith('https://kwatch.dev/')) {
    fail(`sitemap contains a non-production URL: ${url}`);
  }
}

if (process.exitCode) process.exit(1);
console.log(
  `SEO verification passed: ${indexablePages.length} indexable pages, ` +
  `${sitemapURLs.size} sitemap URLs.`,
);
