import React from 'react';
import type {ReactNode} from 'react';
import Head from '@docusaurus/Head';
import Layout from '@theme-original/DocItem/Layout';
import type LayoutType from '@theme/DocItem/Layout';
import type {WrapperProps} from '@docusaurus/types';
import {useDoc} from '@docusaurus/plugin-content-docs/client';

type Props = WrapperProps<typeof LayoutType>;

const origin = 'https://docs.kwatch.dev';

// TechArticle JSON-LD for every doc page. Docusaurus already emits the
// BreadcrumbList.
export default function LayoutWrapper(props: Props): ReactNode {
  const {metadata, frontMatter} = useDoc();
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

  return (
    <>
      <Head>
        <script type="application/ld+json">{JSON.stringify(article)}</script>
      </Head>
      <Layout {...props} />
    </>
  );
}
