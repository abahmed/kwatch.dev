import {render} from '@testing-library/react';
import {MemoryRouter} from 'react-router-dom';
import {vi} from 'vitest';
import App from '../App';
import type {AccountResponse, License} from '../api';

type Reply = {status?: number; body?: unknown};
export type Handler = Reply | ((init: RequestInit) => Reply);

/** Mocks fetch with a "METHOD /path" table; unknown routes answer 404. */
export function mockApi(routes: Record<string, Handler>) {
  const calls: {key: string; init: RequestInit}[] = [];
  const fn = vi.fn(async (url: string, init: RequestInit = {}) => {
    const key = `${init.method ?? 'GET'} ${new URL(url).pathname}`;
    calls.push({key, init});
    const h = routes[key];
    const r = typeof h === 'function' ? h(init) : h;
    if (!r) return new Response(JSON.stringify({error: 'not_found'}), {status: 404});
    return new Response(r.body === undefined ? '' : JSON.stringify(r.body), {status: r.status ?? 200});
  });
  vi.stubGlobal('fetch', fn);
  return {fn, calls};
}

export const license = (over: Partial<License> = {}): License => ({
  lid: 'lic_1',
  plan: 'pro',
  status: 'active',
  issued_at: 1_700_000_000,
  expires_at: 1_800_000_000,
  key_masked: 'KW1-••••••f3a9Qk',
  activation: {cluster: '7c1e04ab', first_seen: 1_700_000_000, last_renew: Math.floor(Date.now() / 1000) - 7200, kwatch_version: '1.0.0', node_count: 6},
  transfers_left: 2,
  ...over,
});

export const account = (over: Partial<AccountResponse> = {}): AccountResponse => ({
  account: {email: 'ab@acme.com', created_at: 1_790_000_000},
  licenses: [],
  trial_available: true,
  trials: {used: 0, limit: 2, scope: 'organization', domain: 'acme.com'},
  ...over,
});

export function renderAt(path: string) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <App />
    </MemoryRouter>,
  );
}
