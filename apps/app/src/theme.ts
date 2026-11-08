import {useCallback, useState} from 'react';

export type Theme = 'system' | 'light' | 'dark';
const KEY = 'kwatch-theme';

export function readTheme(): Theme {
  try {
    const t = localStorage.getItem(KEY);
    if (t === 'light' || t === 'dark') return t;
  } catch {
    /* storage blocked: stay on System */
  }
  return 'system';
}

export function applyTheme(theme: Theme) {
  const root = document.documentElement;
  if (theme === 'system') root.removeAttribute('data-theme');
  else root.setAttribute('data-theme', theme);
  try {
    if (theme === 'system') localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, theme);
  } catch {
    /* storage blocked: the choice lasts for this page only */
  }
}

const ORDER: Theme[] = ['system', 'light', 'dark'];

export function useTheme(): [Theme, () => void] {
  const [theme, setTheme] = useState<Theme>(readTheme);
  const next = useCallback(() => {
    const n = ORDER[(ORDER.indexOf(theme) + 1) % ORDER.length];
    applyTheme(n);
    setTheme(n);
  }, [theme]);
  return [theme, next];
}
