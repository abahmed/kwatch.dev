import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const logo = {
  alt: 'kwatch Kubernetes incident monitoring and alerting',
  src: 'img/kwatch-logo.svg',
};

const siteDescription =
  'See what broke. Understand why. Know what to do next. Open-source Kubernetes incident monitoring and alerting.';

const config: Config = {
  title: 'kwatch',
  tagline: 'See what broke. Understand why. Know what to do next. 👀🧠⚡',
  favicon: 'img/kwatch-logo.svg',

  // Set the production url of your site here
  url: 'https://kwatch.dev',
  // Render serves the site from the domain root.
  baseUrl: '/',

  organizationName: 'abahmed', // GitHub owner of the documentation site.
  projectName: 'kwatch.dev', // Repository containing the documentation site.

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  customFields: {
    description: siteDescription,
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
          blogTitle: 'Kubernetes monitoring and incident response blog',
          blogDescription:
            'Practical Kubernetes monitoring, incident diagnosis, and alerting guides from the kwatch team.',
          feedOptions: {
            type: 'all',
            title: 'kwatch Blog',
            description: 'Latest news and updates about kwatch — Kubernetes incident monitoring',
            copyright: `Copyright © ${new Date().getFullYear()} kwatch`,
          },
        },
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          ignorePatterns: [
            '/blog/archive',
            '/blog/authors',
            '/blog/tags/**',
          ],
          lastmod: 'date',
          filename: 'sitemap.xml',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/kwatch-logo-full.png',
    metadata: [
      {
        name: 'author',
        content: 'kwatch contributors',
      },
      {
        name: 'keywords',
        content:
          'kubernetes monitoring, kubernetes alerting, k8s alerts, pod crash monitoring, incident diagnosis, devops, cloud native',
      },
      {property: 'og:type', content: 'website'},
      {property: 'og:site_name', content: 'kwatch'},
      {
        property: 'og:image:alt',
        content: 'kwatch Kubernetes incident monitoring and alerting',
      },
      {name: 'twitter:card', content: 'summary_large_image'},
      {
        name: 'twitter:image:alt',
        content: 'kwatch Kubernetes incident monitoring and alerting',
      },
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
        {
          to: '/docs/installation',
          label: 'Install',
          position: 'left',
          className: 'navbar-install-link',
        },
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
