import {useEffect} from 'react';
import type {ReactNode} from 'react';
import {NavLink, Outlet, useNavigate} from 'react-router-dom';
import {logout} from './api';
import {DOCS_URL} from './config';
import {useSession} from './session';

export function Mark({size = 34}: {size?: number}) {
  return (
    <svg className="mark" width={size} height={size} viewBox="0 0 64 64" aria-hidden="true">
      <path d="M17 5.5v53" strokeWidth="8.5" />
      <path d="M47.5 6.5 32.2 27.6" strokeWidth="7.5" />
      <path d="M33.4 36.8 48.5 57.5" strokeWidth="8" />
      <circle className="mark-dot" cx="28.6" cy="32.2" r="8.6" strokeWidth="3.2" />
    </svg>
  );
}

export function usePageTitle(title: string) {
  useEffect(() => {
    document.title = `${title} · kwatch`;
  }, [title]);
}

/** Centered card used by the sign-in screens and the 404. */
export function Card({children}: {children: ReactNode}) {
  return (
    <main className="center">
      <div className="card">{children}</div>
    </main>
  );
}

export function Shell() {
  const {data} = useSession();
  const navigate = useNavigate();

  async function signOut() {
    try {
      await logout();
    } catch {
      /* leave regardless */
    }
    navigate('/signin', {replace: true});
  }

  return (
    <div className="shell">
      <nav className="side" aria-label="App">
        <span className="wordmark">kwatch</span>
        <NavLink to="/licenses">Licenses</NavLink>
        <NavLink to="/account">Account</NavLink>
        <a className="muted-link" href={DOCS_URL}>
          Docs ↗
        </a>
        <span className="who">
          {data.account.email} ·{' '}
          <button type="button" className="link" onClick={signOut}>
            Sign out
          </button>
        </span>
      </nav>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}

export function Dialog({
  title,
  children,
  onClose,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="overlay" onClick={onClose}>
      <div className="dialog" role="dialog" aria-modal="true" aria-label={title} onClick={(e) => e.stopPropagation()}>
        <h3>{title}</h3>
        {children}
      </div>
    </div>
  );
}
