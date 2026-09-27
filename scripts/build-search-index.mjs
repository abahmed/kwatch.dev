import fs from 'node:fs';
import path from 'node:path';

const buildRoot = path.resolve('build');
const outputs = [
  path.resolve('static/search-index.json'),
  path.join(buildRoot, 'search-index.json'),
];

function htmlFiles(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) return htmlFiles(file);
    return entry.name.endsWith('.html') ? [file] : [];
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

function decodeEntities(value) {
  const named = {
    amp: '&', apos: "'", gt: '>', lt: '<', nbsp: ' ', quot: '"',
    hellip: '…', mdash: '—', ndash: '–', rsquo: '’', lsquo: '‘',
  };
  return value.replace(/&(#x[\da-f]+|#\d+|[a-z]+);/gi, (_, entity) => {
    if (entity.startsWith('#x')) {
      return String.fromCodePoint(Number.parseInt(entity.slice(2), 16));
    }
    if (entity.startsWith('#')) {
      return String.fromCodePoint(Number.parseInt(entity.slice(1), 10));
    }
    return named[entity.toLowerCase()] ?? ' ';
  });
}

function plainText(html) {
  return decodeEntities(html
    .replace(/<(script|style|svg|nav|footer|button)\b[^>]*>[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<[^>]+>/g, ' '))
    .replace(/[\u200b-\u200d\ufeff]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function descriptionFrom(html) {
  const tag = html.match(/<meta\b[^>]*\bname="description"[^>]*>/i)?.[0];
  return plainText(tag?.match(/\bcontent="([^"]*)"/i)?.[1] ?? '');
}

const entries = htmlFiles(buildRoot).flatMap((file) => {
  const url = routeFor(file);
  const isDoc = url === '/docs' || url.startsWith('/docs/');
  const isPost = url.startsWith('/blog/') &&
    !url.startsWith('/blog/tags/') &&
    !url.startsWith('/blog/authors/') &&
    url !== '/blog/archive';
  if (!isDoc && !isPost) return [];

  const html = fs.readFileSync(file, 'utf8');
  if (html.includes('content="noindex')) return [];
  const article = html.match(/<article\b[^>]*>([\s\S]*?)<\/article>/i)?.[1];
  if (!article) return [];

  const title = plainText(article.match(/<h1\b[^>]*>([\s\S]*?)<\/h1>/i)?.[1] ?? '');
  const headings = [...article.matchAll(/<h[23]\b[^>]*>([\s\S]*?)<\/h[23]>/gi)]
    .map((match) => plainText(match[1]))
    .filter(Boolean);
  if (!title) return [];

  return [{
    url,
    type: isDoc ? 'Documentation' : 'Guide',
    title,
    description: descriptionFrom(html),
    headings,
    content: plainText(article).slice(0, 30000),
  }];
});

entries.sort((a, b) => a.url.localeCompare(b.url));
const output = `${JSON.stringify(entries)}\n`;
for (const file of outputs) fs.writeFileSync(file, output);
console.log(`Search index generated: ${entries.length} pages, ${Buffer.byteLength(output)} bytes.`);
