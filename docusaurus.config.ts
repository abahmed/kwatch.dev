import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import { EnumChangefreq } from 'sitemap';

const logo = {
  alt: 'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  src: 'img/kwatch-logo.svg',
};

const config: Config = {
  title: 'kwatch',
  tagline: 'Monitor your Kubernetes cluster — get crash alerts with plain-English explanations and fixes',
  favicon: 'img/kwatch-logo.svg',

  // Set the production url of your site here
  url: 'https://kwatch.dev',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'kwatch', // Usually your GitHub org/user name.
  projectName: 'kwatch', // Usually your repo name.

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  customFields: {
    description:
    'kwatch monitors your Kubernetes cluster and sends crash alerts with plain-English explanations of what went wrong and how to fix it',
  },
  trailingSlash: false,

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
        },
    blog: {
      showReadingTime: true,
      blogSidebarCount: 0,
      feedOptions: {
        type: 'all',
        title: 'kwatch Blog',
        description: 'Latest news and updates about kwatch — Kubernetes crash monitoring',
        copyright: `Copyright © ${new Date().getFullYear()} kwatch`,
      },
    },
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          changefreq: EnumChangefreq.DAILY,
          priority: 0.5,
          filename: 'sitemap.xml',
        },
        gtag: {
          trackingID: 'G-999X9XX9XX',
          anonymizeIP: true,
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/kwatch-logo-full.png',
    metadata: [
      {name: 'keywords', content: 'kubernetes, k8s, crash monitoring, pod crashes, alerting, devops, cluster monitoring, kubernetes alerts'},
      {property: 'og:title', content: 'kwatch — Kubernetes Crash Monitor'},
      {property: 'og:description', content: 'Monitor your Kubernetes cluster and get crash alerts with plain-English explanations and fixes'},
      {property: 'og:type', content: 'website'},
      {property: 'og:url', content: 'https://kwatch.dev'},
      {name: 'twitter:card', content: 'summary_large_image'},
      {name: 'twitter:title', content: 'kwatch — Kubernetes Crash Monitor'},
      {name: 'twitter:description', content: 'Monitor your Kubernetes cluster and get crash alerts with plain-English explanations and fixes'},
    ],
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'kwatch',
      logo: logo,
      items: [
        {to: '/docs', label: 'Docs', position: 'left'},
        {to: '/docs/installation', label: 'Install', position: 'left'},
        {to: '/docs/channels', label: 'Channels', position: 'left'},
        {to: '/blog', label: 'Blog', position: 'left'},
        {to: '/community', label: 'Community', position: 'right'},
        {
          href: 'https://github.com/abahmed/kwatch/releases/latest',
          position: 'right',
          className: 'header-download-link',
          'aria-label': 'Download',
        },
        {
          href: 'https://github.com/abahmed/kwatch',
          position: 'right',
          className: 'header-github-link',
          'aria-label': 'GitHub repository',
        },
      ],
    },
    /*
    announcementBar: {
      id: 'supportus',
      backgroundColor: '#0b8df5',
      textColor: 'white',
      isCloseable: false,
      content: '⭐️ We\'re working on SAAS version of kwatch that provides User interface, optimized notifications, more details about crashes, and more. you can join <a href="https://join.kwatch.dev">the waitlist</a>! ⭐️',
    },*/
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Getting Started',
          items: [
            {label: 'Installation', to: '/docs/installation'},
            {label: 'Configuration', to: '/docs/general-configuration'},
            {label: 'Channels', to: '/docs/channels'},
            {label: 'CLI Commands', to: '/docs/cli-commands'},
          ],
        },
        {
          title: 'Monitors',
          items: [
            {label: 'Pod Crashes', to: '/docs/general-configuration'},
            {label: 'PVC Disk Usage', to: '/docs/general-configuration'},
            {label: 'Node Health', to: '/docs/general-configuration'},
            {label: 'Rollouts & DaemonSets', to: '/docs/rollout-monitor-configuration'},
            {label: 'Jobs & CronJobs', to: '/docs/job-monitor-configuration'},
            {label: 'HPA & TLS', to: '/docs/hpa-monitor-configuration'},
          ],
        },
        {
          title: 'Community',
          items: [
            {label: 'Discord', href: 'https://discord.gg/kzJszdKmJ7'},
            {label: 'GitHub', href: 'https://github.com/abahmed/kwatch'},
            {label: 'Contributing', to: '/docs/contributing'},
            {label: 'Blog', to: '/blog'},
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} kwatch`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
