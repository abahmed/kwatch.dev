import React from 'react';
import Layout from '@theme/Layout';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from "./index.module.scss";
import Header from "@theme/Header";
import Features from "@theme/Features";
import Installation from "@theme/Installation";


export default function Home() {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout description={siteConfig.customFields.description}>
      <Header />

      <main className={styles.main}>
          <Features />
          <Installation />
        </main>
    </Layout>
  );
}
