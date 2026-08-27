import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';
import Header from "@site/src/theme/Header";
import Installation from "@site/src/theme/Installation";
import Features from "@site/src/theme/Features";

import styles from './index.module.css';
import ChannelIcon from '@site/src/theme/ChannelIcon';

export default function Home(): JSX.Element {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout
      description={`${siteConfig.customFields.description}`}>
      <Header />
      <main className={styles.main}>
        <Features />
        <Installation />
        <section className={styles.notPlatform}>
          <div className="container">
            <div className="row">
              <div className="col col--8 col--offset-2">
                <h2 className={styles.notPlatformTitle}>📖 Not a monitoring platform — and proud of it! 🎉</h2>
                <p>
                  kwatch is <strong>not</strong> a metrics collector, dashboard, or observability backend.
                  No TSDB, no dashboards, no log storage, no query language.
                  kwatch is the <strong>alarm</strong> — your existing tools are the archive.
                </p>
                <p>
                  Need full observability? Pair kwatch with Prometheus + Grafana for metrics,
                  or Loki for logs. kwatch handles the one thing a dashboard cannot: telling
                  you something broke <strong>right now</strong>. ⏰
                </p>
              </div>
            </div>
          </div>
        </section>
        <section className={styles.channels}>
          <div className="container">
            <div className="row">
              <div className="col col--10 col--offset-1">
                <h2 className={styles.channelsTitle}>
                  <span className={styles.channelsEmoji}>📨</span> Send alerts where you already work
                </h2>
                <p className={styles.channelsSubtitle}>
                  kwatch delivers crash alerts to your team's messaging platform — no extra tools needed
                </p>                <div className={styles.channelsGrid}>
                  {[
                    'Slack', 'Discord', 'Microsoft Teams', 'Telegram',
                    'PagerDuty', 'OpsGenie', 'Mattermost', 'RocketChat',
                    'Matrix', 'Google Chat', 'Feishu', 'Zenduty',
                    'Email', 'DingTalk', 'Webhook',
                  ].map((name, i) => (
                    <div key={i} className={styles.channelCard}>
                      <ChannelIcon name={name} />
                      <span className={styles.channelName}>{name}</span>
                    </div>
                  ))}
                </div>
                <p className={styles.channelsNote}>
                  … and <strong>41 more</strong> — GitLab, Gitea, Matrix, Splunk, SendGrid, AWS SNS/SES,
                  Twilio, PagerDuty &amp; Jira. <strong>56 providers</strong> supported in total.
                </p>
              </div>
            </div>
          </div>
        </section>
        <section className={styles.users}>
          <div className="container">
            <div className="row">
              <div className="col col--10 col--offset-1">
                <h3 className={styles.usersTitle}>🚀 Who uses kwatch?</h3>
                <p className={styles.usersSubtitle}>
                  Trusted by engineering teams around the world
                </p>
                <div className={styles.userLogos}>
                  <a href="https://www.trella.app" target="_blank" rel="noopener noreferrer" className={styles.userLogoLink}>
                    <img src="https://raw.githubusercontent.com/abahmed/kwatch/main/assets/users/trella.png" alt="Trella" className={styles.userLogo} />
                    <span className={styles.userLogoName}>Trella</span>
                  </a>
                  <a href="https://ibecsystems.com/en#/" target="_blank" rel="noopener noreferrer" className={styles.userLogoLink}>
                    <img src="https://raw.githubusercontent.com/abahmed/kwatch/main/assets/users/ibec-systems.svg" alt="IBEC Systems" className={styles.userLogo} />
                    <span className={styles.userLogoName}>IBEC Systems</span>
                  </a>
                  <a href="https://www.justwatch.com/us/talent" target="_blank" rel="noopener noreferrer" className={styles.userLogoLink}>
                    <img src="https://raw.githubusercontent.com/abahmed/kwatch/main/assets/users/justwatch.png" alt="JustWatch" className={styles.userLogo} />
                    <span className={styles.userLogoName}>JustWatch</span>
                  </a>
                </div>
                <p className={styles.usersNote}>
                  🏢 Want to add your company? <a href="https://github.com/abahmed/kwatch/issues">Open an issue!</a>
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
