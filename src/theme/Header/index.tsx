import React, { useState, useEffect, useCallback } from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import useBaseUrl from "@docusaurus/useBaseUrl";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";

import styles from "./styles.module.css";

const floatingEmojis = ["💥", "🔇", "🧠", "⚡", "🎯", "🤖"];

const taglines = [
  "60 seconds to install.",
  "No backend. No dashboards.",
  "Alerts that explain themselves.",
  "No YAML spaghetti.",
  "Smart noise reduction.",
];

const terminalLines = [
  { text: '$ kubectl apply -f config.yaml', type: 'command' },
  { text: 'configmap/kwatch-config created', type: 'output' },
  { text: 'deployment.apps/kwatch created', type: 'output' },
  { text: '', type: 'spacer' },
  { text: '✓ kwatch is running', type: 'success' },
  { text: '  monitoring 8 namespaces', type: 'output' },
  { text: '  monitors active • 56 channels', type: 'output' },
  { text: '', type: 'spacer' },
  { text: '🚨 Crash detected: api-7d8f9c', type: 'error' },
  { text: '  → OOMKilled (exit code 137)', type: 'output' },
  { text: '  → root cause: memory limit', type: 'output' },
  { text: '  ✓ alert sent to Slack, Discord', type: 'success' },
  { text: '', type: 'spacer' },
];

const alertSamples = [
  {
    icon: "🚨",
    pod: "api-7d8f9c",
    namespace: "production",
    error: "OOMKilled",
    exitCode: 137,
    restarts: 3,
    age: "crashed 2m ago",
    summary: "Container used 290Mi of 256Mi limit",
    severity: "critical",
  },
  {
    icon: "⚠️",
    pod: "user-service-6b2a1e",
    namespace: "staging",
    error: "CrashLoopBackOff",
    exitCode: 1,
    restarts: 7,
    age: "crashed 5m ago",
    summary: "Missing DATABASE_URL environment variable",
    severity: "warning",
  },
  {
    icon: "🔧",
    pod: "nginx-ingress-4f3c2b",
    namespace: "production",
    error: "Liveness probe failed",
    exitCode: 0,
    restarts: 1,
    age: "unreachable 1m ago",
    summary: "HTTP GET :8080/healthz timed out (30s)",
    severity: "low",
  },
  {
    icon: "💾",
    pod: "postgres-statefulset-0",
    namespace: "data",
    error: "PVC 85% full",
    exitCode: 0,
    restarts: 0,
    age: "trending 10m",
    summary: "Volume using 85Gi of 100Gi, growing 2Gi/day",
    severity: "warning",
  },
];

const lineTimings = [0, 600, 1200, 1400, 1800, 2200, 2700, 2900, 3400, 3900, 4400, 4900, 5400, 5600];
const cycleDuration = 9000;

function TerminalDemo({ elapsed }: { elapsed: number }) {
  const revealed = terminalLines.filter((_, i) => lineTimings[i] <= elapsed).length;

  return (
    <div className={styles.terminal}>
      <div className={styles.terminalBar}>
        <span className={styles.terminalDot} style={{ background: '#ef4444' }} />
        <span className={styles.terminalDot} style={{ background: '#eab308' }} />
        <span className={styles.terminalDot} style={{ background: '#22c55e' }} />
        <span className={styles.terminalLabel}>terminal</span>
      </div>
      <div className={styles.terminalBody}>
        {terminalLines.slice(0, revealed).map((line, i) => (
          <div key={i} className={clsx(
            styles.terminalLine,
            line.type === 'command' && styles.terminalCommand,
            line.type === 'success' && styles.terminalSuccess,
            line.type === 'error' && styles.terminalError,
          )}>
            {line.type === 'command' && <span className={styles.terminalPrompt}>$ </span>}
            {line.text}
          </div>
        ))}
        {revealed < terminalLines.length && <span className={styles.terminalCursor} />}
      </div>
    </div>
  );
}

const severityColors: Record<string, string> = {
  critical: '#dc2626',
  warning: '#d97706',
  low: '#2563eb',
};

const severityBg: Record<string, string> = {
  critical: '#fef2f2',
  warning: '#fffbeb',
  low: '#eff6ff',
};

