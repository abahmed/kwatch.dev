import {useEffect, useState} from 'react';
import type {FormEvent, ReactNode} from 'react';
import {Link, useNavigate, useSearchParams} from 'react-router-dom';
import {ApiError, getAccount, startSignin, verifySignin} from '../api';
import {Card, Mark, usePageTitle} from '../components';
import {SITE_URL, TURNSTILE_SITEKEY} from '../config';
import {errorMessage} from '../messages';
import {Turnstile} from '../turnstile';

function ExpiredNotice() {
  return (
    <div className="notice notice-warn" role="alert">
      <p className="notice-title">Link expired</p>
      <p>
        Links work once, for 15 minutes. <Link to="/signin">Get a new one</Link>.
      </p>
    </div>
  );
}

function Confirm({t}: {t: string}) {
  usePageTitle('Continue');
  const navigate = useNavigate();
  const [busy, setBusy] = useState(false);
  const [expired, setExpired] = useState(false);
  const [error, setError] = useState<ReactNode>('');

  async function go() {
    setBusy(true);
    setError('');
    try {
      await verifySignin(t);
      navigate('/licenses', {replace: true});
    } catch (err) {
      if ((err as ApiError).code === 'link_expired') setExpired(true);
      else setError(errorMessage(err, 'Something went wrong. Please try again.'));
      setBusy(false);
    }
  }

  return (
    <Card>
      <h1>Continue to kwatch</h1>
      <p className="lead">
        Press the button to finish signing in. (This stops email scanners from using your link.)
      </p>
      {error && <p className="alert" role="alert">{error}</p>}
      {expired ? (
        <ExpiredNotice />
      ) : (
        <button type="button" className="btn btn-primary" disabled={busy} onClick={go}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      )}
    </Card>
  );
}

function Request({linkExpired}: {linkExpired: boolean}) {
  usePageTitle('Sign in');
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [token, setToken] = useState('');
  const [widgetKey, setWidgetKey] = useState(0);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<ReactNode>('');

  // Already signed in? Go to the licenses.
  useEffect(() => {
    let cancelled = false;
    getAccount()
      .then(() => {
        if (!cancelled) navigate('/licenses', {replace: true});
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [navigate]);

  const freshCheck = () => {
    setToken('');
    setWidgetKey((k) => k + 1);
  };

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError('');
    if (TURNSTILE_SITEKEY && !token) {
      setError('Please complete the verification check first.');
      return;
    }
    setBusy(true);
    try {
      await startSignin(email.trim(), token);
      setSent(true);
    } catch (err) {
      setError(errorMessage(err, 'Something went wrong. Please try again.'));
      freshCheck();
    } finally {
      setBusy(false);
    }
  }

  if (sent) {
    return (
      <Card>
        <p className="eyebrow">link sent</p>
        <h1>Check your inbox</h1>
        <p className="lead">
          We sent a sign-in link to <strong>{email.trim()}</strong>. It works once, for 15 minutes.
        </p>
        <p className="body">
          Nothing after a minute? Check spam, or{' '}
          <button
            type="button"
            className="link"
            onClick={() => {
              setSent(false);
              freshCheck();
            }}
          >
            send another link
          </button>
          .
        </p>
        <p className="body">
          <button
            type="button"
            className="link"
            onClick={() => {
              setSent(false);
              setEmail('');
              freshCheck();
            }}
          >
            Use a different email
          </button>
        </p>
      </Card>
    );
  }

  return (
    <Card>
      <form onSubmit={submit} noValidate>
        <Mark />
        <h1>Sign in to kwatch</h1>
        <p className="lead small-lead">New here? The same link creates your account. No password.</p>
        {linkExpired && <ExpiredNotice />}
        {error && <p className="alert" role="alert">{error}</p>}
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          autoComplete="email"
          required
          placeholder="you@company.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <Turnstile
          key={widgetKey}
          onToken={setToken}
          onLoadError={() => setError('Could not load the verification check, please retry.')}
        />
        <button type="submit" className="btn btn-primary btn-block" disabled={busy || !email}>
          {busy ? 'Sending…' : 'Email me a sign-in link'}
        </button>
        <p className="muted small">
          By continuing you agree to the <a href={`${SITE_URL}/terms`}>Terms</a> and{' '}
          <a href={`${SITE_URL}/privacy`}>Privacy policy</a>.
        </p>
        <p className="back">
          <a href={SITE_URL}>← Back to kwatch.dev</a>
        </p>
      </form>
    </Card>
  );
}

export default function Signin() {
  const [params] = useSearchParams();
  const t = params.get('t');
  if (t) return <Confirm t={t} />;
  return <Request linkExpired={params.get('error') === 'link_expired'} />;
}
