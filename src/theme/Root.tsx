import React from 'react';
import Head from '@docusaurus/Head';

const structuredData = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'kwatch',
  applicationCategory: 'DeveloperApplication',
  operatingSystem: 'Kubernetes',
  description:
    'kwatch monitors your Kubernetes cluster and sends crash alerts with plain-English explanations of what went wrong and how to fix it',
  url: 'https://kwatch.dev',
  downloadUrl: 'https://github.com/abahmed/kwatch/releases/latest',
  author: {
    '@type': 'Person',
    name: 'Abdelrahman Ahmed',
    url: 'https://github.com/abahmed',
  },
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'USD',
  },
  keywords: 'kubernetes k8s crash monitoring alerting devops',
};

export default function Root({children}) {
  return (
    <>
      <Head>
        <script type="application/ld+json">{JSON.stringify(structuredData)}</script>
      </Head>
      {children}
    </>
  );
}
