import React from "react";
import CodeSnippet from "@site/src/theme/CodeSnippet";

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
              <h2 className={styles.title}>60-second install</h2>
              <p className={styles.subtitle}>Pick your method — both take under a minute 🚀</p>

              <div className={styles.methodCard}>
                <div className={styles.methodBadge}>
                  <span className={styles.methodIcon}>🏆</span>
                  <span className={styles.methodLabel}>Easiest</span>
                </div>
                <h4 className={styles.methodTitle}>📦 Helm</h4>
                <CodeSnippet
                  language="bash"
                  code="helm repo add kwatch https://kwatch.dev/charts
helm install [RELEASE_NAME] kwatch/kwatch --namespace kwatch --create-namespace --version 0.11.0-rc.6"
                />
                <p className={styles.note}>
                  More details in the <a href="https://github.com/abahmed/kwatch/blob/main/deploy/chart/README.md">chart docs</a> 📖
                </p>
              </div>

              <div className={styles.methodCard}>
                <div className={styles.methodBadge}>
                  <span className={styles.methodIcon}>🐙</span>
                  <span className={styles.methodLabel}>Classic</span>
                </div>
                <h4 className={styles.methodTitle}>kubectl</h4>
                <div className={styles.steps}>
                  <div className={styles.step}>
                    <span className={styles.stepNum}>1</span>
                    <div className={styles.stepContent}>
                      <span className={styles.stepLabel}>Get config</span>
                      <CodeSnippet
                        language="bash"
                        code="curl -L https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/config.yaml -o config.yaml"
                      />
                    </div>
                  </div>
                  <div className={styles.step}>
                    <span className={styles.stepNum}>2</span>
                    <div className={styles.stepContent}>
                      <span className={styles.stepLabel}>Edit & apply</span>
                      <CodeSnippet
                        language="bash"
                        code="vim config.yaml  # ✏️ add your webhook
kubectl apply -f config.yaml"
                      />
                    </div>
                  </div>
                  <div className={styles.step}>
                    <span className={styles.stepNum}>3</span>
                    <div className={styles.stepContent}>
                      <span className={styles.stepLabel}>Deploy kwatch 🎉</span>
                      <CodeSnippet
                        language="bash"
                        code="kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.11.0-rc.6/deploy/deploy.yaml"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default Installation;
