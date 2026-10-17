import React from 'react';
import type { ReactNode } from 'react';
import Head from '@docusaurus/Head';
import {useLocation} from '@docusaurus/router';

const origin = 'https://docs.kwatch.dev';

const structuredData = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  '@id': `${origin}/#website`,
  name: 'kwatch docs',
  url: `${origin}/`,
  description:
    'Documentation for kwatch, source-available Kubernetes incident monitoring and alerting.',
  inLanguage: 'en',
  publisher: {'@type': 'Organization', name: 'kwatch', url: 'https://kwatch.dev/'},
};

export default function Root({children}: {children: ReactNode}) {
  const {pathname} = useLocation();
  const isNoIndexRoute = pathname === '/404' || pathname === '/404.html';
  const canonicalPath =
    pathname.length > 1 && pathname.endsWith('/')
      ? pathname.slice(0, -1)
      : pathname || '/';
  const canonicalURL = `${origin}${canonicalPath}`;

  return (
    <>
      <Head>
        <link rel="canonical" href={canonicalURL} />
        <meta property="og:url" content={canonicalURL} />
        <meta
          name="robots"
          content={
            isNoIndexRoute
              ? 'noindex, follow'
              : 'index, follow, max-image-preview:large'
          }
        />
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
