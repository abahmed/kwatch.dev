import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const posts = defineCollection({
  loader: glob({ pattern: '**/*.mdx', base: './src/content/posts' }),
  schema: z.object({
    title: z.string().min(1),
    description: z.string().min(1),
    date: z.coerce.date(),
    updated: z.coerce.date().optional(),
    author: z.string(),
    tags: z.array(z.string()).min(1),
    cover: z.string().optional(),
    // Optional kwatch output shown in the featured card and the og image.
    output: z.string().optional(),
    draft: z.boolean().default(false),
  }),
});

const authors = defineCollection({
  loader: glob({ pattern: '**/*.json', base: './src/content/authors' }),
  schema: z.object({
    name: z.string(),
    bio: z.string(),
    github: z.string().url().optional(),
    site: z.string().url().optional(),
  }),
});

export const collections = { posts, authors };
