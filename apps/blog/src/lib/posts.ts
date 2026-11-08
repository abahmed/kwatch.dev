import { getCollection, type CollectionEntry } from 'astro:content';

export type Post = CollectionEntry<'posts'>;
export type Author = CollectionEntry<'authors'>;

export const SITE = 'https://blog.kwatch.dev';

// Drafts are excluded from production builds. `SHOW_DRAFTS=1` includes them
// for a preview build; `astro dev` always includes them.
const showDrafts = !import.meta.env.PROD || process.env.SHOW_DRAFTS === '1';

export async function getPosts(): Promise<Post[]> {
  const posts = await getCollection('posts', ({ data }) => showDrafts || !data.draft);
  return posts.sort((a, b) => b.data.date.valueOf() - a.data.date.valueOf());
}

export async function getAuthors(): Promise<Author[]> {
  return getCollection('authors');
}

/** Whole minutes to read, at 200 words a minute, never under 1. */
export function readingTime(body: string | undefined): number {
  const words = (body ?? '')
    .replace(/^import .*$/gm, '')
    .replace(/<[^>]+>/g, ' ')
    .split(/\s+/)
    .filter(Boolean).length;
  return Math.max(1, Math.round(words / 200));
}

export function tagSlug(tag: string): string {
  return tag.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

export function tagCounts(posts: Post[]): { tag: string; slug: string; count: number }[] {
  const map = new Map<string, number>();
  for (const p of posts) for (const t of p.data.tags) map.set(t, (map.get(t) ?? 0) + 1);
  return [...map.entries()]
    .map(([tag, count]) => ({ tag, slug: tagSlug(tag), count }))
    .sort((a, b) => b.count - a.count || a.tag.localeCompare(b.tag));
}

const fmt = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' });
export const formatDate = (d: Date) => fmt.format(d);
export const isoDate = (d: Date) => d.toISOString().slice(0, 10);

/** Tag ledes use the glossary wording in MESSAGING.md section 4. */
export const tagInfo: Record<string, { lede: string; glossary?: string }> = {
  CrashLoopBackOff: {
    lede: 'A pod keeps starting, failing and restarting. These posts read the last crash and follow it to its cause.',
    glossary: 'https://docs.kwatch.dev/glossary#crashloopbackoff',
  },
  OOMKilled: {
    lede: 'A pod used more memory than allowed and was stopped. These posts read the limit, the usage and the exit code.',
    glossary: 'https://docs.kwatch.dev/glossary#oomkilled',
  },
  'Root cause': { lede: 'Posts that follow a failure upstream to the one thing that started it.' },
  Pro: { lede: 'What Pro adds to the cause, and how to get a free license from the installer.' },
  Releases: { lede: 'What changed in kwatch, and what it means for the message you get.' },
};
export const tagLede = (tag: string) =>
  tagInfo[tag]?.lede ?? `Posts tagged ${tag}.`;
