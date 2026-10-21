import {useEffect, useRef, useState} from 'react';
import type {FormEvent} from 'react';
import {Link} from 'react-router-dom';
import {sendSupport} from '../api';
import type {ApiError, Cluster} from '../api';
import {usePageTitle} from '../components';
import {ISSUES_URL} from '../config';
import {fmtAgoLong, fmtDate} from '../format';
import {useSession} from '../session';
import {useClusters} from '../useClusters';

const INSTALLER = '/bin/bash -c "$(curl -fsSL https://kwatch.dev/kwatch.sh)"';
const MIN = 20;
const MAX = 4000;
const TOPICS: [string, string][] = [
  ['installing', 'Installing kwatch'],
  ['alerts_not_arriving', 'Alerts not arriving'],
  ['alert_unclear', 'An alert I do not understand'],
  ['license', 'My license'],
  ['other', 'Something else'],
];

export function supportError(err: unknown): string {
  const e = err as ApiError;
  if (e?.code === 'network') {
    return 'We could not reach the kwatch service, so nothing was sent. Check your connection and try again.';
  }
  if (e?.status === 429 || e?.code === 'support_limit') {
    return 'You have sent 3 requests today. Please wait for our reply, or try again tomorrow. For something urgent, open an issue on GitHub.';
  }
  if (e?.status === 503 || e?.code === 'support_busy') {
    return 'Support is busy right now. Please try again tomorrow or open an issue on GitHub.';
  }
  if (e?.status === 401) return 'Your session expired. Please sign in again.';
  return 'We could not send your request. Nothing was sent. Try again, and if it keeps failing, open an issue on GitHub.';
}

function NotPro() {
  return (
    <>
      <h1>Get help</h1>
      <p className="body">Get help is for Pro. Community support is on GitHub.</p>
      <a className="btn btn-primary" style={{display: 'inline-block', marginTop: 18, textDecoration: 'none'}} href={ISSUES_URL}>
        Open an issue
      </a>
    </>
  );
}

function Sent({email, refId}: {email: string; refId: string}) {
  const head = useRef<HTMLHeadingElement>(null);
  const [copied, setCopied] = useState(false);
  useEffect(() => head.current?.focus(), []);
  async function copy() {
    try {
      await navigator.clipboard.writeText(refId);
      setCopied(true);
    } catch {
      /* the reference stays selectable */
    }
  }
  return (
    <div className="help">
      <h1 ref={head} tabIndex={-1}>Request sent</h1>
      <p className="body">
        We will reply by e-mail to {email}. Replies come from our support address, so check your spam folder if you do
        not see one.
      </p>
      <p className="row" style={{alignItems: 'center'}}>
        <span>Reference <span className="ref">{refId}</span></span>
        <button type="button" className="btn btn-sm" onClick={copy}>{copied ? 'Copied' : 'Copy'}</button>
      </p>
      <p className="body">When we do, reply with your diagnostics file attached.</p>
      <section className="panel">
        <h2>Make the diagnostics file now</h2>
        <ol className="steps" style={{marginTop: 10}}>
          <li>Run the installer: <code className="mono small">{INSTALLER}</code></li>
          <li>Choose Save diagnostics to file.</li>
          <li>Keep the file ready. Secrets are removed and nothing is uploaded.</li>
        </ol>
      </section>
      <Link className="btn" style={{display: 'inline-block', marginTop: 18, textDecoration: 'none'}} to="/licenses">
        Back to licenses
      </Link>
    </div>
  );
}

