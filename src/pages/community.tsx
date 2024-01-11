import React from 'react';
import clsx from 'clsx';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import classnames from 'classnames';
import Link from '@docusaurus/Link';

import styles from './community.module.css';

export default function Community(): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout title="Community" description="Where to ask questions and get in touch">
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
            <div className="col text--center padding-vert--md">
              <div className="card">
                <div className="card__header">
                  <i className={classnames(styles.icon, styles.discord)}></i>
                </div>
                <div className="card__body">
                  <p>Join the official kwatch discord server</p>
                </div>
                <div className="card__footer">
                  <Link to="https://discord.gg/kzJszdKmJ7" className="button button--outline button--primary button--block">Join</Link>
                </div>
              </div>
            </div>

            <div className="col text--center padding-vert--md">
              <div className="card">
                <div className="card__header">
                  <i className={classnames(styles.icon, styles.email)}></i>
                </div>
                <div className="card__body">
                  <p>Say hello via email</p>
                </div>
                <div className="card__footer">
                  <Link to="mailto:hello@kwatch.dev" className="button button--outline button--primary button--block">hello&#64;kwatch.dev</Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </Layout>
  );
}
