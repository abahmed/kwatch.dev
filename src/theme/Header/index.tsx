import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

export default function Header(): ReactElement {
  return (
    <header className={styles.hero}>
      <div className="container">
        <div className={styles.layout}>
          <div className={styles.intro}>
            <p className={styles.eyebrow}>
              Kubernetes incidents, explained
            </p>
            <h1>
              See what broke.
              <span>Understand why.</span>
              <span>Know what to do next.</span>
            </h1>
            <p className={styles.summary}>
              kwatch turns Kubernetes failures into clear alerts with the
              likely cause, useful evidence, and a practical next step.
            </p>
            <div className={styles.actions}>
              <Link
                className="button button--primary button--lg"
                to="/docs/installation"
              >
                Install kwatch <span aria-hidden="true">→</span>
              </Link>
              <Link className={styles.secondaryAction} to="/docs">
                Explore the docs <span aria-hidden="true">↗</span>
              </Link>
            </div>
            <div className={styles.facts} aria-label="Why kwatch">
              <span>Open source</span>
              <span>Runs in your cluster</span>
              <span>No hosted account</span>
            </div>
          </div>

          <div className={styles.example} id="example-alert">
            <div className={styles.exampleHeader}>
              <span className={styles.exampleLabel}>
                <span className={styles.liveDot} aria-hidden="true" />
                Example incident
              </span>
              <span className={styles.exampleSeverity}>High severity</span>
            </div>
            <div className={styles.exampleBody}>
              <p className={styles.exampleReason}>OOMKilled</p>
              <p className={styles.exampleSubject}>production / orders-api</p>
              <p className={styles.exampleMeta}>
                Pod: orders-api-7ffc9d4f9-x9p4t · Node: worker-3
              </p>
              <div className={styles.exampleDetail}>
                <strong>Likely cause</strong>
                <p>The container exceeded its 512Mi memory limit.</p>
              </div>
              <div className={styles.exampleDetail}>
                <strong>Next step</strong>
                <p>Increase <code>limits.memory</code> or reduce memory usage.</p>
              </div>
              <p className={styles.exampleFoot}>
                Recent logs and Kubernetes events add context to the alert.
              </p>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
