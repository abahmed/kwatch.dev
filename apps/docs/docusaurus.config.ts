import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const logo = {
  alt: 'kwatch',
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
        {href: 'https://kwatch.dev', label: 'kwatch.dev', position: 'right'},
        {
          href: 'https://github.com/abahmed/kwatch',
          label: 'GitHub',
          position: 'right',
        },
        {
          href: 'https://app.kwatch.dev',
          label: 'Sign in',
          position: 'right',
          className: 'navbar-signin-link',
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
      style: 'light',
      links: [
        {
          title: 'Get started',
          items: [
            {label: 'Installation', to: '/installation'},
            {label: 'Configuration', to: '/general-configuration'},
            {label: 'Channels', to: '/channels'},
            {label: 'CLI commands', to: '/cli-commands'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'kwatch.dev', href: 'https://kwatch.dev'},
            {label: 'GitHub', href: 'https://github.com/abahmed/kwatch'},
            {label: 'Discord', href: 'https://discord.gg/kzJszdKmJ7'},
            {label: 'Contributing', to: '/contributing'},
          ],
        },
        {
          title: 'Account and legal',
          items: [
            {label: 'Pro', href: 'https://kwatch.dev/pro'},
            {label: 'Sign in', href: 'https://app.kwatch.dev'},
            {label: 'Privacy', href: 'https://kwatch.dev/privacy'},
            {label: 'Terms', href: 'https://kwatch.dev/terms'},
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
