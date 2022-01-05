// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const lightCodeTheme = require('prism-react-renderer/themes/github');
const darkCodeTheme = require('prism-react-renderer/themes/dracula');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'kwatch',
  tagline: 'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  url: 'https://kwatch.dev',
  baseUrl: '/',
  customFields: {
    description:
    'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  },
  onBrokenLinks: 'log',
  onBrokenMarkdownLinks: 'warn',
  //favicon: 'img/favicon.ico',
  organizationName: 'kwatch',
  projectName: 'kwatch',

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/abahmed/kwatch.dev/tree/main/',
        },
        blog: {
          showReadingTime: true,
          editUrl: 'https://github.com/abahmed/kwatch.dev/tree/main/',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'kwatch',
        items: [
          {
            type: 'doc',
            docId: 'intro',
            position: 'left',
            label: 'Docs',
          },
          {to: '/docs/contributing', label: 'Contributing', position: 'left'},
          {to: '/blog', label: 'Blog', position: 'left'},
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
      announcementBar: {
        id: 'supportus',
        backgroundColor: '#65b910',
        textColor: 'white',
        content: '⭐️ If you like kwatch, give it a star on <a target="_blank" rel="noopener noreferrer" href="https://github.com/abahmed/kwatch">GitHub</a>! ⭐️',
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              {
                label: 'Getting started',
                to: 'docs/intro',
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
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
      },
    }),
};

module.exports = config;
