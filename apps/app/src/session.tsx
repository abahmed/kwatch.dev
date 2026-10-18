import {createContext, useCallback, useContext, useEffect, useState} from 'react';
import type {ReactNode} from 'react';
import {Navigate} from 'react-router-dom';
import {ApiError, getAccount} from './api';
import type {AccountResponse} from './api';
import {errorMessage} from './messages';

type Session = {data: AccountResponse; reload: () => Promise<void>};
const Ctx = createContext<Session | null>(null);

export function useSession(): Session {
  const s = useContext(Ctx);
  if (!s) throw new Error('useSession outside RequireAuth');
  return s;
}

/** Loads the account; a 401 sends the person to /signin. */
export function RequireAuth({children}: {children: ReactNode}) {
  const [data, setData] = useState<AccountResponse | null>(null);
  const [unauth, setUnauth] = useState(false);
  const [error, setError] = useState<ReactNode>('');

  const reload = useCallback(async () => {
    try {
      setData(await getAccount());
      setError('');
    } catch (err) {
      if ((err as ApiError).status === 401) setUnauth(true);
      else setError(errorMessage(err, 'Could not load your account. Please refresh.'));
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    getAccount().then(
      (d) => {
        if (!cancelled) setData(d);
      },
      (err) => {
        if (cancelled) return;
        if ((err as ApiError).status === 401) setUnauth(true);
        else setError(errorMessage(err, 'Could not load your account. Please refresh.'));
      },
    );
    return () => {
      cancelled = true;
    };
  }, []);

  if (unauth) return <Navigate to="/signin" replace />;
  if (!data) {
    return (
      <main className="center">
        {error ? <p role="alert" className="alert">{error}</p> : <p className="muted">Loading…</p>}
      </main>
    );
  }
  return <Ctx.Provider value={{data, reload}}>{children}</Ctx.Provider>;
}
