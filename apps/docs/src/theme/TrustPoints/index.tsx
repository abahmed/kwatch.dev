import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

const points = [
  {
    title: 'Runs in your cluster',
    text: 'One small pod with read-only access. There is no hosted service to sign up for.',
  },
  {
    title: 'Nothing leaves but alerts',
    text: 'Cluster data goes only to the providers you configure. A Pro key adds one hashed license check: a hashed cluster id, the version and the node count.',
    to: '/privacy',
    cta: 'Privacy policy',
  },
  {
    title: '50+ alert providers',
    text: 'Slack, Teams, Discord, PagerDuty, Opsgenie, email, webhooks and more.',
    to: '/docs/channels',
    cta: 'All channels',
  },
  {
    title: 'Source available',
    text: 'Read and change the code under the Elastic License 2.0. Releases up to v1.0.0-rc.10 are MIT.',
    to: '/docs/licensing',
    cta: 'Licensing',
  },
];

export default function TrustPoints(): ReactElement {
  return (
    <section className={styles.section} id="trust">
      <div className="container">
        <div className={styles.heading}>
          <p className={styles.eyebrow}>Why teams trust it</p>
          <h2>Built to be safe to leave running.</h2>
        </div>
        <ul className={styles.grid}>
          {points.map((p) => (
            <li className={styles.card} key={p.title}>
              <h3>{p.title}</h3>
              <p>{p.text}</p>
              {p.to && (
                <Link to={p.to}>
                  {p.cta} <span aria-hidden="true">→</span>
                </Link>
              )}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
