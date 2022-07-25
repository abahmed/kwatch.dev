import React from "react";
import CodeSnippet from "@theme/CodeSnippet";
import styles from "./styles.module.scss";

function Installation() {
  return (
        <section id="installation" className={styles.installation}>
          <div className="container">
            <div className="row">
              <div className="col col--10 col--offset-1">
                <div className={styles.headline}>
                  <span className={styles.category}>Installation</span>
                  <h4 className={styles.subtitle}>Get Configuration</h4>
                  <CodeSnippet
                    language="bash"
                    code="curl  -L https://raw.githubusercontent.com/abahmed/kwatch/v0.6.1/deploy/config.yaml -o config.yaml"
                  />
                  <h4 className={styles.subtitle}>Apply Configuration</h4>
                  <CodeSnippet
                    language="bash"
                    code="kubectl apply -f config.yaml"
                  />
                  <h4 className={styles.subtitle}>Deploy kwatch</h4>
                  <CodeSnippet
                    language="bash"
                    code="kubectl apply -f https://raw.githubusercontent.com/abahmed/kwatch/v0.6.1/deploy/deploy.yaml"
                  />
                </div>

              </div>
            </div>
          </div>
        </section>
      );
}

export default Installation;
