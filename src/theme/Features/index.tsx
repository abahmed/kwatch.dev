import React from "react";
import clsx from "clsx";
import styles from "./styles.module.css";

const catchData = [
  { signal: "🟥 Pod crashes (CrashLoop, OOM, ImagePull, Error)", what: "Container state + last logs + events — tells you *why*", defaultOn: true },
  { signal: "⏳ Pending pods (stuck Unschedulable)", what: "Alerts after 300s stuck", defaultOn: true },
  { signal: "🖥️ Node issues (NotReady, Disk/Memory pressure)", what: "Per-condition severity", defaultOn: true },
  { signal: "💾 PVC running out of space", what: "Warn at 80%, critical at 90%", defaultOn: true },
  { signal: "❌ Failed Jobs & stuck CronJobs", what: "JobFailed / suspended / missed runs", defaultOn: true },
  { signal: "🚀 Stuck rollouts & StatefulSets", what: "ProgressDeadlineExceeded — deployment didn't finish", defaultOn: true },
  { signal: "📡 DaemonSet pods not running", what: "Unavailable pods detected", defaultOn: true },
  { signal: "📈 HPA stuck at max replicas", what: "After 20 minutes sustained", defaultOn: true },
  { signal: "📣 Cluster autoscaler can't scale", what: "FailedToScaleUp / NotTriggerScaleUp", defaultOn: true },
  { signal: "🔒 TLS certs expiring", what: "Enable if you want cert expiry warnings", defaultOn: false },
  { signal: "💓 Heartbeat (dead man's switch)", what: "Enable to page you if kwatch itself goes down", defaultOn: false },
];

