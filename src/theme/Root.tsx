import React from 'react';
import type { ReactNode } from 'react';
import Head from '@docusaurus/Head';

const structuredData = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'kwatch',
  applicationCategory: 'DeveloperApplication',
  applicationSubCategory: 'Kubernetes monitoring and alerting',
  operatingSystem: 'Kubernetes',
  description:
    'See what broke. Understand why. Know what to do next. Open-source Kubernetes incident monitoring and alerting.',
  url: 'https://kwatch.dev',
  downloadUrl: 'https://github.com/abahmed/kwatch/releases/latest',
  author: {
    '@type': 'Person',
    name: 'Abdelrahman Ahmed',
    url: 'https://github.com/abahmed',
  },
  sameAs: [
    'https://github.com/abahmed/kwatch',
    'https://discord.gg/kzJszdKmJ7',
  ],
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'USD',
  },
  keywords:
    'kubernetes monitoring, kubernetes alerting, pod crash monitoring, devops',
};

export default function Root({children}: {children: ReactNode}) {
  return (
    <>
      <Head>
        <script type="application/ld+json">{JSON.stringify(structuredData)}</script>
      </Head>
      {children}
    </>
  );
}
