import React from "react";
import clsx from "clsx";

import styles from "./styles.module.scss";

const data = [
  {
    title: <>What is kwatch?</>,
    description: (
      <>
        kwatch helps you monitor all changes in your Kubernetes(K8s) cluster,
        detects crashes in your running apps in realtime,
        and publishes notifications to your favourite channels (Slack, Discord, etc.) instantly
      </>
    ),
  },
  {
    title: <>How do I use it?</>,
    description: (
      <>
        You can deploy kwatch easily on your cluster with one command
      </>
    ),
  },
];

function Feature({ title, description }) {
  return (
    <div className={clsx("col col--6", styles.feature)}>
      <div className="item">
        <div className={styles.header}>
          <h2 className={styles.title}>{title}</h2>
        </div>
        <p>{description}</p>
      </div>
    </div>
  );
}

function Features() {
  return (
    <>
      {data && data.length && (
        <section id="features" className={styles.features}>
          <div className="container">
            <div className="row">
              <div className="col col--11 col--offset-1">
                <div className="row">
                  {data.map((props, idx) => (
                    <Feature key={idx} {...props} />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>
      )}
    </>
  );
}

export default Features;
