import type { ReactElement } from 'react';
import Layout from '@theme/Layout';
import Header from "@site/src/theme/Header";
import Installation from "@site/src/theme/Installation";
import Features from "@site/src/theme/Features";

import styles from './index.module.css';
import ChannelIcon from '@site/src/theme/ChannelIcon';

export default function Home(): ReactElement {
  return (
    <Layout
      title="Kubernetes incident monitoring and alerting"
      description="See what broke. Understand why. Know what to do next. Open-source Kubernetes incident monitoring and alerting.">
      <Header />
      <main className={styles.main}>
        <Installation />
        <section className={styles.signalStrip} aria-label="kwatch at a glance">
          <div className="container">
            <div className={styles.signalGrid}>
              <div className={styles.signalItem}>
                <span className={styles.signalValue}>🏠</span>
                <span>
                  <strong>Runs in your cluster</strong>
                  <small>No hosted backend or metrics database</small>
                </span>
              </div>
              <div className={styles.signalItem}>
                <span className={styles.signalValue}>⚡</span>
                <span>
                  <strong>One guided command</strong>
                  <small>Install, configure, upgrade, and recover</small>
                </span>
              </div>
              <div className={styles.signalItem}>
                <span className={styles.signalValue}>📣</span>
                <span>
                  <strong>56 notification providers</strong>
                  <small>Send one clear incident to every team</small>
                </span>
              </div>
            </div>
          </div>
        </section>
        <Features />
        <section className={styles.notPlatform}>
          <div className="container">
            <div className="row">
              <div className="col col--8 col--offset-2">
                <h2 className={styles.notPlatformTitle}>🧭 An alert, not a dashboard</h2>
                <p>
                  kwatch does one job really well: it tells you when something
                  breaks and explains what to do next. It does not collect
                  metrics, store logs, or build dashboards.
                </p>
                <p>
                  Already use Prometheus, Grafana, or Loki? Keep them. kwatch
                  works alongside them as the <strong>alarm</strong> that tells
                  you something needs attention <strong>right now</strong>. ⏰
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
                  <span className={styles.channelsEmoji}>📨</span> Get alerts where you already work
                </h2>
                <p className={styles.channelsSubtitle}>
                  kwatch delivers clear incident alerts to your team's
                  messaging platform — no extra tools needed
                </p>
                <div className={styles.channelsGrid} aria-label="Supported notification channels">
                  {[
                    'Slack', 'Discord', 'Microsoft Teams', 'Telegram',
                    'PagerDuty', 'OpsGenie', 'Mattermost', 'RocketChat',
                    'Matrix', 'Google Chat', 'Feishu', 'Zenduty',
                    'Email', 'DingTalk', 'Webhook',
                  ].map((name) => (
                    <div key={name} className={styles.channelCard}>
                      <ChannelIcon name={name} />
                      <span className={styles.channelName}>{name}</span>
                    </div>
                  ))}
                </div>
                <p className={styles.channelsNote}>
                  … and <strong>41 more</strong> — GitLab, Gitea, Splunk,
                  SendGrid, AWS SNS/SES, Twilio &amp; Jira. <strong>56 providers</strong>
                  supported in total.
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
                    <img src="https://raw.githubusercontent.com/abahmed/kwatch/main/assets/users/trella.png" alt="Trella" className={styles.userLogo} loading="lazy" decoding="async" />
                    <span className={styles.userLogoName}>Trella</span>
                  </a>
                  <a href="https://ibecsystems.com/en#/" target="_blank" rel="noopener noreferrer" className={styles.userLogoLink}>
                    <img src="https://raw.githubusercontent.com/abahmed/kwatch/main/assets/users/ibec-systems.svg" alt="IBEC Systems" className={styles.userLogo} loading="lazy" decoding="async" />
                    <span className={styles.userLogoName}>IBEC Systems</span>
                  </a>
                  <a href="https://www.justwatch.com/us/talent" target="_blank" rel="noopener noreferrer" className={styles.userLogoLink}>
                    <img src="https://raw.githubusercontent.com/abahmed/kwatch/main/assets/users/justwatch.png" alt="JustWatch" className={styles.userLogo} loading="lazy" decoding="async" />
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
