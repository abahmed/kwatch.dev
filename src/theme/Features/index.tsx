import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

const steps = [
  {
    number: '01',
    title: 'Detect the problem',
    description:
      'Watch for crashes, stuck workloads, unhealthy nodes, and other cluster signals.',
  },
  {
    number: '02',
    title: 'Connect the clues',
    description:
      'Bring together status, recent logs, Kubernetes events, and affected resources.',
  },
  {
    number: '03',
    title: 'Send a useful alert',
    description:
      'Give responders a likely cause and a next step in the channel they already use.',
  },
];

const coverage = [
  {
    title: 'Pods and scheduling',
    description: 'Crashes, OOM kills, restarts, readiness, and pending Pods.',
  },
  {
    title: 'Workloads',
    description: 'Rollouts, Jobs, CronJobs, autoscaling, and availability.',
  },
  {
    title: 'Infrastructure and storage',
    description: 'Node pressure, persistent storage, and platform health.',
  },
  {
    title: 'Networking and security',
    description: 'Services, Ingress, webhooks, TLS, RBAC, and policy findings.',
  },
];

export default function Features(): ReactElement {
  return (
    <>
      <section className={styles.section} id="how-it-works">
        <div className="container">
          <div className={styles.heading}>
            <p className={styles.eyebrow}>From signal to action</p>
            <h2>Understand the incident without piecing it together yourself</h2>
            <p>
              Kubernetes shows symptoms. kwatch connects the story so your
              team can decide what needs attention.
            </p>
          </div>
          <div className={styles.stepGrid}>
            {steps.map((step) => (
              <div className={styles.step} key={step.number}>
                <span className={styles.stepNumber}>{step.number}</span>
                <h3>{step.title}</h3>
                <p>{step.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className={styles.coverageSection} id="monitors">
        <div className="container">
          <div className={styles.heading}>
            <p className={styles.eyebrow}>Coverage</p>
            <h2>Start with common failures. Add checks as you grow.</h2>
            <p>
              Safe defaults cover everyday incidents. Heartbeat, Metrics
              Server usage, TLS checks, and active probes are available when
              you need them.
            </p>
          </div>
          <div className={styles.coverageGrid}>
            {coverage.map((area) => (
              <div className={styles.coverageCard} key={area.title}>
                <h3>{area.title}</h3>
                <p>{area.description}</p>
              </div>
            ))}
          </div>
          <div className={styles.more}>
            <Link to="/docs/kubernetes-coverage">
              Explore everything kwatch monitors <span aria-hidden="true">→</span>
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
