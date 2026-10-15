import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

const faqs: {q: string; a: ReactElement | string}[] = [
  {
    q: 'Is kwatch open source?',
    a: 'kwatch is source available under the Elastic License 2.0. You can run it for free in your own clusters, read and change the code, and share it. You may not offer it as a hosted service. Releases up to v1.0.0-rc.10 are MIT.',
  },
  {
    q: 'What does Community include?',
    a: 'Pod crash, OOM and Pending detection, node NotReady, a root-cause headline, basic dedup, namespace filters and silences, and one alert provider. It is free forever and needs no account.',
  },
  {
    q: 'Is Pro really free?',
    a: 'During early access, yes. Each license runs 3 months and may be renewed, for up to 2 clusters per account (per company domain for work emails). We ask for no payment details. When a license ends, kwatch falls back to Community and alerting never stops.',
  },
  {
    q: 'What leaves my cluster?',
    a: 'Alerts, to the providers you configure. With a Pro key kwatch also renews its license by sending a hashed cluster id, its version and the node count. A Community install without a key makes no license calls.',
  },
  {
    q: 'How do I install it?',
    a: (
      <>
        Run the <code>kwatch.sh</code> installer. It asks which cluster and
        channel to use, stores credentials in a Kubernetes Secret and checks the
        install. See the <Link to="/docs/installation">installation guide</Link>.
      </>
    ),
  },
];

export default function HomeFaq(): ReactElement {
  return (
    <section className={styles.section} id="faq">
      <div className="container">
        <div className={styles.inner}>
          <h2>Questions, answered</h2>
          {faqs.map((f) => (
            <details key={f.q}>
              <summary>{f.q}</summary>
              <p>{f.a}</p>
            </details>
          ))}
          <p className={styles.more}>
            More in the <Link to="/pricing">editions page</Link> and the{' '}
            <Link to="/docs/license">license docs</Link>.
          </p>
        </div>
      </div>
    </section>
  );
}
