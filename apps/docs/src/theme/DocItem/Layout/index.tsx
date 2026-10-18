import React from 'react';
import type {ReactNode} from 'react';
import Head from '@docusaurus/Head';
import Layout from '@theme-original/DocItem/Layout';
import type LayoutType from '@theme/DocItem/Layout';
import type {WrapperProps} from '@docusaurus/types';
import {useDoc} from '@docusaurus/plugin-content-docs/client';
import {useSidebarBreadcrumbs} from '@docusaurus/plugin-content-docs/client';

type Props = WrapperProps<typeof LayoutType>;

const origin = 'https://docs.kwatch.dev';

// TechArticle and BreadcrumbList JSON-LD for every doc page.
export default function LayoutWrapper(props: Props): ReactNode {
  const {metadata, frontMatter} = useDoc();
  const crumbs = useSidebarBreadcrumbs() ?? [];
  const url = `${origin}${metadata.permalink === '/' ? '/' : metadata.permalink}`;
  const article: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': 'TechArticle',
    headline: metadata.title,
    description: metadata.description,
    url,
    inLanguage: 'en',
    isPartOf: {'@id': `${origin}/#website`},
    publisher: {'@type': 'Organization', name: 'kwatch', url: 'https://kwatch.dev/'},
  };
  if (metadata.lastUpdatedAt) {
    article.dateModified = new Date(metadata.lastUpdatedAt).toISOString();
  }
  const keywords = frontMatter.keywords;
  if (keywords && keywords.length) article.keywords = keywords.join(', ');

  const items = [
    {name: 'kwatch docs', item: `${origin}/`},
    ...crumbs
      .filter((c) => c.href)
      .map((c) => ({name: c.label, item: `${origin}${c.href}`})),
  ];
  if (items[items.length - 1]?.item !== url) {
    items.push({name: metadata.title, item: url});
  }
  const breadcrumbs = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((entry, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: entry.name,
      item: entry.item,
    })),
  };

  return (
    <>
      <Head>
        <script type="application/ld+json">{JSON.stringify(article)}</script>
        <script type="application/ld+json">{JSON.stringify(breadcrumbs)}</script>
      </Head>
      <Layout {...props} />
    </>
  );
}
