import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Header from "@site/src/theme/Header";
import Installation from "@site/src/theme/Installation";
import Features from "@site/src/theme/Features";
import Waitlist from "@site/src/theme/Waitlist";

import styles from './index.module.css';

export default function Home(): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      description={`${siteConfig.customFields.description}`}>
      <Header />
      <main className={styles.main}>
        <Features />
        <Waitlist />
        <Installation />
      </main>
    </Layout>
  );
}
