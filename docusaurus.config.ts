import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import { EnumChangefreq } from 'sitemap';

const logo = {
  alt: 'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  src: 'img/kwatch-logo.png',
};

const config: Config = {
  title: 'kwatch',
  tagline: 'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  favicon: 'img/kwatch-logo.png',

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
  onBrokenMarkdownLinks: 'warn',

  customFields: {
    description:
    'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
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
        },
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          changefreq: EnumChangefreq.DAILY,
          priority: 0.5,
          filename: 'sitemap.xml',
        },
        googleAnalytics: {
          trackingID: 'UA-162766515-2',
          anonymizeIP: true,
        },
        gtag: {
          trackingID: 'G-999X9XX9XX',
          anonymizeIP: true,
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      defaultMode: 'light',
      disableSwitch: true,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'kwatch',
      logo: logo,
      items: [
        {to: '/docs', label: 'Docs', position: 'left'},
        {to: '/docs/contributing', label: 'Contributing', position: 'left'},
        {to: '/blog', label: 'Blog', position: 'left'},
        // {to: 'https://join.kwatch.dev', label: 'Join Waitlist', position: 'right'},
        {to: 'community', label: 'Community', position: 'right'},
        {
          href: 'https://github.com/abahmed/kwatch/releases/latest',
          position: 'right',
          className: 'header-download-link header-icon-link',
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
          title: 'Docs',
          items: [
            {
              label: 'Getting started',
              to: 'docs',
            },
            {to: '/docs/contributing', label: 'Contributing'},
            {
              label: 'Blog',
              to: '/blog',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Join the chat',
              href: 'https://discord.gg/kzJszdKmJ7',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/abahmed/kwatch',
            },
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
