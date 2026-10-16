import {useEffect, useRef, useState} from 'react';
import {TURNSTILE_SITEKEY} from './config';

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

export function loadTurnstile(): Promise<TurnstileApi> {
  return new Promise((resolve, reject) => {
    if (window.turnstile) return resolve(window.turnstile);
    let script = document.querySelector<HTMLScriptElement>('script[data-kwatch-turnstile]');
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
      if (script) script.dataset.state = 'error';
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
    script.addEventListener('error', onError);
  });
}

/** Renders the Cloudflare check; remount it (change `key`) to get a fresh challenge. */
export function Turnstile({
  onToken,
  onLoadError,
}: {
  onToken: (token: string) => void;
  onLoadError: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [loading, setLoading] = useState(Boolean(TURNSTILE_SITEKEY));

  useEffect(() => {
    if (!TURNSTILE_SITEKEY) return undefined;
    let cancelled = false;
    let id: string | undefined;
    loadTurnstile()
      .then((ts) => {
        if (cancelled || !ref.current) return;
        setLoading(false);
        id = ts.render(ref.current, {
          sitekey: TURNSTILE_SITEKEY,
          callback: onToken,
          'expired-callback': () => onToken(''),
          'error-callback': () => onToken(''),
        });
      })
      .catch(() => {
        if (!cancelled) {
          setLoading(false);
          onLoadError();
        }
      });
    return () => {
      cancelled = true;
      if (id && window.turnstile) window.turnstile.remove(id);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!TURNSTILE_SITEKEY) return null;
  return (
    <div className="check" ref={ref}>
      {loading && <span className="muted small">Loading check…</span>}
    </div>
  );
}
