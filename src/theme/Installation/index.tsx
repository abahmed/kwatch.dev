import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';
import CodeSnippet from '@site/src/theme/CodeSnippet';

import styles from './styles.module.css';

const steps = [
  {
    number: '01',
    title: 'Choose your cluster',
    detail: 'The manager shows the current kubectl context before installing.',
  },
  {
    number: '02',
    title: 'Connect a channel',
    detail: 'It stores credentials in a Kubernetes Secret.',
  },
  {
    number: '03',
    title: 'Verify the install',
    detail: 'It checks the deployment before you start monitoring.',
  },
];

export default function Installation(): ReactElement {
  return (
    <section id="installation" className={styles.installation}>
      <div className="container">
        <div className={styles.heading}>
          <p className={styles.eyebrow}>Get started</p>
          <h2>From command to useful alerts.</h2>
          <p>
            The interactive <code>kwatch.sh</code> manager guides installation,
            channel setup, and verification. You need Bash, curl, kubectl,
            and cluster install permissions.
          </p>
        </div>

        <div className={styles.layout}>
          <div className={styles.commandCard}>
            <div className={styles.commandHeader}>
              <span className={styles.windowDots} aria-hidden="true">
                <i /><i /><i />
              </span>
              <span>Install kwatch</span>
              <span className={styles.recommended}>Recommended</span>
            </div>
            <div className={styles.commandBody}>
              <p>Run the manager on a machine with access to your cluster.</p>
              <CodeSnippet
                language="bash"
                code={'/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"'}
              />
              <p className={styles.commandNote}>
                Run it again to change settings, upgrade, check status,
                or uninstall.
              </p>
            </div>
          </div>

          <div className={styles.steps} aria-label="Installation steps">
            {steps.map((step) => (
              <div className={styles.step} key={step.number}>
                <span className={styles.stepNum}>{step.number}</span>
                <div>
                  <h3>{step.title}</h3>
                  <p>{step.detail}</p>
                </div>
              </div>
            ))}
            <Link to="/docs/installation">
              Read the installation guide <span aria-hidden="true">→</span>
            </Link>
          </div>
        </div>

        <div className={styles.reliability}>
          <span>Built for production</span>
          <p>
            Two replicas by default: one active leader and one standby.
            A single-replica option is available without kwatch self-failover.
          </p>
          <Link to="/docs/operations/replication-and-failover">
            How failover works <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </section>
  );
}
