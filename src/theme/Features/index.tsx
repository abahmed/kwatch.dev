import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

const steps = [
  {
    number: '01',
    title: 'Watch',
    description:
      'kwatch keeps a live map of your cluster: every object, how they connect, and what changed.',
  },
  {
    number: '02',
    title: 'Detect',
    description:
      'It spots crash loops, unready nodes, stuck workloads and other unhealthy signals.',
  },
  {
    number: '03',
    title: 'Explain',
    description:
      'It follows each failure upstream to the one cause that explains the rest.',
  },
  {
    number: '04',
    title: 'Tell',
    description:
      'One message per cause, in the channel you already use. Updated only on news, closed once fixed.',
  },
];

const coverage = [
  {
    title: 'Pods and scheduling',
    description: 'Crashes, OOM kills, restarts and pending Pods in Community. Readiness checks in Pro.',
  },
  {
    title: 'Workloads',
    description: 'Rollouts, Jobs, CronJobs, autoscaling and availability. Part of Pro.',
  },
  {
    title: 'Infrastructure and storage',
    description: 'Node NotReady in Community. Node pressure, persistent storage and the control plane in Pro.',
  },
  {
    title: 'Networking and security',
    description: 'RBAC findings in Community. Services, Ingress, webhooks, TLS and quota in Pro.',
  },
];

export default function Features(): ReactElement {
  return (
    <>
      <section className={styles.section} id="how-it-works">
        <div className="container">
          <div className={styles.heading}>
            <p className={styles.eyebrow}>How it works</p>
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
              Community covers the everyday incidents. Pro adds the wider
              detectors, and opt-in heartbeat, TLS checks and active probes.
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
