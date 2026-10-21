import {useCallback, useEffect, useState} from 'react';
import {getClusters} from './api';
import type {Cluster} from './api';
import {useRefreshOnReturn} from './useRefreshOnReturn';

type State = {clusters: Cluster[] | null; failed: boolean; nowMs: number; skewMs: number; latest: string | null};

/** Loads the account's clusters; reloads quietly when the person returns to the tab. No polling. */
export function useClusters() {
  const [state, setState] = useState<State>({clusters: null, failed: false, nowMs: 0, skewMs: 0, latest: null});

  const load = useCallback(async () => {
    try {
      const r = await getClusters();
      const nowMs = Date.now();
      // Server minus local clock, so relative times hold when the device clock is off.
      const skewMs = r.srv_time ? r.srv_time * 1000 - nowMs : 0;
      setState({clusters: r.clusters ?? [], failed: false, nowMs, skewMs, latest: r.latest_version ?? null});
      return true;
    } catch {
      setState((s) => ({...s, failed: true, nowMs: Date.now()}));
      return false;
    }
  }, []);

  useEffect(() => {
    // Deferred so the first load is not a synchronous setState in the effect body.
    const t = setTimeout(() => void load(), 0);
    return () => clearTimeout(t);
  }, [load]);
  useRefreshOnReturn(() => void load());

  return {clusters: state.clusters, failed: state.failed, nowMs: state.nowMs, skewMs: state.skewMs, latest: state.latest, reload: load};
}
