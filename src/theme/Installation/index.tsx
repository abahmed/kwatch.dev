import React from "react";
import CodeSnippet from "@site/src/theme/CodeSnippet";
import Link from "@docusaurus/Link";

import styles from './styles.module.css';

function Installation() {
  return (
    <section id="installation" className={styles.installation}>
      <div className="container">
        <div className="row">
          <div className="col col--10 col--offset-1">
            <div className={styles.headline}>
              <span className={styles.category}>
                <span className={styles.lightning}>⚡</span> Installation
              </span>
              <h2 className={styles.title}>Start here: one command to install</h2>
              <p className={styles.subtitle}>
                One command is all you need to get started. No Helm or
                <code>kubectl apply</code> steps here 🚀
              </p>

              <div className={styles.methodCard}>
                <div className={styles.methodBadge}>
                  <span className={styles.methodIcon}>✨</span>
                  <span className={styles.methodLabel}>Recommended</span>
                </div>
                <h4 className={styles.methodTitle}>Interactive manager</h4>
                <CodeSnippet
                  language="bash"
                  code={'/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"'}
                />
                <p className={styles.note}>
                  Install, configure, upgrade, check, or uninstall kwatch from
                  one menu. The manager asks for your cluster and alert
                  destination, stores credentials in a Secret, and waits for
                  kwatch to become ready.
                </p>
              </div>

              <div className={styles.steps} aria-label="Installation steps">
                <div className={styles.step}>
                  <span className={styles.stepNum}>1</span>
                  <div className={styles.stepContent}>
                    <span className={styles.stepLabel}>Select your cluster</span>
                    <span>The manager never changes your kubectl context.</span>
                  </div>
                </div>
                <div className={styles.step}>
                  <span className={styles.stepNum}>2</span>
                  <div className={styles.stepContent}>
                    <span className={styles.stepLabel}>Choose your alert channel</span>
                    <span>Credentials are stored in a Kubernetes Secret.</span>
                  </div>
                </div>
                <div className={styles.step}>
                  <span className={styles.stepNum}>3</span>
                  <div className={styles.stepContent}>
                    <span className={styles.stepLabel}>Start watching</span>
                    <span>The manager verifies that kwatch is ready.</span>
                  </div>
                </div>
              </div>

              <p className={styles.previewNotice}>
                Need to inspect release artifacts or understand the supported
                lifecycle? Read the full{' '}
                <Link to="/docs/installation">installation guide</Link>.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default Installation;
