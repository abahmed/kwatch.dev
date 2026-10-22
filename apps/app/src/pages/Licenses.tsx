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

export const MIN_REFRESH_MS = 400;
const REFRESH_ERROR = 'Could not refresh. Check your connection and try again.';

const INSTALLER = '/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"';

function LastSeen({unix, skewMs}: {unix: number; skewMs: number}) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(id);
  }, []);
  return <span title={fmtUtcFull(unix)}>Last seen {fmtLastSeenAgo(unix, now + skewMs)}</span>;
}

function statusOf(l: License): {label: string; tone: 'neutral' | 'warn' | 'bad'} {
  if (l.status === 'active') return {label: 'active', tone: 'neutral'};
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
      <div className="cluster-grid">
        <div className="cluster-name">
          Cluster <span className="mono cluster-id">{c.id_short}</span>
        </div>
        <div className="mono cluster-sub cluster-last">
          <LastSeen unix={c.last_seen} skewMs={cs.skewMs} />
        </div>
        <div className="cluster-version-col">
          <div className="mono cluster-version">{c.version ? `v${c.version.replace(/^v/, '')}` : ''}</div>
          {cs.latest && isOutdated(c.version, cs.latest) && (
            <a className="small update-available" href={`${DOCS_URL}/update`}>
              Update available: v{cs.latest.replace(/^v/, '')}
            </a>
          )}
        </div>
        <div className="cluster-nodes">{c.nodes != null ? plural(c.nodes, 'node', 'nodes') : ''}</div>
      </div>
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
      <p className="mono cluster-label">Cluster</p>
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
            Free during early access · {license.status === 'expired' ? 'ended' : 'ends'} {fmtDate(license.expires_at)}
          </p>
        </div>
        <p className="mono key">{shownKey}</p>
      </div>
      <ClusterHalf license={license} cs={cs} />
      <div className="license-footer" role="group" aria-label="License actions">
        <div className="license-group license-group-key" role="group" aria-label="Key actions">
          <button type="button" className="btn-action is-primary" onClick={copy}>
            {copied ? 'Copied' : 'Copy key'}
          </button>
          <button
            type="button"
            className="btn-action is-toggle"
            disabled={busy}
            aria-busy={busy && !revealed ? true : undefined}
            onClick={show}
          >
            {busy && !revealed ? 'Showing…' : revealed ? 'Hide key' : 'Show key'}
          </button>
        </div>
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
  const [refreshing, setRefreshing] = useState(false);
  const [refreshFailed, setRefreshFailed] = useState(false);
  const [announce, setAnnounce] = useState('');
  const [tick, setTick] = useState(() => Date.now());
  useEffect(() => {
    const id = setInterval(() => setTick(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);
  // Manual refresh: busy state stays up for at least MIN_REFRESH_MS so it registers.
  async function refresh() {
    setRefreshing(true);
    setRefreshFailed(false);
    setAnnounce('');
    try {
      const [results] = await Promise.all([
        Promise.all([reload(), reloadClusters()]),
        new Promise((r) => setTimeout(r, MIN_REFRESH_MS)),
      ]);
      const failed = results.some((ok) => !ok);
      setRefreshFailed(failed);
      setAnnounce(failed ? REFRESH_ERROR : 'Refreshed');
    } finally {
      setRefreshing(false);
    }
  }
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
                  {where ? ` · ${where}` : ''}
                </span>
              )}
              <span className="small muted" title={fmtUtcFull(updatedAt / 1000)}>
                {fmtRefreshed(updatedAt, Math.max(tick, updatedAt))}
              </span>
              <span className="sr-only" aria-live="polite">{announce}</span>
              <button
                type="button"
                className="link small"
                disabled={refreshing}
                aria-busy={refreshing || undefined}
                onClick={() => void refresh()}
              >
                {refreshing && <span className="spinner" aria-hidden="true" />}
                {refreshing ? 'Refreshing…' : 'Refresh'}
              </button>
            </div>
          </div>
          {error && <div className="alert" role="alert">{error}</div>}
          {refreshFailed && !refreshing && (
            <div className="alert">{REFRESH_ERROR}</div>
          )}
          <div aria-busy={refreshing}>
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
              <p className="small muted">You can have {free?.limit ?? 2}. One license runs one cluster.</p>
            </div>
          )}
          {!empty && (
            <div className="small muted">
              <p>
                Want an alert if kwatch stops?{' '}
                <a href={`${DOCS_URL}/heartbeat-monitor-configuration`}>Set up the dead man&rsquo;s switch.</a>
              </p>
            </div>
          )}
        </>
      )}
    </>
  );
}
