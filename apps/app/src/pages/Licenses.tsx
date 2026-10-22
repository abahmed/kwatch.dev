import {useCallback, useEffect, useState} from 'react';
import type {ReactNode} from 'react';
import {getFreeLicense, displayKey, moveLicense, replaceKey, revealKey} from '../api';
import type {Cluster, License} from '../api';
import {Dialog, usePageTitle} from '../components';
import {isOutdated, fmtLastSeenAgo, fmtDate, fmtRefreshed, fmtUtcFull, plural} from '../format';
import {errorMessage, LimitNotice} from '../messages';
import {useSession} from '../session';
import {useClusters} from '../useClusters';
import {DOCS_URL} from '../config';


const INSTALLER = '/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"';

function LastSeen({unix, skewMs}: {unix: number; skewMs: number}) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(id);
  }, []);
  return <span title={fmtUtcFull(unix)}>{fmtLastSeenAgo(unix, now + skewMs)}</span>;
}

function statusOf(l: License): {label: string; tone: 'ok' | 'warn' | 'bad'} {
  if (l.status === 'active') return {label: 'active', tone: 'ok'};
  if (l.status === 'suspended') return {label: l.status, tone: 'warn'};
  return {label: l.status, tone: 'bad'};
}

type ClusterState = {cluster?: Cluster; skewMs: number; latest: string | null; loading: boolean; failed: boolean; retry: () => void};

function ClusterHalf({license, cs}: {license: License; cs: ClusterState}) {
  const {cluster: c} = cs;
  const label = `Cluster for license ${license.lid}`;
  const ended = license.status === 'expired' ? (
    <p className="small cluster-ended">
      This license ended on {fmtDate(license.expires_at)}. kwatch is on Community; alerts still work.
    </p>
  ) : null;
  let body: ReactNode;
  if (cs.failed) {
    body = (
      <div className="cluster-unavailable">
        <p className="small">Cluster status unavailable. Try again.</p>
        <button type="button" className="btn-action" onClick={cs.retry}>Try again</button>
      </div>
    );
  } else if (cs.loading) {
    body = <div className="skeleton" aria-busy="true" aria-label="Loading cluster" />;
  } else if (c) {
    body = (
      <dl className="cluster-grid">
        <div>
          <dt className="mono cluster-label">Cluster</dt>
          <dd className="mono cluster-id">{c.id_short}</dd>
        </div>
        <div>
          <dt className="mono cluster-label">Last update</dt>
          <dd className="cluster-last">
            <LastSeen unix={c.last_seen} skewMs={cs.skewMs} />
          </dd>
        </div>
        <div>
          <dt className="mono cluster-label">Version</dt>
          <dd className="cluster-version-col">
            <span className="mono cluster-version">{c.version ? `v${c.version.replace(/^v/, '')}` : ''}</span>
            {cs.latest && isOutdated(c.version, cs.latest) && (
              <a className="small update-available" href={`${DOCS_URL}/update`}>
                Update available: v{cs.latest.replace(/^v/, '')}
              </a>
            )}
          </dd>
        </div>
        <div>
          <dt className="mono cluster-label">Nodes</dt>
          <dd className="cluster-nodes">{c.nodes != null ? plural(c.nodes, 'node', 'nodes') : ''}</dd>
        </div>
      </dl>
    );
  } else if (license.status === 'active') {
    body = (
      <p className="small muted">
        Not attached yet. Add the key in the installer: License / Pro &gt; Add or replace key. It appears here after
        the cluster&rsquo;s first license check.
      </p>
    );
  } else {
    body = null;
  }
  if (!body && !ended) return null;
  return (
    <div className="license-cluster" role="group" aria-label={label}>
      {!c && <p className="mono cluster-label">Cluster</p>}
      {ended}
      {body}
    </div>
  );
}

