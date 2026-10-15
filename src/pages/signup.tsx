import {useEffect, useRef, useState} from 'react';
import type {FormEvent, ReactElement} from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import BrowserOnly from '@docusaurus/BrowserOnly';
import {useHistory, useLocation} from '@docusaurus/router';
import {ApiError, apiFetch, useSiteConfig} from '../lib/licenseApi';

import styles from './portal.module.css';

type TurnstileApi = {
  render: (
    el: HTMLElement,
    opts: {
      sitekey: string;
      callback: (token: string) => void;
      'expired-callback': () => void;
      'error-callback': () => void;
    },
  ) => string;
  reset: (id?: string) => void;
  remove: (id?: string) => void;
};

declare global {
  interface Window {
    turnstile?: TurnstileApi;
  }
}

const SCRIPT_SRC = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

const LOAD_TIMEOUT_MS = 15000;

function loadTurnstile(): Promise<TurnstileApi> {
  return new Promise((resolve, reject) => {
    if (window.turnstile) return resolve(window.turnstile);
    let script = document.querySelector<HTMLScriptElement>(
      'script[data-kwatch-turnstile]',
    );
    // A tag left behind by a failed load would never fire again: drop it.
    if (script && script.dataset.state === 'error') {
      script.remove();
      script = null;
    }
    const timer = window.setTimeout(() => {
      script?.remove();
      reject(new Error('turnstile timeout'));
    }, LOAD_TIMEOUT_MS);
    const onLoad = () => {
      window.clearTimeout(timer);
      if (window.turnstile) {
        if (script) script.dataset.state = 'loaded';
        resolve(window.turnstile);
      } else {
        script?.remove();
        reject(new Error('turnstile'));
      }
    };
    const onError = () => {
      window.clearTimeout(timer);
      script?.remove();
      reject(new Error('turnstile'));
    };
    if (!script) {
      script = document.createElement('script');
      script.src = SCRIPT_SRC;
      script.async = true;
      script.defer = true;
      script.dataset.kwatchTurnstile = '1';
      document.head.appendChild(script);
    }
    script.addEventListener('load', onLoad);
    script.addEventListener('error', () => {
      if (script) script.dataset.state = 'error';
      onError();
    });
  });
}

function SignupForm(): ReactElement {
  const {apiUrl, turnstileSiteKey} = useSiteConfig();
  const history = useHistory();
  const location = useLocation();
  const linkExpired = new URLSearchParams(location.search).get('error') === 'link_expired';

  const [email, setEmail] = useState('');
  const [token, setToken] = useState('');
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');
  const widgetRef = useRef<HTMLDivElement>(null);
  const widgetId = useRef<string | undefined>(undefined);

  // Already signed in? Go to the account page.
  useEffect(() => {
    let cancelled = false;
    apiFetch(apiUrl, '/v1/account')
      .then(() => {
        if (!cancelled) history.replace('/account');
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, [apiUrl, history]);

  // Lazily load the Turnstile widget, client only.
  useEffect(() => {
    if (!turnstileSiteKey || sent) return undefined;
    let cancelled = false;
    loadTurnstile()
      .then((ts) => {
        if (cancelled || !widgetRef.current) return;
        widgetId.current = ts.render(widgetRef.current, {
          sitekey: turnstileSiteKey,
          callback: setToken,
          'expired-callback': () => setToken(''),
          'error-callback': () => setToken(''),
        });
      })
      .catch(() =>
        setError('Could not load the verification widget, please retry.'),
      );
    return () => {
      cancelled = true;
      if (widgetId.current && window.turnstile) window.turnstile.remove(widgetId.current);
      widgetId.current = undefined;
    };
  }, [turnstileSiteKey, sent]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError('');
    if (turnstileSiteKey && !token) {
      setError('Please complete the verification check first.');
      return;
    }
    setBusy(true);
    try {
      await apiFetch(apiUrl, '/v1/auth/start', {
        method: 'POST',
        body: {email: email.trim(), turnstile_token: token},
      });
      setSent(true);
    } catch (err) {
      const e2 = err as ApiError;
      if (e2.code === 'disposable_email') {
        setError('Disposable email addresses are not accepted. Please use a permanent address.');
      } else if (e2.code === 'invalid_email') {
        setError('That does not look like a valid email address.');
      } else if (e2.status === 429) {
        setError('Too many attempts. Please wait a few minutes and try again.');
      } else if (e2.code === 'network') {
        setError('Could not reach the kwatch license service. Check your connection and try again.');
      } else {
        setError('Something went wrong. Please try again.');
      }
      if (widgetId.current && window.turnstile) window.turnstile.reset(widgetId.current);
      setToken('');
    } finally {
      setBusy(false);
    }
  }

  if (sent) {
    return (
      <div className={styles.card}>
        <p className={styles.eyebrow}>Almost there</p>
        <h1>Check your inbox</h1>
        <p>
          We sent a sign-in link to <strong>{email}</strong>. It opens your account and expires
          shortly, so use it soon. No password needed.
        </p>
        <p className={styles.muted}>
          Nothing arrived? Check spam, or{' '}
          <a
            href="#resend"
            onClick={(e) => {
              e.preventDefault();
              setSent(false);
              setToken('');
            }}
          >
            try again
          </a>
          .
        </p>
      </div>
    );
  }

  return (
    <form className={styles.card} onSubmit={submit} noValidate>
      <p className={styles.eyebrow}>kwatch Pro</p>
      <h1>Sign in or get kwatch Pro free</h1>
      <p className={styles.muted}>
        Enter your email and we will send you a sign-in link. New here? That creates your account
        and unlocks 3 months of Pro, free during early access.
      </p>
      {linkExpired && (
        <div className={styles.error} role="alert">
          That sign-in link has expired or was already used. Request a new one below.
        </div>
      )}
      {error && (
        <div className={styles.error} role="alert">
          {error}
        </div>
      )}
      <label htmlFor="signup-email">Email address</label>
      <input
        id="signup-email"
        className={styles.field}
        type="email"
        autoComplete="email"
        required
        placeholder="you@company.com"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
      />
      {turnstileSiteKey ? (
        <div ref={widgetRef} style={{marginBottom: '1rem'}} />
      ) : (
        <div className={styles.todo}>
          TODO: set KWATCH_TURNSTILE_SITEKEY at build time to render the Cloudflare Turnstile widget.
        </div>
      )}
      <button className="button button--primary button--lg" type="submit" disabled={busy || !email}>
        {busy ? 'Sending...' : 'Email me a sign-in link'}
      </button>
      <p className={styles.muted} style={{marginTop: '1rem', fontSize: '0.85rem'}}>
        By continuing you agree to the <Link to="/terms">Terms</Link> and{' '}
        <Link to="/privacy">Privacy policy</Link>. The free Community edition needs no account.
      </p>
    </form>
  );
}

export default function Signup(): ReactElement {
  return (
    <Layout
      title="Sign in or get kwatch Pro free"
      description="Create a kwatch account with a magic link and get kwatch Pro free for 3 months during early access."
    >
      <main className={styles.page}>
        <div className="container">
          <div className={styles.narrow}>
            <BrowserOnly fallback={<div className={styles.card}><h1>Sign in</h1></div>}>
              {() => <SignupForm />}
            </BrowserOnly>
          </div>
        </div>
      </main>
    </Layout>
  );
}
