import {useEffect, useState} from 'react';
import type {ReactElement} from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import Head from '@docusaurus/Head';
import BrowserOnly from '@docusaurus/BrowserOnly';
import {useHistory, useLocation} from '@docusaurus/router';
import {ApiError, apiFetch, useSiteConfig} from '../lib/licenseApi';

import styles from './portal.module.css';

function SigninCard(): ReactElement | null {
  const {apiUrl} = useSiteConfig();
  const history = useHistory();
  const location = useLocation();
  const t = new URLSearchParams(location.search).get('t');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [expired, setExpired] = useState(false);

  useEffect(() => {
    if (!t) history.replace('/signup');
  }, [t, history]);

  if (!t) return null;

  async function confirm() {
    setBusy(true);
    setError('');
    try {
      await apiFetch(apiUrl, '/v1/auth/verify', {method: 'POST', body: {t}});
      history.push('/account');
    } catch (err) {
      const e = err as ApiError;
      if (e.code === 'link_expired') setExpired(true);
      else if (e.code === 'network') setError('Could not reach the kwatch license service. Check your connection and try again.');
      else setError('Something went wrong. Please try again.');
      setBusy(false);
    }
  }

  if (expired) {
    return (
      <div className={styles.card}>
        <p className={styles.eyebrow}>kwatch Pro</p>
        <h1>Link expired</h1>
        <div className={styles.error} role="alert">
          That sign-in link has expired or was already used.
        </div>
        <p>
          <Link to="/signup">Request a new sign-in link</Link>
        </p>
      </div>
    );
  }

  return (
    <div className={styles.card}>
      <p className={styles.eyebrow}>kwatch Pro</p>
      <h1>Sign in to kwatch</h1>
      <p className={styles.muted}>Confirm to finish signing in on this device.</p>
      {error && (
        <div className={styles.error} role="alert">
          {error}
        </div>
      )}
      <button className="button button--primary button--lg" type="button" disabled={busy} onClick={confirm}>
        {busy ? 'Signing in...' : 'Sign in to kwatch'}
      </button>
    </div>
  );
}

export default function Signin(): ReactElement {
  return (
    <Layout title="Sign in" description="Finish signing in to your kwatch account.">
      <Head>
        <meta name="robots" content="noindex, nofollow" />
      </Head>
      <main className={styles.page}>
        <div className="container">
          <div className={styles.narrow}>
            <BrowserOnly fallback={<div className={styles.card}><h1>Sign in</h1></div>}>
              {() => <SigninCard />}
            </BrowserOnly>
          </div>
        </div>
      </main>
    </Layout>
  );
}