function SlackChat({ elapsed }: { elapsed: number }) {
  const cycleIndex = Math.floor(elapsed / cycleDuration);
  const alert = alertSamples[cycleIndex % alertSamples.length];
  const t = elapsed % cycleDuration;

  const phase = t < 2200 ? 'idle'
    : t < 3400 ? 'online'
    : t < 4400 ? 'typing'
    : t < 5600 ? 'alert'
    : 'done';

  return (
    <div className={styles.slackCard}>
      <div className={styles.slackHeader}>
        <span className={styles.slackHeaderTitle}>kwatch-bot</span>
        <span className={styles.slackHeaderMeta}>
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>
          </svg>
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <path d="M18 6L6 18M6 6l12 12"/>
          </svg>
        </span>
      </div>
      <div className={styles.slackBody}>
        <div className={styles.slackChannel}>
          <span className={styles.slackChannelHash}>#</span> kwatch-alerts
        </div>

        <div className={styles.slackMessages}>
          {phase !== 'idle' && (
            <div className={clsx(styles.slackMessage, styles.slackSystemMsg)}>
              <span className={styles.slackSystemDot} />
              <span>kwatch-bot joined #kwatch-alerts</span>
            </div>
          )}

          {(phase === 'typing' || phase === 'alert' || phase === 'done') && (
            <div className={styles.slackTyping}>
              <svg viewBox="0 0 24 24" width="16" height="16" className={styles.slackTypingAvatar} aria-hidden="true">
                <rect width="24" height="24" rx="4" fill="#4A154B"/>
                <circle cx="12" cy="10" r="4" fill="white"/>
                <path d="M6 20c0-3.3 2.7-6 6-6s6 2.7 6 6" fill="none" stroke="white" strokeWidth="1.5"/>
              </svg>
              <div className={styles.slackTypingDots}>
                <span className={styles.slackDot} />
                <span className={styles.slackDot} />
                <span className={styles.slackDot} />
              </div>
            </div>
          )}

          {(phase === 'alert' || phase === 'done') && (
            <div className={styles.slackMsg}>
              <div className={styles.slackMsgAvatar}>
                <svg viewBox="0 0 24 24" width="36" height="36" aria-hidden="true">
                  <rect width="24" height="24" rx="6" fill="url(#kg)"/>
                  <rect x="6" y="6" width="12" height="12" rx="2" fill="none" stroke="white" strokeWidth="1.5"/>
                  <path d="M9 12l2 2 4-4" fill="none" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                  <defs>
                    <linearGradient id="kg" x1="0" y1="0" x2="24" y2="24">
                      <stop offset="0%" stopColor="#0ea5e9"/>
                      <stop offset="100%" stopColor="#8b5cf6"/>
                    </linearGradient>
                  </defs>
                </svg>
              </div>
              <div className={styles.slackMsgContent}>
                <div className={styles.slackMsgHeader}>
                  <span className={styles.slackMsgApp}>kwatch</span>
                  <span className={styles.slackMsgBadge}>APP</span>
                  <span className={styles.slackMsgTime}>2:41 PM</span>
                </div>

                <div className={styles.slackMsgBody} style={phase === 'alert' ? { borderColor: severityColors[alert.severity], borderLeftWidth: 4 } : {}}>
                  <div className={styles.slackAlertSeverity} style={{ background: severityColors[alert.severity] }}>
                    {alert.severity === 'low' ? 'info' : alert.severity}
                  </div>

                  <div className={styles.slackErrorLine}>
                    <span className={styles.slackAlertIcon}>{alert.icon}</span>
                    <span className={styles.slackAlertError}>{alert.error}</span>
                    {alert.exitCode > 0 && <span className={styles.slackExitCode}>exit {alert.exitCode}</span>}
                  </div>

                  <div className={styles.slackPodLine}>
                    <span className={styles.slackAlertPod}>{alert.pod}</span>
                    {alert.restarts > 0 && <span className={styles.slackRestarts}>{alert.restarts} restarts</span>}
                  </div>

                  <div className={styles.slackDivider} />

                  <div className={styles.slackAiSection}>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#8b5cf6" strokeWidth="2" aria-hidden="true">
                      <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
                    </svg>
                    <span className={styles.slackAiLabel}>Root cause</span>
                    <span className={styles.slackAiSummary}>{alert.summary}</span>
                  </div>

                  <div className={styles.slackFooterRow}>
                    <span className={styles.slackAlertNamespace}>
                      <svg viewBox="0 0 24 24" width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                        <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
                        <circle cx="12" cy="10" r="3"/>
                      </svg>
                      {alert.namespace}
                    </span>
                    <span className={styles.slackAlertAge}>{alert.age}</span>
                  </div>
                </div>

                <div className={styles.slackMsgFooter}>
                  <span className={styles.slackMsgActions}>
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
                    </svg>
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                      <circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>
                    </svg>
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                      <polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/>
                    </svg>
                  </span>
                  <span className={styles.slackMsgSent}>
                    {phase === 'done' && <><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#16a34a" strokeWidth="2" aria-hidden="true"><path d="M20 6L9 17l-5-5"/></svg> Sent via kwatch</>}
                  </span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function Header() {
  const {siteConfig} = useDocusaurusContext();
  const [taglineIndex, setTaglineIndex] = useState(0);
  const [taglineVisible, setTaglineVisible] = useState(true);
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setElapsed((e) => (e + 80) % cycleDuration);
    }, 80);
    return () => clearInterval(timer);
  }, []);

  const advanceTagline = useCallback(() => {
    setTaglineVisible(false);
    setTimeout(() => {
      setTaglineIndex((i) => (i + 1) % taglines.length);
      setTaglineVisible(true);
    }, 400);
  }, []);

  useEffect(() => {
    const timer = setInterval(advanceTagline, 3500);
    return () => clearInterval(timer);
  }, [advanceTagline]);

  return (
    <header id="hero" className={clsx("hero", styles.banner)}>
      <div className={styles.glowOrb1} />
      <div className={styles.glowOrb2} />
      <div className={styles.glowOrb3} />
      <div className={styles.gridBg} />

      {floatingEmojis.map((emoji, i) => (
        <span
          key={i}
          className={styles.floatingEmoji}
          style={{
            left: `${10 + (i * 16)}%`,
            animationDelay: `${i * 0.4}s`,
            animationDuration: `${3 + (i % 3)}s`,
            fontSize: `${1.5 + (i % 3) * 0.4}rem`,
          }}
        >
          {emoji}
        </span>
      ))}

      <div className={styles.demoPanel}>
        <TerminalDemo elapsed={elapsed} />
        <div className={styles.demoConnector} />
        <SlackChat elapsed={elapsed} />
      </div>

      <div className="container">
        <div className={styles.heroCenter}>
          <img src={useBaseUrl("img/kwatch-logo.svg")} className={styles.heroLogo} alt="kwatch" />
          <p className={clsx("hero__subtitle", styles.subtitle)}>
            Crash. <span className={styles.highlight}>Root cause. Next step.</span>
          </p>
          <p className={styles.description}>
            kwatch watches your Kubernetes cluster 24/7.
            Every crash comes with the root cause and fix —{" "}
            <span className={styles.shimmerText}>straight to your team chat</span>.
          </p>
          <p className={styles.tagline}>
            <span className={styles.sparkle}>✨</span>{' '}
            <span className={clsx(styles.cyclingTagline, taglineVisible ? styles.cyclingIn : styles.cyclingOut)}>
              {taglines[taglineIndex]}
            </span>
          </p>

          <div className={styles.buttons}>
            <Link
              className={clsx(
                "button button--primary button--lg",
                styles.getStarted
              )}
              to={useBaseUrl("docs/installation")}
            >
              🚀 Get Started
            </Link>
            <Link
              className={clsx(
                "button button--outline button--lg",
                styles.githubButton
              )}
              to="https://github.com/abahmed/kwatch"
            >
              <svg viewBox="0 0 24 24" width="18" height="18" style={{ marginRight: '0.4rem', verticalAlign: 'middle', fill: 'currentColor' }} aria-hidden="true">
                <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/>
              </svg> View on GitHub
            </Link>
          </div>
          <div className={clsx(styles.buttons, styles.githubStars)}>
            <iframe
              className={styles.githubStarsButton}
              src="https://ghbtns.com/github-btn.html?user=abahmed&amp;repo=kwatch&amp;type=star&amp;count=true&amp;size=large"
              width={160}
              height={30}
              title="GitHub Stars"
            />
          </div>
        </div>
      </div>
    </header>
  );
}

export default Header;
