import {useEffect, useRef} from 'react';

export const REFRESH_MIN_MS = 15_000;

/**
 * Calls cb when the person returns to the tab (visibilitychange to visible, or window focus).
 * Both events together fire once; at most one call per 15s; never while hidden. No polling.
 */
export function useRefreshOnReturn(cb: () => void) {
  const ref = useRef(cb);
  useEffect(() => {
    ref.current = cb;
  });
  useEffect(() => {
    let last = Date.now(); // the initial load just happened
    const onReturn = () => {
      if (document.hidden) return;
      const now = Date.now();
      if (now - last < REFRESH_MIN_MS) return;
      last = now;
      ref.current();
    };
    document.addEventListener('visibilitychange', onReturn);
    window.addEventListener('focus', onReturn);
    return () => {
      document.removeEventListener('visibilitychange', onReturn);
      window.removeEventListener('focus', onReturn);
    };
  }, []);
}
