import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

type Example = {
  edition: 'Community' | 'Pro';
  title: string;
  note: string;
  lines: string[];
};

// Messages come from the kwatch README.
const examples: Example[] = [
  {
    edition: 'Pro',
    title: 'A bad release, in one message',
    note: 'Twenty crash-loop and readiness alerts become one incident that names the release, who shipped it, what else is hit and the fix.',
    lines: [
      '🔴 api is down in shop (prod-eu-1)',
      "after the 14:02 release of api:2.3. alice",
      'released it; the previous image was',
      'api:2.2. Only pods of the new',
      'revision fail. Service api and',
      "ingress storefront can't serve traffic.",
      'checkout is affected as well. Rolling',
      'back fixes it (changes the cluster):',
      'kubectl rollout undo deployment/api',
      '-n shop --to-revision=13',
    ],
  },
  {
    edition: 'Pro',
    title: 'A database outside the cluster',
    note: 'When five apps fail because the database is down, kwatch blames the database, not the apps.',
    lines: [
      '🟠 api in shop (prod-eu-1) keeps crashing',
      'because external endpoint',
      'db.example.com:5432 refuses connections.',
      'It fails with "dial tcp',
      'db.example.com:5432: connect: connection',
      'refused". Every error mentions it.',
      'cart, search, auth and one other are',
      'affected as well. To read the output of',
      'the last crash, run',
      'kubectl logs api-6d4f-0 -c app -n shop --previous',
    ],
  },
  {
    edition: 'Community',
    title: 'A lost node',
    note: 'Community names the failure and the command to check it.',
    lines: [
      '🔴 Node n1 (prod-eu-1) has not reported',
      'for about two minutes. It reports',
      '"Kubelet stopped posting node status".',
      "To check the node's conditions and",
      'recent events, run',
      'kubectl describe node n1',
    ],
  },
];

export default function AlertShowcase(): ReactElement {
  return (
    <section className={styles.section} id="alerts">
      <div className="container">
        <div className={styles.heading}>
          <p className={styles.eyebrow}>What you receive</p>
          <h2>One message with the cause, not twenty alerts.</h2>
          <p>
            Real messages, written for people. One emoji tells you how urgent
            it is: 🔴 page · 🟠 notify · 🟡 low · ✅ resolved.
          </p>
        </div>
        <div className={styles.grid}>
          {examples.map((ex) => (
            <figure className={styles.card} key={ex.title}>
              <figcaption className={styles.cardHead}>
                <strong>{ex.title}</strong>
                <span
                  className={`${styles.edition} ${
                    ex.edition === 'Pro' ? styles.pro : ''
                  }`}>
                  {ex.edition}
                </span>
              </figcaption>
              <pre className={styles.message} tabIndex={0}>
                {ex.lines.join('\n')}
              </pre>
              <p className={styles.note}>{ex.note}</p>
            </figure>
          ))}
        </div>
        <p className={styles.resolved}>
          When it is fixed you hear about it once:{' '}
          <code>✅ api in shop (prod-eu-1) is healthy again. It was down for eight minutes.</code>
        </p>
        <div className={styles.more}>
          <Link to="/docs/getting-started">
            See how alerts are built <span aria-hidden="true">→</span>
          </Link>
        </div>
      </div>
    </section>
  );
}
