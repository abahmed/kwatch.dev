import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Header from '@site/src/theme/Header';
import Installation from '@site/src/theme/Installation';
import Features from '@site/src/theme/Features';

import styles from './index.module.css';

const paths = [
  {
    label: '01 / Start here',
    title: 'Understand kwatch',
    description: 'A quick tour of incidents and monitoring coverage.',
    href: '/docs',
  },
  {
    label: '02 / Set up',
    title: 'Install kwatch',
    description: 'One guided command, followed by a verified deployment.',
    href: '/docs/installation',
  },
  {
    label: '03 / Connect',
    title: 'Choose a channel',
    description: 'Send incidents to chat, on-call, email, or a webhook.',
    href: '/docs/channels',
  },
  {
    label: '04 / Operate',
    title: 'Troubleshoot alerts',
    description: 'Trace a missing alert from detection to delivery.',
    href: '/docs/operations/troubleshooting',
  },
];

const channels = [
  {name: 'Slack', href: '/docs/channels/slack'},
  {name: 'Discord', href: '/docs/channels/discord'},
  {name: 'Microsoft Teams', href: '/docs/channels/ms-teams'},
  {name: 'PagerDuty', href: '/docs/channels/pagerduty'},
  {name: 'Email', href: '/docs/channels/email'},
  {name: 'Webhook', href: '/docs/channels/webhook'},
];

export default function Home(): ReactElement {
  return (
    <Layout
      title="Kubernetes incidents, explained"
      description="See what broke. Understand why. Know what to do next. Open-source Kubernetes incident monitoring and alerting."
    >
      <main>
        <Header />
        <nav className={styles.pathSection} aria-label="Explore kwatch">
          <div className="container">
            <div className={styles.sectionHeading}>
              <p className={styles.eyebrow}>Explore kwatch</p>
              <h2>Pick up where you are.</h2>
              <p>From first look to production response, find the right guide.</p>
            </div>
            <div className={styles.pathGrid}>
              {paths.map((path) => (
                <Link className={styles.pathCard} key={path.title} to={path.href}>
                  <span className={styles.pathLabel}>{path.label}</span>
                  <strong>{path.title} <span aria-hidden="true">→</span></strong>
                  <span className={styles.pathDescription}>
                    {path.description}
                  </span>
                </Link>
              ))}
            </div>
          </div>
        </nav>

        <Features />

        <Installation />

        <section className={styles.channelsSection}>
          <div className="container">
            <div className={styles.channelLayout}>
              <div className={styles.sectionHeading}>
                <p className={styles.eyebrow}>Notifications</p>
                <h2>Send alerts where your team works.</h2>
                <p>
                  Connect a familiar destination first. Choose from 56
                  integrations when your team needs more routes.
                </p>
                <Link className={styles.allChannels} to="/docs/channels">
                  See all channels <span aria-hidden="true">→</span>
                </Link>
              </div>
              <div className={styles.channelGrid}>
                {channels.map((channel) => (
                  <Link key={channel.name} to={channel.href}>
                    {channel.name} <span aria-hidden="true">↗</span>
                  </Link>
                ))}
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
