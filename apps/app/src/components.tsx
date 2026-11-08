import {useEffect, useId, useRef, useState} from 'react';
import type {ReactNode, RefObject} from 'react';
import {NavLink, Outlet, useNavigate} from 'react-router-dom';
import {logout, logoutAll} from './api';
import type {ApiError} from './api';
import {BLOG_URL, DOCS_URL, GITHUB_URL, SITE_URL} from './config';
import {useSession} from './session';
import {useTheme} from './theme';
import type {Theme} from './theme';

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

const THEME_LABEL: Record<Theme, string> = {system: 'System', light: 'Light', dark: 'Dark'};

function ThemeIcon({theme}: {theme: Theme}) {
  const common = {
    width: 20,
    height: 20,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true,
  };
  if (theme === 'light') {
    return (
      <svg {...common}>
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
      </svg>
    );
  }
  if (theme === 'dark') {
    return (
      <svg {...common}>
        <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />
      </svg>
    );
  }
  return (
    <svg {...common}>
      <rect x="3" y="4" width="18" height="12" rx="2" />
      <path d="M8 20h8M12 16v4" />
    </svg>
  );
}

export function ThemeToggle() {
  const [theme, next] = useTheme();
  return (
    <button
      type="button"
      className="theme-toggle"
      onClick={next}
      aria-label={`Theme: ${THEME_LABEL[theme]}. Switch theme`}
      title={`Theme: ${THEME_LABEL[theme]}`}
    >
      <ThemeIcon theme={theme} />
    </button>
  );
}

export function SkipLink() {
  return (
    <a className="skip-link" href="#main">
      Skip to content
    </a>
  );
}

/** The one kwatch header: the same links on web, docs, blog and app. */
export function SiteHeader({signedIn = false}: {signedIn?: boolean}) {
  return (
    <header className="site-header">
      <a className="brand" href={SITE_URL} aria-label="kwatch home">
        <Mark size={26} />
        <span className="wordmark">kwatch</span>
      </a>
      <nav className="site-nav" aria-label="Site">
        <a href={DOCS_URL}>Docs</a>
        <a href={BLOG_URL}>Blog</a>
        <a href={`${SITE_URL}/pro`}>Pro</a>
        <a href={`${SITE_URL}/support`}>Get help</a>
        {signedIn ? (
          <NavLink to="/account" className="nav-account">Account</NavLink>
        ) : (
          <NavLink to="/signin" className="nav-account">Sign in</NavLink>
        )}
      </nav>
      <ThemeToggle />
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <span>kwatch · source available under ELv2</span>
      <nav aria-label="Footer">
        <a href={DOCS_URL}>Docs</a>
        <a href={BLOG_URL}>Blog</a>
        <a href={GITHUB_URL}>GitHub</a>
        <a href={`${SITE_URL}/support`}>Get help</a>
        <a href={`${SITE_URL}/privacy`}>Privacy</a>
        <a href={`${SITE_URL}/terms`}>Terms</a>
      </nav>
    </footer>
  );
}

/** Centered card used by the sign-in screens and the 404. */
export function Card({children}: {children: ReactNode}) {
  return (
    <>
      <SkipLink />
      <SiteHeader />
      <main id="main" className="center">
        <div className="card">{children}</div>
      </main>
    </>
  );
}

export function Shell() {
  const {data} = useSession();
  const navigate = useNavigate();

  const [signOutError, setSignOutError] = useState('');

  async function signOut(all = false) {
    setSignOutError('');
    try {
      await (all ? logoutAll() : logout());
    } catch (err) {
      // 401 means the session is already gone; anything else may have left it active.
      if ((err as ApiError)?.status !== 401) {
        setSignOutError(
          (err as ApiError)?.code === 'network'
            ? 'Could not sign you out. Check your connection, then try again.'
            : 'Could not sign you out. Try again.',
        );
        return;
      }
    }
    navigate('/signin', {replace: true});
  }

  return (
    <>
      <SkipLink />
      <SiteHeader signedIn />
      <div className="shell">
        <nav className="side" aria-label="App">
          <NavLink to="/licenses">Licenses</NavLink>
          <NavLink to="/help">Get help</NavLink>
          <NavLink to="/account">Account</NavLink>
          <span className="who">
            {data.account.email} ·{' '}
            <button type="button" className="link" onClick={() => signOut()}>
              Sign out
            </button>
            {signOutError && <span className="alert" role="alert">{signOutError}</span>}
          </span>
        </nav>
        <div className="main">
          <main id="main" className="content" tabIndex={-1}>
            <Outlet />
          </main>
          <SiteFooter />
        </div>
      </div>
    </>
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
