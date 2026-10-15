import {useCallback, useEffect, useState} from 'react';
import type {ReactElement, ReactNode} from 'react';
import Layout from '@theme/Layout';
import BrowserOnly from '@docusaurus/BrowserOnly';
import Link from '@docusaurus/Link';
import {useHistory} from '@docusaurus/router';
import {ApiError, apiFetch, useSiteConfig} from '../lib/licenseApi';
import type {AccountResponse, License} from '../lib/licenseApi';

import styles from './portal.module.css';

function fmtDate(unix: number): string {
  return new Date(unix * 1000).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function daysLeft(unix: number): number {
  return Math.ceil((unix * 1000 - Date.now()) / 86_400_000);
}

const CONTACT_URL = 'mailto:hello@kwatch.dev';

function errorMessage(err: unknown, fallback: string): ReactNode {
  const e = err as ApiError;
  if (e?.code === 'network') return 'Could not reach the kwatch license service. Try again.';
  if (e?.code === 'trial_limit_reached' || e?.code === 'trial_already_used') {
    const who =
      e.scope === 'organization'
        ? `Your organization${e.domain ? ` (${e.domain})` : ''} has used both free Pro clusters.`
        : 'This account has used both free Pro clusters.';
    return (
      <>
        {who} Need more time or more clusters?{' '}
        <a href={CONTACT_URL}>Contact us</a> and we will help.
      </>
    );
  }
  if (e?.code === 'transfer_limit') return 'No transfers left for this license. Contact support if you need another.';
  if (e?.status === 401) return 'Your session expired. Please sign in again.';
  return fallback;
}

function Dialog({
  title,
  children,
  onClose,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}): ReactElement {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className={styles.overlay} onClick={onClose}>
      <div
        className={styles.dialog}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <h3>{title}</h3>
        {children}
      </div>
    </div>
  );
}

