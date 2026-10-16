import {useEffect, useState} from 'react';
import {Navigate, Route, Routes, useSearchParams} from 'react-router-dom';
import {getAccount} from './api';
import {Shell} from './components';
import {RequireAuth} from './session';
import Account from './pages/Account';
import Licenses from './pages/Licenses';
import NotFound from './pages/NotFound';
import Signin from './pages/Signin';

/** `/` goes to the licenses when signed in, else to sign-in. */
function Home() {
  const [to, setTo] = useState<string | null>(null);
  useEffect(() => {
    getAccount().then(
      () => setTo('/licenses'),
      () => setTo('/signin'),
    );
  }, []);
  return to ? <Navigate to={to} replace /> : <main className="center"><p className="muted">Loading…</p></main>;
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
