import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

export default function FinalCta(): ReactElement {
  return (
    <section className={styles.section} aria-labelledby="final-cta-title">
      <div className="container">
        <h2 id="final-cta-title">Know what to do next, in about five minutes.</h2>
        <p>
          Run one command, pick a channel, and the next time something breaks
          you get the cause and the fix.
        </p>
        <div className={styles.actions}>
          <Link className="button button--primary button--lg" to="/docs/installation">
            Install with kwatch.sh <span aria-hidden="true">→</span>
          </Link>
          <Link className="button button--outline button--primary button--lg" to="/signup">
            Get Pro free (early access)
          </Link>
        </div>
      </div>
    </section>
  );
}
