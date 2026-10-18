import {useEffect, useState} from 'react';
import {Navigate, Route, Routes, useSearchParams} from 'react-router-dom';
import {getAccount} from './api';
import type {ApiError} from './api';
import {Shell} from './components';
import {RequireAuth} from './session';
import Account from './pages/Account';
import Licenses from './pages/Licenses';
import NotFound from './pages/NotFound';
import Signin from './pages/Signin';

/** `/` goes to the licenses when signed in, to sign-in only on a 401. */
function Home() {
  const [to, setTo] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let cancelled = false;
    getAccount().then(
      () => !cancelled && setTo('/licenses'),
      (err) => {
        if (cancelled) return;
        if ((err as ApiError).status === 401) setTo('/signin');
        else setFailed(true);
      },
    );
    return () => {
      cancelled = true;
    };
  }, [attempt]);
  if (to) return <Navigate to={to} replace />;
  if (failed) {
    return (
      <main className="center">
        <p role="alert" className="alert">Could not reach the kwatch service. Check your connection and try again.</p>
        <button
          type="button"
          className="btn"
          onClick={() => {
            setFailed(false);
            setAttempt((n) => n + 1);
          }}
        >
          Try again
        </button>
      </main>
    );
  }
  return <main className="center"><p className="muted">Loading…</p></main>;
}

/** Emails sent before the split link to /signup. */
function LegacySignup() {
  const [params] = useSearchParams();
  const q = params.toString();
  return <Navigate to={`/signin${q ? `?${q}` : ''}`} replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/signin" element={<Signin />} />
      <Route path="/signup" element={<LegacySignup />} />
      <Route
        element={
          <RequireAuth>
            <Shell />
          </RequireAuth>
        }
      >
        <Route path="/licenses" element={<Licenses />} />
        <Route path="/account" element={<Account />} />
      </Route>
      <Route path="*" element={<NotFound />} />
    </Routes>
  );
}
