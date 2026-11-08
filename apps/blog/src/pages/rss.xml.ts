import rss from '@astrojs/rss';
import type { APIContext } from 'astro';
import { SITE, getPosts } from '../lib/posts';

export async function GET(context: APIContext) {
  const posts = await getPosts();
  return rss({
    title: 'kwatch blog',
    description: 'Notes on finding the cause of Kubernetes failures.',
    site: context.site ?? SITE,
    items: posts.map((p) => ({
      title: p.data.title,
      description: p.data.description,
      pubDate: p.data.date,
      link: `/${p.id}`,
      categories: p.data.tags,
    })),
    customData: '<language>en</language>',
  });
}
