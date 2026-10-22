import {useEffect, useId, useRef} from 'react';
import type {ReactNode, RefObject} from 'react';
import {NavLink, Outlet, useNavigate} from 'react-router-dom';
import {logout} from './api';
import {DOCS_URL, SITE_URL} from './config';
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
        <span className="brand">
          <Mark size={26} />
          <span className="wordmark">kwatch</span>
        </span>
        <NavLink to="/licenses">Licenses</NavLink>
        <NavLink to="/help">Get help</NavLink>
        <NavLink to="/account">Account</NavLink>
        <a className="muted-link" href={DOCS_URL}>
          Docs ↗
        </a>
        <a className="muted-link" href={SITE_URL}>
          kwatch.dev ↗
        </a>
        <span className="who">
          {data.account.email} ·{' '}
          <button type="button" className="link" onClick={signOut}>
            Sign out
          </button>
        </span>
      </nav>
      <div className="main">
        <main className="content">
          <Outlet />
        </main>
        <footer className="site-footer">kwatch · source available under ELv2</footer>
      </div>
    </div>
  );
}

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Modal dialog: focus moves in on open, Tab is trapped, Escape and the
 * backdrop close it, and focus returns to `returnFocusRef` (or the element
 * that was focused before it opened) on close.
 */
export function Dialog({
  title,
  children,
  onClose,
  returnFocusRef,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  returnFocusRef?: RefObject<HTMLElement | null>;
}) {
  const titleId = useId();
  const box = useRef<HTMLDivElement>(null);
  const closeRef = useRef(onClose);
  useEffect(() => {
    closeRef.current = onClose;
  });

  useEffect(() => {
    const target = returnFocusRef?.current ?? (document.activeElement as HTMLElement | null);
    const el = box.current;
    el?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        closeRef.current();
        return;
      }
      if (e.key !== 'Tab' || !el) return;
      const items = Array.from(el.querySelectorAll<HTMLElement>(FOCUSABLE));
      if (items.length === 0) {
        e.preventDefault();
        return;
      }
      const first = items[0];
      const last = items[items.length - 1];
      const active = document.activeElement;
      if (e.shiftKey && (active === first || active === el)) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      } else if (!el.contains(active)) {
        e.preventDefault();
        first.focus();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      if (target?.isConnected) target.focus();
    };
  }, [returnFocusRef]);

  return (
    <div className="overlay">
      <div className="backdrop" aria-hidden="true" onClick={onClose} />
      <div className="dialog" ref={box} role="dialog" aria-modal="true" aria-labelledby={titleId} tabIndex={-1}>
        <h3 id={titleId}>{title}</h3>
        {children}
      </div>
    </div>
  );
}
