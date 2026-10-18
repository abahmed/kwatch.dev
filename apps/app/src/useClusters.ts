import {useCallback, useEffect, useState} from 'react';
import {getClusters} from './api';
import type {Cluster} from './api';

/** Loads the account's clusters; reloads when the tab regains focus. No polling. */
export function useClusters() {
  const [clusters, setClusters] = useState<Cluster[] | null>(null);
  const [failed, setFailed] = useState(false);

  const load = useCallback(async () => {
    try {
      setClusters((await getClusters()).clusters ?? []);
      setFailed(false);
    } catch {
      setFailed(true);
    }
  }, []);

  useEffect(() => {
    void load();
    const onFocus = () => void load();
    window.addEventListener('focus', onFocus);
    return () => window.removeEventListener('focus', onFocus);
  }, [load]);

  return {clusters, failed, reload: load};
}
