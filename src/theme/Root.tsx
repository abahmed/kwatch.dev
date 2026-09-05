import React from 'react';
import type { ReactNode } from 'react';
import Head from '@docusaurus/Head';
import {useLocation} from '@docusaurus/router';

const structuredData = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'WebSite',
      '@id': 'https://kwatch.dev/#website',
      name: 'kwatch',
      url: 'https://kwatch.dev/',
      description:
        'Open-source Kubernetes incident monitoring and alerting.',
      inLanguage: 'en',
      publisher: {'@id': 'https://kwatch.dev/#organization'},
    },
    {
      '@type': 'Organization',
      '@id': 'https://kwatch.dev/#organization',
      name: 'kwatch',
      url: 'https://kwatch.dev/',
      logo: {
        '@type': 'ImageObject',
        url: 'https://kwatch.dev/img/kwatch-logo-full.png',
      },
      sameAs: [
        'https://github.com/abahmed/kwatch',
        'https://discord.gg/kzJszdKmJ7',
      ],
    },
    {
      '@type': 'SoftwareApplication',
      '@id': 'https://kwatch.dev/#software',
      name: 'kwatch',
      applicationCategory: 'DeveloperApplication',
      applicationSubCategory: 'Kubernetes monitoring and alerting',
      operatingSystem: 'Kubernetes',
      description:
        'See what broke. Understand why. Know what to do next. Open-source Kubernetes incident monitoring and alerting.',
      url: 'https://kwatch.dev/',
      image: 'https://kwatch.dev/img/kwatch-logo-full.png',
      downloadUrl: 'https://github.com/abahmed/kwatch/releases/latest',
      publisher: {'@id': 'https://kwatch.dev/#organization'},
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'USD',
      },
    },
  ],
};

export default function Root({children}: {children: ReactNode}) {
  const {pathname} = useLocation();
  const isThinBlogRoute =
    pathname === '/blog/archive' ||
    pathname === '/blog/authors' ||
    pathname.startsWith('/blog/tags/');
  const isNoIndexRoute = isThinBlogRoute || pathname === '/404.html';

  return (
    <>
      <Head>
        {isNoIndexRoute && (
          <meta name="robots" content="noindex, follow" />
        )}
        {pathname === '/' && (
          <script type="application/ld+json">
            {JSON.stringify(structuredData)}
          </script>
        )}
      </Head>
      {children}
    </>
  );
}
