import {kwatchPrismTheme} from './src/prism-theme';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const logo = {
  alt: 'kwatch',
  href: 'https://kwatch.dev',
  target: '_self',
  src: 'img/junction.svg',
  srcDark: 'img/junction-dark.svg',
};

const siteDescription =
  'See what broke. Understand why. Know what to do next. Source-available Kubernetes incident monitoring and alerting.';

const config: Config = {
  title: 'kwatch',
  tagline: 'See what broke. Understand why. Know what to do next. 👀🧠⚡',
  favicon: 'img/favicon.svg',

  // Docs live on their own host. kwatch.dev/docs/* redirects here.
  url: 'https://docs.kwatch.dev',
  baseUrl: '/',

  organizationName: 'abahmed', // GitHub owner of the documentation site.
  projectName: 'kwatch.dev', // Repository containing the documentation site.

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
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
          // Docs only: /installation, not /docs/installation.
          routeBasePath: '/',
          editUrl: 'https://github.com/abahmed/kwatch.dev/tree/main/apps/docs/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
        sitemap: {
          lastmod: 'date',
          filename: 'sitemap.xml',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/og.png',
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
      // Light or dark follows the OS setting; the design has no toggle.
      defaultMode: 'light',
      disableSwitch: true,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'kwatch docs',
      logo: logo,
      items: [
        {type: 'search', position: 'left'},
        {to: '/', label: 'Docs', position: 'right'},
        {href: 'https://kwatch.dev/pro', label: 'Pro', position: 'right'},
        {href: 'https://kwatch.dev/support', label: 'Get help', position: 'right'},
        {
          href: 'https://app.kwatch.dev',
          label: 'Sign in',
          position: 'right',
          className: 'navbar-signin-link',
        },
      ],
    },
    footer: {
      style: 'light',
      copyright:
        'kwatch · source available under ELv2' +
        ' <a href="/">Docs</a>' +
        ' <a href="https://github.com/abahmed/kwatch">GitHub</a>' +
        ' <a href="https://kwatch.dev/support">Get help</a>' +
        ' <a href="https://kwatch.dev/privacy">Privacy</a>' +
        ' <a href="https://kwatch.dev/terms">Terms</a>',
    },
    prism: {
      theme: kwatchPrismTheme,
      darkTheme: kwatchPrismTheme,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