function Features() {
  return (
    <>
      {/* ─── What is kwatch ─── */}
      <section id="what-is" className={styles.section}>
        <div className="container">
          <div className="row">
            <div className="col col--10 col--offset-1">
              <h2 className={styles.sectionTitle}>
                <span className={styles.titleEmoji}>🧐</span> What is kwatch?
              </h2>
              <p className={styles.lead}>
                kwatch is like a <strong>smart friend</strong> for your Kubernetes cluster:
              </p>
              <div className={styles.grid}>
                <div className={styles.gridCard}>
                  <div className={styles.gridIcon}>💥</div>
                  <div>
                    <strong>Something crashes</strong> → you get a message that says <em>why</em> (not just "pod is broken")
                  </div>
                </div>
                <div className={styles.gridCard}>
                  <div className={styles.gridIcon}>🔇</div>
                  <div>
                    <strong>Smart about noise</strong> — groups related problems and avoids repeating the same alert
                  </div>
                </div>
                <div className={styles.gridCard}>
                  <div className={styles.gridIcon}>🧠</div>
                  <div>
                    <strong>Explains itself</strong> — every alert says the cause, the impact, and what changed
                  </div>
                </div>
                <div className={styles.gridCard}>
                  <div className={styles.gridIcon}>⚡</div>
                  <div>
                    <strong>Works from one command</strong> — a few simple answers and a ready cluster
                  </div>
                </div>
              </div>
              <p className={styles.note}>
                <span className={styles.badge}>🚫 No Prometheus</span>
                <span className={styles.badge}>🚫 No Grafana</span>
                <span className={styles.badge}>🚫 No 50-step setup</span>
                <br />
                You can keep your existing monitoring tools. kwatch is the alarm
                that tells you what needs attention. 🎯
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─── Before vs After ─── */}
      <section id="before-after" className={styles.section}>
        <div className="container">
          <div className="row">
            <div className="col col--12">
              <h2 className={styles.sectionTitle}>
                <span className={styles.titleEmoji}>🚨</span> From confusing errors to clear next steps
              </h2>
              <div className={styles.baGrid}>
                <div className={styles.baBefore}>
                  <div className={styles.baBadge}>🤷 Before</div>
                  <div className={styles.baExample}>
                    <div className={styles.baCode}>CrashLoopBackOff</div>
                    <div className={styles.baDesc}>
                      <span className={styles.baArrow}>😰</span> Raw YAML output — good luck figuring it out
                    </div>
                  </div>
                  <div className={styles.baExample}>
                    <div className={styles.baCode}>Error</div>
                    <div className={styles.baDesc}>
                      <span className={styles.baArrow}>😰</span> Just "Error" — no context, no cause
                    </div>
                  </div>
                </div>

                <div className={styles.baVS}>
                  <span className={styles.baVSText}>⬌</span>
                  <span className={styles.baVSLabel}>kwatch</span>
                </div>

                <div className={styles.baAfter}>
                  <div className={styles.baBadgeAfter}>💡 After</div>
                  <div className={styles.baExampleAfter}>
                    <div className={styles.baCodeAfter}>
                      🚨 <strong>OOMKilled</strong>
                    </div>
                    <div className={styles.baDescAfter}>
                      <span className={styles.baArrowAfter}>💡</span> memory limit: 512Mi — try raising <code>limits.memory</code>
                    </div>
                    <div className={styles.baMeta}>
                      <span>📋 logs + events included</span>
                    </div>
                  </div>
                  <div className={styles.baExampleAfter}>
                    <div className={styles.baCodeAfter}>
                      🚨 <strong>Liveness probe failed</strong>
                    </div>
                    <div className={styles.baDescAfter}>
                      <span className={styles.baArrowAfter}>💡</span> <code>:8080/healthz</code> timed out — check the endpoint and startup timing
                    </div>
                    <div className={styles.baMeta}>
                      <span>🔧 points to the failing probe</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ─── What does it catch ─── */}
      <section id="monitors" className={clsx(styles.section, styles.altBg)}>
        <div className="container">
          <div className="row">
            <div className="col col--10 col--offset-1">
              <h2 className={styles.sectionTitle}>
                <span className={styles.titleEmoji}>🎯</span> What does it catch?
              </h2>
              <p className={styles.lead}>Most monitors are <strong>on by default</strong> — zero config needed:</p>
              <div className={styles.monitorGrid}>
                {catchData.map((row, i) => (
                  <div key={i} className={styles.monitorCard}>
                    <div className={styles.monitorHeader}>
                      <span
                        className={clsx(
                          styles.monitorCheck,
                          !row.defaultOn && styles.monitorOptional,
                        )}
                      >
                        {row.defaultOn ? "✅" : "○"}
                      </span>
                      <span className={styles.monitorSignal}>{row.signal}</span>
                    </div>
                    <p className={styles.monitorWhat}>{row.what}</p>
                  </div>
                ))}
              </div>
              <p className={styles.note}>
                ✨ <strong>TLS and heartbeat are opt-in</strong> — the core monitors
                work out of the box.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─── Alerts that explain themselves ─── */}
      <section id="insight" className={styles.section}>
        <div className="container">
          <div className="row">
            <div className="col col--10 col--offset-1">
              <h2 className={styles.sectionTitle}>
                <span className={styles.titleEmoji}>🧠</span> Alerts that explain themselves
              </h2>
              <p className={styles.lead}>
                kwatch ships with a <strong>diagnosis engine</strong> that runs inside your
                cluster, reads the logs and events, and tells you what's wrong and what to do next.
              </p>

              <div className={styles.aiHowItWorks}>
                <h3 className={styles.aiSubtitle}>How does the insight engine work?</h3>
                <div className={styles.aiSteps}>
                  <div className={styles.aiStep}>
                    <div className={styles.aiStepNumber}>1</div>
                    <div className={styles.aiStepContent}>
                      <strong>Something breaks</strong> — a pod crashes, a node goes down, a deployment gets stuck
                    </div>
                  </div>
                  <div className={styles.aiStep}>
                    <div className={styles.aiStepNumber}>2</div>
                    <div className={styles.aiStepContent}>
                      <strong>kwatch works out the root cause</strong> — it maps the pod to its node, owner,
                      services, PVCs and config, and reads the container logs, events, and crash reasons
                    </div>
                  </div>
                  <div className={styles.aiStep}>
                    <div className={styles.aiStepNumber}>3</div>
                    <div className={styles.aiStepContent}>
                      <strong>You get a plain-English fix</strong> — "OOMKilled — try raising memory limit"
                      instead of a cryptic error code
                    </div>
                  </div>
                </div>
              </div>

              <p className={styles.aiNotePrivacy}>
                🕳️ <strong>Knows when it was blind:</strong> kwatch stamps its own liveness, so if it was down
                while your cluster wasn't, the next startup message says how long nobody was watching.
              </p>

              <div className={styles.aiCard}>
                <div className={styles.aiCardHeader}>
                  <span className={styles.aiPulse} /> diagnosis configuration
                </div>
                <div className={styles.codeBlock}>
                  <pre>
                    <code>{`# Says *why* a crash happened — the root cause, impact, and what changed.
# Configuration is optional: the insight/dependency graph is on by default.`}</code>
                  </pre>
                </div>
              </div>
              <p className={styles.aiDescription}>
                When a crash happens, the diagnosis engine reads the logs and tells you the{" "}
                <strong>most likely cause</strong> and <strong>what to do next</strong>.
                Like having a senior SRE on-call with you. 🎯
              </p>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}

export default Features;
