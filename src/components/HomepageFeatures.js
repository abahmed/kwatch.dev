import React from 'react';
import clsx from 'clsx';
import styles from './HomepageFeatures.module.css';

const FeatureList = [
  {
    title: 'What is kwatch?',
    description: (
      <>
        kwatch helps you monitor all changes in your Kubernetes(K8s) cluster,
        detects crashes in your running apps in realtime,
        and publishes notifications to your favourite channels (Slack, Discord, etc.) instantly
      </>
    ),
  },
  {
    title: 'How do I use it?',
    description: (
      <>
        You can deploy kwatch easily on your cluster with one command
      </>
    ),
  },
];

function Feature({Svg, title, description}) {
  return (
    <div className={clsx('col col--6')}>
      <div className="text--center padding-horiz--md">
        <h3>{title}</h3>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