function LicenseCard({
  license,
  cs,
  onChange,
  initialKey = null,
}: {
  license: License;
  cs: ClusterState;
  onChange: () => Promise<void>;
  initialKey?: string | null;
}) {
  // The full key lives only here while shown. Hide and unmount drop it.
  const [fullKey, setFullKey] = useState<string | null>(initialKey);
  const shownKey = fullKey ?? displayKey(license);
  const revealed = fullKey !== null;
  const [copied, setCopied] = useState(false);
  const [dialog, setDialog] = useState<null | 'move' | 'replace'>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<ReactNode>('');
  const [message, setMessage] = useState('');

  const st = statusOf(license);
  const a = cs.cluster;

  async function show() {
    if (revealed) {
      setFullKey(null);
      return;
    }
    setError('');
    setBusy(true);
    try {
      setFullKey((await revealKey(license.lid)).key);
    } catch (err) {
      setError(errorMessage(err, 'Could not load the key. Please try again.'));
    } finally {
      setBusy(false);
    }
  }

  async function copy() {
    setError('');
    let key = fullKey;
    if (key === null) {
      try {
        key = (await revealKey(license.lid)).key;
      } catch (err) {
        setError(errorMessage(err, 'Could not load the key. Please try again.'));
        return;
      }
    }
    try {
      await navigator.clipboard.writeText(key);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      setError('Copy failed. Show the key and copy it manually.');
    }
  }

  async function run(action: () => Promise<void>, fallback: string) {
    setBusy(true);
    setError('');
    setMessage('');
    try {
      await action();
      await onChange();
    } catch (err) {
      setError(errorMessage(err, fallback));
    } finally {
      setBusy(false);
      setDialog(null);
    }
  }

  return (
    <section className="license" id={`lic-${license.lid}`} aria-label={`License ${license.lid}`}>
      <div className="license-main">
        <div>
          <p className="license-name">
            Pro <span className={`badge badge-${st.tone}`}>{st.label}</span>
          </p>
          <p className="small muted">
            {license.status === 'expired' ? 'Ended' : 'Ends'} {fmtDate(license.expires_at)}
          </p>
        </div>
        <div className="key-row" role="group" aria-label="Key actions">
          <p className="mono key">{shownKey}</p>
          <button
            type="button"
            className="icon-btn"
            aria-label={copied ? 'Copied' : 'Copy key'}
            title={copied ? 'Copied' : 'Copy key'}
            onClick={copy}
          >
            {copied ? (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M20 6 9 17l-5-5" />
              </svg>
            ) : (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <rect x="9" y="9" width="12" height="12" rx="2" />
                <path d="M5 15V5a2 2 0 0 1 2-2h10" />
              </svg>
            )}
          </button>
          <button
            type="button"
            className="icon-btn"
            aria-label={busy && !revealed ? 'Showing…' : revealed ? 'Hide key' : 'Show key'}
            title={revealed ? 'Hide key' : 'Show key'}
            disabled={busy}
            aria-busy={busy && !revealed ? true : undefined}
            onClick={show}
          >
            {busy && !revealed ? (
              <span className="spinner" aria-hidden="true" />
            ) : revealed ? (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M3 3l18 18" />
                <path d="M10.6 5.1A10 10 0 0 1 12 5c6 0 10 7 10 7a17 17 0 0 1-3.2 3.9M6.6 6.6A17 17 0 0 0 2 12s4 7 10 7a10 10 0 0 0 5.4-1.6" />
                <path d="M9.9 9.9a3 3 0 0 0 4.2 4.2" />
              </svg>
            ) : (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z" />
                <circle cx="12" cy="12" r="3" />
              </svg>
            )}
          </button>
        </div>
      </div>
      <ClusterHalf license={license} cs={cs} />
      <div className="license-footer" role="group" aria-label="License actions">
        <div className="license-group license-group-manage" role="group" aria-label="Manage license">
          {a && (
            <button type="button" className="btn-action" onClick={() => setDialog('move')}>
              Move to another cluster
            </button>
          )}
          {license.status !== 'revoked' && (
            <button type="button" className="btn-action btn-quiet" onClick={() => setDialog('replace')}>
              Replace key
            </button>
          )}
        </div>
      </div>

      {(error || message) && (
        <div className="license-wide">
          {error && <div className="alert" role="alert">{error}</div>}
          {message && <div className="notice" role="status">{message}</div>}
        </div>
      )}

      {dialog === 'move' && (
        <Dialog title="Move to another cluster" onClose={() => setDialog(null)}>
          <p>
            A license works on one cluster at a time. Moving releases it from the current cluster. On the new
            cluster, run the installer and choose License / Pro, then Add or replace key. The new cluster takes
            it within about 5 minutes; this one drops to Community at its next check.
          </p>
          <p>
            <strong>{plural(license.transfers_left, 'move', 'moves')} left this month</strong>
          </p>
          <div className="row">
            <button
              type="button"
              className="btn btn-primary"
              disabled={busy || license.transfers_left <= 0}
              onClick={() =>
                run(async () => {
                  await moveLicense(license.lid);
                  setMessage('License released. Add the key on your new cluster.');
                }, 'Could not move the license. Please try again.')
              }
            >
              {busy ? 'Moving…' : 'Move license'}
            </button>
            <button type="button" className="btn" onClick={() => setDialog(null)}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
      {dialog === 'replace' && (
        <Dialog title="Replace key" onClose={() => setDialog(null)}>
          <p>
            This issues a new key. <strong>The old key stops working</strong>, so update it on every cluster that
            uses it.
          </p>
          <div className="row">
            <button
              type="button"
              className="btn btn-danger"
              disabled={busy}
              onClick={() =>
                run(async () => {
                  const r = await replaceKey(license.lid);
                  setFullKey(r.key ?? null);
                  setMessage('New key issued. The old key no longer works.');
                }, 'Could not replace the key. Please try again.')
              }
            >
              {busy ? 'Replacing…' : 'Replace key'}
            </button>
            <button type="button" className="btn" onClick={() => setDialog(null)}>
              Cancel
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

export default function Licenses() {
  usePageTitle('Licenses');
  const {data, reload, updatedAt} = useSession();
  const cl = useClusters();
  const reloadClusters = cl.reload;
  const reloadAll = useCallback(async () => {
    await Promise.all([reload(), reloadClusters()]);
  }, [reload, reloadClusters]);
  const [tick, setTick] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setTick(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<ReactNode>('');
  const [trialKey, setTrialKey] = useState<{lid: string; key: string} | null>(null);
  const free = data.trials;
  const empty = data.licenses.length === 0;
  const byLicense = new Map<string, Cluster>();
  for (const c of cl.clusters ?? []) if (!byLicense.has(c.license)) byLicense.set(c.license, c);
  const rank = (l: License) => (l.status !== 'active' ? 0 : 1);
  const sorted = [...data.licenses].sort((a, b) => rank(a) - rank(b) || b.issued_at - a.issued_at);
  const where = free?.scope === 'organization' && free.domain ? free.domain : '';

  async function getFree() {
    setBusy(true);
    setError('');
    try {
      const r = await getFreeLicense();
      if (r.license && r.key) setTrialKey({lid: r.license.lid, key: r.key});
      await reload();
    } catch (err) {
      setError(errorMessage(err, 'Could not create the license. Please try again.', free?.limit));
      await reload();
    } finally {
      setBusy(false);
    }
  }

  const button = (
    <button type="button" className="btn btn-signal" disabled={busy} onClick={getFree}>
      {busy ? 'Getting your license…' : 'Get a free Pro license'}
    </button>
  );

  return (
    <>
      {empty && data.trial_available ? (
        <div className="empty">
          <div>
            <h1 className="big">Get your free Pro license.</h1>
            <p className="lead">
              Pro is free during early access. Each license is free for 3 months and we may renew it. One license runs one cluster. You can have{' '}
              {free?.limit ?? 2}
              {where ? ` (shared across ${where})` : ''}.
            </p>
            {error && <div className="alert" role="alert">{error}</div>}
            {button}
          </div>
          <ol className="steps">
            <li>Get your key here.</li>
            <li>
              Run the installer: <code className="mono small">{INSTALLER}</code>
            </li>
            <li>Choose License / Pro → Add or replace key.</li>
          </ol>
        </div>
      ) : (
        <>
          <div className="page-head">
            <h1>Licenses</h1>
            <div className="head-side">
              {free && (
                <span className="small muted">
                  <span className="mono count">{free.used} of {free.limit}</span> free Pro licenses used
                </span>
              )}
              <span className="small muted" title={fmtUtcFull(updatedAt / 1000)}>
                {fmtRefreshed(updatedAt, Math.max(tick, updatedAt))}
              </span>
            </div>
          </div>
          {error && <div className="alert" role="alert">{error}</div>}
          <div>
          {sorted.map((l) => (
            <LicenseCard
              key={l.lid}
              license={l}
              cs={{
                cluster: byLicense.get(l.lid),
                loading: cl.clusters === null && !cl.failed,
                failed: cl.failed,
                skewMs: cl.skewMs,
                latest: cl.latest,
                retry: () => void reloadClusters(),
              }}
              onChange={reloadAll}
              initialKey={trialKey?.lid === l.lid ? trialKey.key : null}
            />
          ))}
          </div>
          {empty && !data.trial_available && free && (
            <LimitNotice scope={free.scope} domain={free.domain} limit={free.limit} />
          )}
          {data.trial_available && !empty && (
            <div className="get-more">
              <button type="button" className="btn-action" disabled={busy} onClick={getFree}>
                {busy ? 'Getting your license…' : 'Get another free Pro license'}
              </button>
            </div>
          )}
        </>
      )}
    </>
  );
}
