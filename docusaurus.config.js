const logo = {
  alt: 'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  src: 'img/kwatch-logo.png',
};

const config = {
  title: 'kwatch',
  tagline: 'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  url: 'https://kwatch.dev',
  baseUrl: '/',
  customFields: {
    description:
    'monitor & detect crashes in your Kubernetes(K8s) cluster instantly',
  },
  trailingSlash: false,
  onBrokenLinks: 'log',
  onBrokenMarkdownLinks: 'warn',
  favicon: 'img/kwatch-logo.png',
  organizationName: 'kwatch',
  projectName: 'kwatch',
  plugins: [
    'docusaurus-plugin-sass',
  ],

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          //editUrl: 'https://github.com/abahmed/kwatch.dev/tree/main/',
        },
        blog: {
          showReadingTime: true,
          blogSidebarCount: 0,
          //editUrl: 'https://github.com/abahmed/kwatch.dev/tree/main/',
        },
        theme: {
          customCss: require.resolve('./src/css/custom.scss'),
        },
        sitemap: {
          changefreq: 'weekly',
          priority: 0.5,
        },
        googleAnalytics: {
          trackingID: 'UA-162766515-1',
          anonymizeIP: true,
        },
      }),
    ],
  ],

  themeConfig:
    ({
      colorMode: {
        defaultMode: 'light',
        disableSwitch: true,
        respectPrefersColorScheme: false,
        switchConfig: {
          darkIcon: "🌙",
          darkIconStyle: {
            marginLeft: "2px",
          },
          lightIcon: "☀️",
          lightIconStyle: {
            marginLeft: "1px",
          },
        },
      },
      navbar: {
        title: 'kwatch',
        logo: logo,
        items: [
          {to: '/docs', label: 'Docs', position: 'left'},
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
        backgroundColor: '#0b8df5',
        textColor: 'white',
        isCloseable: false,
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
        theme: require("prism-react-renderer/themes/github"),
        darkTheme: require("prism-react-renderer/themes/dracula"),
      },
    }),
};

module.exports = config;
