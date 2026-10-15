import type {ReactElement} from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import tiers from '../data/feature-tiers.json';

import styles from './pricing.module.css';
import portal from './portal.module.css';

type Cell = string | boolean;
type Row = {label: string; community: Cell; pro: Cell};
type Feature = {id: string; description: string; tier: string};

const groups: {prefix: string; title: string; extra: Row[]}[] = [
  {prefix: 'core', title: 'Detection', extra: []},
  {
    prefix: 'analysis',
    title: 'Analysis',
    extra: [
      {
        label: 'Root cause: headline vs full proof and who changed what',
        community: 'Headline',
        pro: 'Full proof + who changed what',
      },
    ],
  },
  {
    prefix: 'incidents',
    title: 'Incidents',
    extra: [{label: 'Incident history', community: '—', pro: '90 days'}],
  },
  {prefix: 'policy', title: 'Policy', extra: []},
  {
    prefix: 'delivery',
    title: 'Delivery',
    extra: [{label: 'Alert providers', community: '1', pro: 'Unlimited'}],
  },
  {prefix: 'security', title: 'Security', extra: []},
];

const platformRows: Row[] = [
  {label: '/status JSON API', community: false, pro: true},
  {label: 'HA (multiple replicas)', community: false, pro: true},
  {label: 'Flight recorder & replay export', community: false, pro: true},
];

const faqs: {q: string; a: ReactElement | string}[] = [
  {
    q: 'How does the free trial work?',
    a: 'Every account gets a 90-day free trial for up to 2 clusters, no credit card needed. Each trial runs 90 days from the day you start it. With a work email the limit is 2 clusters per company domain, shared by everyone using that domain.',
  },
  {
    q: 'What happens when my trial expires?',
    a: 'kwatch falls back to Community. Detection and alerting never stop, you simply lose the Pro features. Your cluster keeps running with no downtime and no data loss.',
  },
  {
    q: 'Does kwatch work offline?',
    a: 'Yes. A licensed kwatch renews in the background and keeps working for up to 7 days if it cannot reach the license service, for example in an air-gapped or firewalled cluster.',
  },
  {
    q: 'What does one license cover?',
    a: (
      <>
        One license covers one cluster. Moving to a new cluster is self-serve: use{' '}
        <Link to="/account">Transfer to another cluster</Link> on your account page.
      </>
    ),
  },
  {
    q: 'What does the license check send?',
    a: 'A hashed cluster id, the kwatch version and the node count. No workload names, logs, secrets or cluster contents. See the privacy policy for details.',
  },
  {
    q: 'Do I need an account for Community?',
    a: 'No. Community is free forever, needs no account, no key and no sign-up. Install it and go.',
  },
];

function render(cell: Cell): ReactElement {
  if (cell === true) return <span className={styles.yes} aria-label="Included">{'✓'}</span>;
  if (cell === false) return <span className={styles.no} aria-label="Not included">{'—'}</span>;
  return <>{cell}</>;
}

export default function Pricing(): ReactElement {
  const features = tiers as Feature[];
  return (
    <Layout
      title="Pricing"
      description="kwatch Community is free forever. kwatch Pro is $29 per cluster per month with a 90-day free trial for up to 2 clusters (per company domain for work emails) and no credit card."
    >
      <main>
        <div className={portal.page}>
          <div className="container">
            <div style={{textAlign: 'center', marginBottom: '2rem'}}>
              <p className={portal.eyebrow}>Pricing</p>
              <h1>Free to run. Pro when you need the proof.</h1>
              <p className={portal.muted}>
                Detection and alerting are free forever. Pro adds the depth for production teams.
              </p>
            </div>

            <div className={styles.plans}>
              <section className={styles.plan} aria-labelledby="plan-community">
                <h2 id="plan-community">Community</h2>
                <p className={portal.muted}>For any cluster, forever.</p>
                <p className={styles.price}>Free <small>forever</small></p>
                <ul className={styles.planList}>
                  <li>Core pod, node and RBAC detection</li>
                  <li>Root-cause headline on every incident</li>
                  <li>Noise control and scope filters</li>
                  <li>One alert provider</li>
                  <li>No account, no key</li>
                </ul>
                <Link className="button button--secondary button--lg" to="/docs/installation">
                  Install kwatch
                </Link>
              </section>

              <section className={`${styles.plan} ${styles.featured}`} aria-labelledby="plan-pro">
                <h2 id="plan-pro">Pro</h2>
                <p className={portal.muted}>For production clusters.</p>
                <p className={styles.price}>$29 <small>per cluster / month</small></p>
                <p className={portal.muted} style={{margin: 0}}>or $290 per cluster / year</p>
                <ul className={styles.planList}>
                  <li>Everything in Community</li>
                  <li>Workloads, storage, network, control plane and more</li>
                  <li>Full root-cause proof and who changed what</li>
                  <li>Unlimited alert providers, routing and threads</li>
                  <li>90-day incident history, HA and flight recorder</li>
                </ul>
                <Link className="button button--primary button--lg" to="/signup">
                  90-day free trial, no credit card
                </Link>
                <p className={styles.note}>
                  Free trial for up to 2 clusters (per company domain for work emails).
                </p>
                <p className={styles.note}>Licensed per cluster under ELv2.</p>
              </section>
            </div>

            <div className={styles.tableWrap}>
              <table className={styles.table}>
                <caption className="sr-only" style={{captionSide: 'top', textAlign: 'left', fontWeight: 700, paddingBottom: '0.5rem'}}>
                  Feature comparison
                </caption>
                <thead>
                  <tr>
                    <th scope="col">Feature</th>
                    <th scope="col" className={styles.center}>Community</th>
                    <th scope="col" className={styles.center}>Pro</th>
                  </tr>
                </thead>
                <tbody>
                  {groups.map((g) => {
                    const rows: Row[] = [
                      ...features
                        .filter((f) => f.id.split('.')[0] === g.prefix)
                        .map((f) => ({
                          label: f.description,
                          community: f.tier === 'community',
                          pro: true,
                        })),
                      ...g.extra,
                    ];
                    return [
                      <tr key={`${g.prefix}-h`} className={styles.group}>
                        <th colSpan={3} scope="colgroup">{g.title}</th>
                      </tr>,
                      ...rows.map((r) => (
                        <tr key={`${g.prefix}-${r.label}`}>
                          <td>{r.label}</td>
                          <td className={styles.center}>{render(r.community)}</td>
                          <td className={styles.center}>{render(r.pro)}</td>
                        </tr>
                      )),
                    ];
                  })}
                  <tr className={styles.group}>
                    <th colSpan={3} scope="colgroup">Platform</th>
                  </tr>
                  {platformRows.map((r) => (
                    <tr key={r.label}>
                      <td>{r.label}</td>
                      <td className={styles.center}>{render(r.community)}</td>
                      <td className={styles.center}>{render(r.pro)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className={styles.faq}>
              <h2>Frequently asked questions</h2>
              {faqs.map((f) => (
                <details key={f.q}>
                  <summary>{f.q}</summary>
                  <p>{f.a}</p>
                </details>
              ))}
              <p className={portal.muted} style={{marginTop: '1.5rem'}}>
                More in the <Link to="/docs/editions">editions</Link> and{' '}
                <Link to="/docs/license">license</Link> docs.
              </p>
            </div>
          </div>
        </div>
      </main>
    </Layout>
  );
}