function LicenseCard({
  license,
  onChange,
  apiUrl,
}: {
  license: License;
  onChange: () => Promise<void>;
  apiUrl: string;
}): ReactElement {
  const [revealed, setRevealed] = useState(false);
  const [key, setKey] = useState(license.key);
  const [copied, setCopied] = useState(false);
  const [dialog, setDialog] = useState<null | 'transfer' | 'regenerate'>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<ReactNode>('');
  const [message, setMessage] = useState('');

  useEffect(() => setKey(license.key), [license.key]);

  const left = daysLeft(license.expires_at);
  const active = license.status === 'active';
  const shownKey = revealed ? key : key.slice(0, 6) + '•'.repeat(24);
  const snippet = `kubectl create secret generic kwatch-license -n kwatch \\
  --from-literal=license-key=${revealed ? key : '<LICENSE_KEY>'}
helm upgrade --install kwatch kwatch/kwatch \\
  --set license.existingSecret=kwatch-license`;

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      setError('Copy failed. Reveal the key and copy it manually.');
    }
  }

  async function run(path: string, ok: (r: any) => void, fallback: string) {
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const r = await apiFetch(apiUrl, `/v1/account/licenses/${encodeURIComponent(license.lid)}/${path}`, {
        method: 'POST',
      });
      ok(r);
      await onChange();
    } catch (err) {
      setError(errorMessage(err, fallback));
    } finally {
      setBusy(false);
      setDialog(null);
    }
  }

  return (
    <section className={styles.card} aria-label={`License ${license.lid}`}>
      <div className={styles.spread}>
        <div className={styles.row}>
          <h3 style={{margin: 0}}>{license.plan === 'trial' ? 'Pro trial' : 'Pro'}</h3>
          <span className={`${styles.badge} ${active ? styles.badgeActive : styles.badgeBad}`}>
            {license.status}
          </span>
        </div>
        <span className={styles.muted}>
          {left > 0 ? `${left} day${left === 1 ? '' : 's'} left` : 'Expired'} · until{' '}
          {fmtDate(license.expires_at)}
        </span>
      </div>

      {error && <div className={styles.error} role="alert" style={{marginTop: '1rem'}}>{error}</div>}
      {message && <div className={styles.notice} role="status" style={{marginTop: '1rem'}}>{message}</div>}

      <p style={{margin: '1rem 0 0'}}><strong>License key</strong></p>
      <div className={styles.keyBox}>
        <code className={styles.keyText}>{shownKey}</code>
        <button className="button button--secondary" onClick={() => setRevealed(!revealed)}>
          {revealed ? 'Hide' : 'Reveal'}
        </button>
        <button className="button button--secondary" onClick={() => copy(key)}>
          {copied ? 'Copied' : 'Copy'}
        </button>
      </div>

      <p style={{margin: 0}}><strong>Activation</strong></p>
      {license.activation ? (
        <dl className={styles.dl}>
          <dt>Cluster</dt><dd><code>{license.activation.cluster}</code></dd>
          <dt>First seen</dt><dd>{fmtDate(license.activation.first_seen)}</dd>
          <dt>Last renewal</dt><dd>{fmtDate(license.activation.last_renew)}</dd>
          <dt>kwatch version</dt><dd>{license.activation.kwatch_version}</dd>
          <dt>Nodes</dt><dd>{license.activation.node_count}</dd>
        </dl>
      ) : (
        <p className={styles.muted}>Not activated yet.</p>
      )}

      <p style={{margin: 0}}><strong>Install</strong></p>
      <pre className={styles.snippet}><code>{snippet}</code></pre>
      <div className={styles.row} style={{marginBottom: '0.75rem'}}>
        <button className="button button--sm button--secondary" onClick={() => copy(snippet.replace('<LICENSE_KEY>', key))}>
          Copy commands with key
        </button>
      </div>
      <p className={styles.muted} style={{fontSize: '0.88rem'}}>
        Prefer the guided installer? The <Link to="/docs/kwatch-sh">kwatch.sh</Link> manager has a
        License menu that does this for you. See <Link to="/docs/license">License docs</Link>.
      </p>

      <div className={styles.row}>
        <button className="button button--outline button--primary" disabled={busy} onClick={() => setDialog('transfer')}>
          Transfer to another cluster
        </button>
        <button className="button button--outline button--danger" disabled={busy} onClick={() => setDialog('regenerate')}>
          Regenerate key
        </button>
      </div>

      {dialog === 'transfer' && (
        <Dialog title="Transfer to another cluster" onClose={() => setDialog(null)}>
          <p>
            A license works on one cluster at a time. Transferring releases it from the current
            cluster so you can activate it on a new one. The new cluster picks up the license within
            about 5 minutes; the old cluster drops to Community at its next daily check.
          </p>
          <p><strong>Transfers left: {license.transfers_left}</strong></p>
          <div className={styles.row}>
            <button
              className="button button--primary"
              disabled={busy || license.transfers_left <= 0}
              onClick={() => run('transfer', () => setMessage('License released. Activate it on your new cluster.'), 'Transfer failed. Please try again.')}
            >
              {busy ? 'Transferring...' : 'Transfer license'}
            </button>
            <button className="button button--secondary" onClick={() => setDialog(null)}>Cancel</button>
          </div>
        </Dialog>
      )}
      {dialog === 'regenerate' && (
        <Dialog title="Regenerate license key" onClose={() => setDialog(null)}>
          <p>
            This issues a new key. <strong>The old key stops working</strong>, so update the Secret
            in every cluster that uses it.
          </p>
          <div className={styles.row}>
            <button
              className="button button--danger"
              disabled={busy}
              onClick={() =>
                run(
                  'regenerate',
                  (r: {key?: string}) => {
                    if (r?.key) setKey(r.key);
                    setRevealed(true);
                    setMessage('New key issued. The old key no longer works.');
                  },
                  'Could not regenerate the key. Please try again.',
                )
              }
            >
              {busy ? 'Regenerating...' : 'Regenerate key'}
            </button>
            <button className="button button--secondary" onClick={() => setDialog(null)}>Cancel</button>
          </div>
        </Dialog>
      )}
    </section>
  );
}