export default function Help() {
  usePageTitle('Get help');
  const {data} = useSession();
  const {clusters} = useClusters();
  const email = data.account.email;
  const [now] = useState(() => Math.floor(Date.now() / 1000));
  const pro = data.licenses.filter((l) => l.status === 'active' && l.expires_at > now);

  const [lid, setLid] = useState('');
  const [cluster, setCluster] = useState('');
  const [topic, setTopic] = useState(TOPICS[0][0]);
  const [message, setMessage] = useState('');
  const [touched, setTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [sentRef, setSentRef] = useState<string | null>(null);

  if (pro.length === 0) return <NotPro />;
  if (sentRef) return <Sent email={email} refId={sentRef} />;

  const license = pro.find((l) => l.lid === lid) ?? pro.find((l) => l.activation) ?? pro[0];
  const mine: Cluster[] = (clusters ?? []).filter((c) => c.license === license.lid);
  const len = message.trim().length;
  const tooShort = len < MIN;
  const tooLong = message.length > MAX;
  const valid = !tooShort && !tooLong;
  const fieldError = tooLong
    ? 'That is over the 4000 character limit.'
    : touched && tooShort
      ? 'Please write at least 20 characters so we can help.'
      : '';

  async function submit(e: FormEvent) {
    e.preventDefault();
    setTouched(true);
    if (!valid || busy) return;
    setBusy(true);
    setError('');
    try {
      const body = {license: license.lid, topic, message: message.trim()};
      const r = await sendSupport(cluster ? {...body, cluster_uuid: cluster} : body);
      setSentRef(r.ref);
    } catch (err) {
      setError(supportError(err));
      setBusy(false);
    }
  }

  return (
    <form className="help" onSubmit={submit} noValidate>
      <h1>Get help</h1>
      <p className="lead">No file goes in this form. We reply by e-mail.</p>
      {error && <div className="alert" role="alert">{error}</div>}

      <label htmlFor="help-email">Your email</label>
      <input id="help-email" value={email} readOnly />
      <p className="hint">We reply to this address.</p>

      <label htmlFor="help-license">License</label>
      <select
        id="help-license"
        value={license.lid}
        onChange={(e) => {
          setLid(e.target.value);
          setCluster('');
        }}
      >
        {pro.map((l) => (
          <option key={l.lid} value={l.lid}>
            {l.lid}
          </option>
        ))}
      </select>

      <label htmlFor="help-cluster">Cluster</label>
      <select id="help-cluster" value={cluster} onChange={(e) => setCluster(e.target.value)}>
        <option value="">Not sure or not installed yet</option>
        {mine.map((c) => (
          <option key={c.cluster_uuid} value={c.cluster_uuid}>
            Cluster {c.id_short}
            {c.version ? ` (v${c.version.replace(/^v/, '')}` : ' ('}
            {c.last_seen ? `${c.version ? ', ' : ''}${fmtAgoLong(c.last_seen).toLowerCase()}` : ''})
          </option>
        ))}
      </select>

      <label htmlFor="help-topic">What do you need help with?</label>
      <select id="help-topic" value={topic} onChange={(e) => setTopic(e.target.value)}>
        {TOPICS.map(([id, label]) => (
          <option key={id} value={id}>{label}</option>
        ))}
      </select>

      <label htmlFor="help-message">Tell us what happened</label>
      <textarea
        id="help-message"
        value={message}
        placeholder="What you expected, what you saw, and what you tried."
        aria-describedby="help-count help-err"
        aria-invalid={!!fieldError}
        onChange={(e) => setMessage(e.target.value)}
        onBlur={() => setTouched(true)}
      />
      <p className="hint" id="help-count">
        {message.length} / {MAX}
        {message.length >= MAX * 0.9 && <span className="sr-only" role="status"> characters used</span>}
      </p>
      <p className="field-error" id="help-err" aria-live="polite">{fieldError}</p>
      <p className="hint">
        No file goes in this form. After we reply by e-mail, attach your diagnostics file to that reply. Installer:
        Save diagnostics to file.
      </p>

      <p className="hint" style={{marginTop: 18}}>
        Sent with your request: license, plan and expiry, cluster IDs, versions and last seen.
        {' '}({license.lid}, Pro, expires {fmtDate(license.expires_at)})
      </p>

      <button type="submit" className="btn btn-primary" style={{marginTop: 18}} disabled={busy || !valid}>
        {busy ? 'Sending…' : 'Send request'}
      </button>
    </form>
  );
}
