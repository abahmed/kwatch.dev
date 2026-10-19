import {useCallback, useEffect, useState} from 'react';
import {getClusters} from './api';
import type {Cluster} from './api';

type State = {clusters: Cluster[] | null; failed: boolean; nowMs: number};

/** Loads the account's clusters; reloads when the tab regains focus. No polling. */
export function useClusters() {
  const [state, setState] = useState<State>({clusters: null, failed: false, nowMs: 0});

  const load = useCallback(async () => {
    try {
      const r = await getClusters();
      setState({clusters: r.clusters ?? [], failed: false, nowMs: Date.now()});
    } catch {
      setState((s) => ({...s, failed: true, nowMs: Date.now()}));
    }
  }, []);

  useEffect(() => {
    const first = () => void load();
    // Deferred so the first load is not a synchronous setState in the effect body.
    const t = setTimeout(first, 0);
    window.addEventListener('focus', first);
    return () => {
      clearTimeout(t);
      window.removeEventListener('focus', first);
    };
  }, [load]);

  return {clusters: state.clusters, failed: state.failed, nowMs: state.nowMs, reload: load};
}
