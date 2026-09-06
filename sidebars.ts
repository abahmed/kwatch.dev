import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    {type: 'doc', id: 'getting-started', label: '👋 Start here'},
    {
      type: 'category',
      label: '🚀 Install kwatch',
      items: ['installation', 'kwatch-manager', 'kwatch-sh'],
    },
    {
      type: 'category',
      label: '📣 Alerts & channels',
      items: [
        'channels/channels',
        'channels/slack',
        'channels/discord',
        'channels/ms-teams',
        'channels/googlechat',
        'channels/telegram',
        'channels/email',
        'channels/pagerduty',
        'channels/opsgenie',
        'channels/zenduty',
        'channels/mattermost',
        'channels/rocketchat',
        'channels/matrix',
        'channels/dingtalk',
        'channels/feishu',
        'channels/webhook',
        'channels/providers',
      ],
    },
    {
      type: 'category',
      label: '🎯 Monitors',
      items: [
        'general-configuration',
        'configuration-reference',
        'rollout-monitor-configuration',
        'daemonset-monitor-configuration',
        'job-monitor-configuration',
        'cronjob-monitor-configuration',
        'hpa-monitor-configuration',
        'heartbeat-monitor-configuration',
        'tls-monitor-configuration',
      ],
    },
    'cli-commands',
    {
      type: 'category',
      label: '🏗️ How kwatch works',
      items: [
        'architecture/overview',
        'architecture/packages-overview',
        'architecture/correlation-and-alerting',
        'architecture/infrastructure-packages',
        'architecture/data-flow',
        'architecture/design-decisions',
      ],
    },
    {
      type: 'category',
      label: '📚 Reference & trust',
      items: [
        'kubernetes-coverage',
        'feature-reference',
        'release-integrity',
        'licensing',
        'third-party-notices',
        'trademarks',
      ],
    },
    {
      type: 'category',
      label: '🤝 Contributing',
      items: [
        'contributing/contributing',
        'contributing/cloning-and-building',
        'contributing/github-workflow',
        'contributing/release-process',
      ],
    },
  ],
};

export default sidebars;
