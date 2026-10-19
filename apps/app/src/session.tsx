import {createContext, useCallback, useContext, useEffect, useState} from 'react';
import type {ReactNode} from 'react';
import {Navigate} from 'react-router-dom';
import {ApiError, getAccount} from './api';
import type {AccountResponse} from './api';
import {errorMessage} from './messages';
import {useRefreshOnReturn} from './useRefreshOnReturn';

/** reload resolves true on success; updatedAt is when the account last loaded (ms). */
type Session = {data: AccountResponse; reload: () => Promise<boolean>; updatedAt: number};
const Ctx = createContext<Session | null>(null);

export function useSession(): Session {
  const s = useContext(Ctx);
  if (!s) throw new Error('useSession outside RequireAuth');
  return s;
}

/** Loads the account; a 401 sends the person to /signin. */
export function RequireAuth({children}: {children: ReactNode}) {
  const [data, setData] = useState<AccountResponse | null>(null);
  const [updatedAt, setUpdatedAt] = useState(0);
  const [unauth, setUnauth] = useState(false);
  const [error, setError] = useState<ReactNode>('');

  const reload = useCallback(async () => {
    try {
      setData(await getAccount());
      setUpdatedAt(Date.now());
      setError('');
      return true;
    } catch (err) {
      if ((err as ApiError).status === 401) setUnauth(true);
      else setError(errorMessage(err, 'Could not load your account. Please refresh.'));
      return false;
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    getAccount().then(
      (d) => {
        if (cancelled) return;
        setData(d);
        setUpdatedAt(Date.now());
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

  // Quiet: the page keeps its content while the account reloads.
  useRefreshOnReturn(() => void reload());

  if (unauth) return <Navigate to="/signin" replace />;
  if (!data) {
    return (
      <main className="center">
        {error ? <p role="alert" className="alert">{error}</p> : <p className="muted">Loading…</p>}
      </main>
    );
  }
  return <Ctx.Provider value={{data, reload, updatedAt}}>{children}</Ctx.Provider>;
}
