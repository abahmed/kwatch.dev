import React from 'react';
import clsx from 'clsx';
import styles from './community.module.scss';
import classnames from 'classnames';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';

import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

function Community() {
  const context = useDocusaurusContext();

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
              <div class="card">
                <div class="card__header">
                  <i className={classnames(styles.icon, styles.discord)}></i>
                </div>
                <div class="card__body">
                  <p>Join the official kwatch discord server</p>
                </div>
                <div class="card__footer">
                  <Link to="https://discord.gg/kzJszdKmJ7" class="button button--outline button--primary button--block">Join</Link>
                </div>
              </div>
            </div>

            <div className="col text--center padding-vert--md">
              <div class="card">
                <div class="card__header">
                  <i className={classnames(styles.icon, styles.email)}></i>
                </div>
                <div class="card__body">
                  <p>Say hello via email</p>
                </div>
                <div class="card__footer">
                  <Link to="mailto:hello@kwatch.dev" class="button button--outline button--primary button--block">hello&#64;kwatch.dev</Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </Layout>
  );
}

export default Community;