import {useState} from 'react';
import type {ReactNode} from 'react';
import {getFreeLicense, displayKey, moveLicense, replaceKey, revealKey} from '../api';
import type {License} from '../api';
import {Dialog, usePageTitle} from '../components';
import {fmtAgo, fmtDate, plural} from '../format';
import {errorMessage, LimitNotice} from '../messages';
import {useSession} from '../session';

const INSTALLER = '/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"';

function statusOf(l: License): {label: string; tone: 'ok' | 'warn' | 'bad'} {
  if (l.status === 'active') return l.activation ? {label: 'active', tone: 'ok'} : {label: 'not activated', tone: 'warn'};
  return {label: l.status, tone: 'bad'};
}

function LicenseCard({
  license,
  onChange,
  initialKey = null,
}: {
  license: License;
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
  const a = license.activation;

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
    <section className="license" aria-label={`License ${license.lid}`}>
      <div className="license-main">
        <p className="license-name">
          Pro <span className={`badge badge-${st.tone}`}>{st.label}</span>
        </p>
        <p className="mono small muted key">
          {shownKey} · {license.status === 'expired' ? 'expired' : 'ends'} {fmtDate(license.expires_at)}
        </p>
      </div>
      <div className="license-cluster">
        {a ? (
          <>
            <p className="small muted">Cluster · last check {fmtAgo(a.last_renew)}</p>
            <p className="mono">
              {a.cluster} · v{a.kwatch_version.replace(/^v/, '')} · {plural(a.node_count, 'node', 'nodes')}
            </p>
          </>
        ) : (
          <p className="body">Add it with the installer: License / Pro → Add or replace key.</p>
        )}
      </div>
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
  const {data, reload} = useSession();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<ReactNode>('');
  const [trialKey, setTrialKey] = useState<{lid: string; key: string} | null>(null);
  const free = data.trials;
  const empty = data.licenses.length === 0;
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
            {free && (
              <span className="small muted">
                Free Pro clusters: {free.used} of {free.limit} used{where ? ` · ${where}` : ''}
              </span>
            )}
          </div>
          {error && <div className="alert" role="alert">{error}</div>}
          {data.licenses.map((l) => (
            <LicenseCard
              key={l.lid}
              license={l}
              onChange={reload}
              initialKey={trialKey?.lid === l.lid ? trialKey.key : null}
            />
          ))}
          {empty && !data.trial_available && free && (
            <LimitNotice scope={free.scope} domain={free.domain} limit={free.limit} />
          )}
          {data.trial_available && !empty && <div className="get-more">{button}</div>}
        </>
      )}
    </>
  );
}
