import React from 'react';
import type { ReactElement } from 'react';
import clsx from 'clsx';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';

import styles from './community.module.css';

const channels = [
  {
    title: 'Discord',
    description: 'Join the official kwatch Discord server — ask questions, get help, and chat with the community',
    url: 'https://discord.gg/kzJszdKmJ7',
    icon: styles.discord,
    cta: 'Join',
  },
  {
    title: 'GitHub',
    description: 'Star the repo, report bugs, suggest features, and browse the source code',
    url: 'https://github.com/abahmed/kwatch',
    icon: styles.github,
    cta: 'Star',
  },
  {
    title: 'Email',
    description: 'Say hello, ask questions, or reach out to the maintainers directly',
    url: 'mailto:hello@kwatch.dev',
    icon: styles.email,
    cta: 'hello@kwatch.dev',
  },
];

export default function Community(): ReactElement {
  return (
    <Layout
      title="Community"
      description="Join the kwatch community for Kubernetes monitoring help, bug reports, and open-source discussions."
    >
      <header id="hero" className={clsx("hero", styles.banner)}>
        <div className="container">
          <h1 className="hero__title">Community</h1>
          <p className={clsx("hero__subtitle", styles.subtitle)}>
            These are places where you can ask questions and get in touch!
          </p>
        </div>
      </header>
      <main>
        <div className="container">
          <div className="row margin-vert--lg">
            {channels.map((channel) => (
              <div className="col col--4 text--center padding-vert--md" key={channel.title}>
                <div className="card">
                  <div className="card__header">
                    <i className={clsx(styles.icon, channel.icon)}></i>
                  </div>
                  <div className="card__body">
                    <h3>{channel.title}</h3>
                    <p>{channel.description}</p>
                  </div>
                  <div className="card__footer">
                    <Link to={channel.url} className="button button--outline button--primary button--block">{channel.cta}</Link>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </main>
    </Layout>
  );
}
