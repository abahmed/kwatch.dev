import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';
import EarlyAccess from '@site/src/theme/EarlyAccess';

import styles from './styles.module.css';

export default function EditionsTeaser(): ReactElement {
  return (
    <section className={styles.section} id="editions">
      <div className="container">
        <div className={styles.heading}>
          <EarlyAccess to={null} />
          <h2>Free to run. Pro when you need the proof.</h2>
          <p>
            Community covers the failures that page you most and is free
            forever. Pro adds the depth for production teams and is free
            during early access.
          </p>
        </div>
        <div className={styles.grid}>
          <div className={styles.card}>
            <h3>Community</h3>
            <p className={styles.sub}>Free forever. No account, no key.</p>
            <ul>
              <li>Pod crashes, OOM kills and Pending pods</li>
              <li>Node NotReady</li>
              <li>Root-cause headline on every incident</li>
              <li>Dedup, namespace filters and silences</li>
              <li>1 alert provider</li>
            </ul>
            <Link className="button button--secondary" to="/docs/installation">
              Install kwatch
            </Link>
          </div>
          <div className={`${styles.card} ${styles.featured}`}>
            <h3>Pro</h3>
            <p className={styles.sub}>Free during early access. 3-month licenses, may be renewed.</p>
            <ul>
              <li>Everything in Community</li>
              <li>Rollouts, storage, network, certificates, control plane and more</li>
              <li>Full proof, who changed what, impact and log excerpts</li>
              <li>Routing, threads, templates and runbooks</li>
              <li>State kept across restarts, standby replicas, flight recorder</li>
            </ul>
            <Link className="button button--primary" to="/signup">
              Get Pro free
            </Link>
          </div>
        </div>
        <div className={styles.more}>
          <Link to="/pricing">
            Compare Community and Pro <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </section>
  );
}