function Account(): ReactElement {
  const {apiUrl} = useSiteConfig();
  const history = useHistory();
  const [data, setData] = useState<AccountResponse | null>(null);
  const [error, setError] = useState<ReactNode>('');
  const [busy, setBusy] = useState(false);
  const [showDelete, setShowDelete] = useState(false);
  const [confirmText, setConfirmText] = useState('');

  const load = useCallback(async () => {
    try {
      setData(await apiFetch<AccountResponse>(apiUrl, '/v1/account'));
    } catch (err) {
      if ((err as ApiError).status === 401) {
        history.replace('/signup');
        return;
      }
      setError(errorMessage(err, 'Could not load your account. Please refresh.'));
    }
  }, [apiUrl, history]);

  useEffect(() => {
    load();
  }, [load]);

  async function logout() {
    try {
      await apiFetch(apiUrl, '/v1/auth/logout', {method: 'POST'});
    } catch {
      /* leave regardless */
    }
    history.replace('/signup');
  }

  async function startTrial() {
    setBusy(true);
    setError('');
    try {
      await apiFetch(apiUrl, '/v1/account/trial', {method: 'POST'});
      await load();
    } catch (err) {
      setError(errorMessage(err, 'Could not create the license. Please try again.'));
      await load();
    } finally {
      setBusy(false);
    }
  }

  async function deleteAccount() {
    setBusy(true);
    setError('');
    try {
      await apiFetch(apiUrl, '/v1/account', {method: 'DELETE'});
      history.replace('/signup');
    } catch (err) {
      setError(errorMessage(err, 'Could not delete the account. Please try again.'));
      setBusy(false);
    }
  }

  if (!data) {
    return (
      <div className={styles.card}>
        {error ? <div className={styles.error} role="alert">{error}</div> : <p>Loading your account...</p>}
      </div>
    );
  }

  return (
    <>
      <div className={styles.card}>
        <p className={styles.eyebrow}>Account</p>
        <div className={styles.spread}>
          <div>
            <h1 style={{fontSize: '1.6rem', margin: 0}}>Your licenses</h1>
            <p className={styles.muted} style={{margin: '0.25rem 0 0'}}>Signed in as {data.account.email}</p>
          </div>
          <button className="button button--secondary" onClick={logout}>Log out</button>
        </div>
        {error && <div className={styles.error} role="alert" style={{marginTop: '1rem'}}>{error}</div>}
        {data.trial_available && (
          <div style={{marginTop: '1rem'}}>
            <button className="button button--primary button--lg" disabled={busy} onClick={startTrial}>
              {busy ? 'Starting...' : 'Get 3 months of Pro free'}
            </button>
            <span className={styles.muted} style={{marginLeft: '0.75rem'}}>Free during early access. One cluster per license.</span>
          </div>
        )}
        {data.trials && (
          <p className={styles.muted} style={{margin: '0.75rem 0 0'}}>
            Trial clusters: {data.trials.used} of {data.trials.limit} used
            {data.trials.scope === 'organization' && data.trials.domain ? ` for ${data.trials.domain}` : ''}
          </p>
        )}
      </div>

      {data.licenses.length === 0 && !data.trial_available && (
        <div className={styles.card}><p>No licenses yet.</p></div>
      )}
      {data.licenses.map((l) => (
        <LicenseCard key={l.lid} license={l} apiUrl={apiUrl} onChange={load} />
      ))}

      <div className={`${styles.card} ${styles.danger}`}>
        <h3>Delete account</h3>
        <p className={styles.muted}>
          Permanently deletes your account, licenses and activation records. Clusters using a
          license fall back to Community. This cannot be undone.
        </p>
        {!showDelete ? (
          <button className="button button--outline button--danger" onClick={() => setShowDelete(true)}>
            Delete account...
          </button>
        ) : (
          <>
            <label htmlFor="delete-confirm">
              Type <strong>{data.account.email}</strong> to confirm
            </label>
            <input
              id="delete-confirm"
              className={styles.field}
              value={confirmText}
              onChange={(e) => setConfirmText(e.target.value)}
              autoComplete="off"
            />
            <div className={styles.row}>
              <button
                className="button button--danger"
                disabled={busy || confirmText !== data.account.email}
                onClick={deleteAccount}
              >
                {busy ? 'Deleting...' : 'Permanently delete account'}
              </button>
              <button className="button button--secondary" onClick={() => { setShowDelete(false); setConfirmText(''); }}>
                Cancel
              </button>
            </div>
          </>
        )}
      </div>
    </>
  );
}

export default function AccountPage(): ReactElement {
  return (
    <Layout
      title="Your account"
      description="Manage your kwatch Pro licenses, keys and cluster transfers."
    >
      <main className={styles.page}>
        <div className="container">
          <div className={styles.wide}>
            <BrowserOnly fallback={<div className={styles.card}><p>Loading your account...</p></div>}>
              {() => <Account />}
            </BrowserOnly>
          </div>
        </div>
      </main>
    </Layout>
  );
}
