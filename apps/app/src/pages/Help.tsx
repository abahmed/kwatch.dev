import {useEffect, useRef, useState} from 'react';
import type {FormEvent} from 'react';
import {Link, useNavigate} from 'react-router-dom';
import {sendSupport} from '../api';
import type {ApiError, Cluster} from '../api';
import {usePageTitle} from '../components';
import {ISSUES_URL, SUPPORT_EMAIL, SUPPORT_MAILTO} from '../config';
import {fmtAgoLong, fmtDate} from '../format';
import {useSession} from '../session';
import {useClusters} from '../useClusters';

const INSTALLER = 'bash <(curl -fsSL https://kwatch.dev/kwatch.sh)';
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
    return `You have used today's requests. Reply to our email or write to ${SUPPORT_EMAIL}.`;
  }
  if (e?.status === 503 || e?.code === 'support_busy') {
    return `Help is at capacity right now. Email ${SUPPORT_EMAIL} and we will pick it up.`;
  }
  if (e?.status === 401) return 'Your session expired. Sign in again.';
  return `Nothing was sent. Try again, or email ${SUPPORT_EMAIL}.`;
}

function NotPro() {
  return (
    <div className="help">
      <div className="page-head"><h1>Get help</h1></div>
      <p className="body">Get help is for Pro. Community support is on GitHub.</p>
      <a className="btn btn-primary help-action" href={ISSUES_URL}>
        Open an issue
      </a>
    </div>
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
      <div className="page-head"><h1 ref={head} tabIndex={-1}>Request sent</h1></div>
      <p className="body">
        We reply by email to {email}. The reply comes from {SUPPORT_EMAIL}.
      </p>
      <p className="row">
        <span>Reference <span className="ref">{refId}</span></span>
        <button type="button" className="btn btn-sm" onClick={copy}>{copied ? 'Copied' : 'Copy'}</button>
      </p>
      <p className="body">Reply with your diagnostics file attached.</p>
      <section className="panel">
        <h2>Make the diagnostics file now</h2>
        <ol className="steps" style={{marginTop: 10}}>
          <li>Run the installer: <code className="mono small">{INSTALLER}</code></li>
          <li>Choose Save diagnostics to file.</li>
          <li>Keep the file ready. Secrets are removed and nothing is uploaded.</li>
        </ol>
      </section>
      <Link className="btn help-action" to="/licenses">
        Back to licenses
      </Link>
    </div>
  );
}

export default function Help() {
  usePageTitle('Get help');
  const navigate = useNavigate();
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
  const [notPro, setNotPro] = useState(false);
  const [sentRef, setSentRef] = useState<string | null>(null);
  const alertRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (error) {
      alertRef.current?.focus();
      alertRef.current?.scrollIntoView?.({block: 'center'});
    }
  }, [error]);

  if (pro.length === 0 || notPro) return <NotPro />;
  if (sentRef) return <Sent email={email} refId={sentRef} />;

  const license = pro.find((l) => l.lid === lid) ?? pro.find((l) => l.activation) ?? pro[0];
  const mine: Cluster[] = (clusters ?? []).filter((c) => c.license === license.lid);
  const picked = mine.find((c) => c.cluster_uuid === cluster);
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
      const ae = err as ApiError;
      if (ae?.status === 401) {
        navigate('/signin', {replace: true});
        return;
      }
      if (ae?.status === 403 && ae?.code === 'not_pro') {
        setNotPro(true);
        return;
      }
      setError(supportError(err));
      setBusy(false);
    }
  }

  return (
    <form className="help" onSubmit={submit} noValidate>
      <div className="page-head"><h1>Get help</h1></div>
      <p className="lead">Diagnostics go in your reply, not in this form.</p>
      {error && <div className="alert" role="alert" tabIndex={-1} ref={alertRef}>{error}</div>}

      <div className="row help-reply">
        <span className="help-label">Reply to</span>
        <span className="help-email">{email}</span>
      </div>

      {pro.length > 1 && (
        <>
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
                {l.lid} (expires {fmtDate(l.expires_at)})
              </option>
            ))}
          </select>
        </>
      )}

      <label htmlFor="help-cluster">Cluster</label>
      <select id="help-cluster" value={cluster} onChange={(e) => setCluster(e.target.value)}>
        <option value="">Not sure or not installed yet</option>
        {mine.map((c) => (
          <option key={c.cluster_uuid} value={c.cluster_uuid}>
            Cluster {c.id_short}
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
        aria-describedby={fieldError ? 'help-err' : undefined}
        aria-invalid={!!fieldError}
        onChange={(e) => setMessage(e.target.value)}
        onBlur={() => setTouched(true)}
      />
      <div className="field-row">
        <p className="field-error" id="help-err" aria-live="polite">{fieldError}</p>
        <p className="hint counter">
          {message.length} / {MAX}
          {message.length >= MAX * 0.9 && <span className="sr-only" role="status"> characters used</span>}
        </p>
      </div>

      <details className="sent-with">
        <summary>Sent with your request</summary>
        <dl className="mono-facts">
          <dt>License</dt><dd>{license.lid}</dd>
          <dt>Plan</dt><dd>Pro</dd>
          <dt>Expires</dt><dd>{fmtDate(license.expires_at)}</dd>
          <dt>Cluster</dt>
          <dd>
            {picked
              ? `${picked.id_short}${picked.version ? ` v${picked.version.replace(/^v/, '')}` : ''}${picked.last_seen ? `, last seen ${fmtAgoLong(picked.last_seen).toLowerCase()}` : ''}`
              : 'None selected'}
          </dd>
        </dl>
      </details>

      <div className="send-row">
        <button type="submit" className="btn btn-primary" disabled={busy || !valid}>
          {busy ? 'Sending…' : 'Send request'}
        </button>
        {!valid && !busy && <span className="hint">20 characters minimum</span>}
      </div>

      <p className="hint alt-contact">
        Prefer email? <a href={SUPPORT_MAILTO}>{SUPPORT_EMAIL}</a>
      </p>
    </form>
  );
}
