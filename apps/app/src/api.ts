import {API_URL} from './config';
import {maskKey} from './format';

export type License = {
  lid: string;
  plan: 'pro';
  status: 'active' | 'revoked' | 'suspended' | 'expired';
  issued_at: number;
  expires_at: number;
  /** Masked key for display. Older API versions sent the full `key` instead. */
  key_masked?: string | null;
  /** Legacy: present only on API versions before masking. Never stored. */
  key?: string;
  activation: null | {
    cluster: string;
    first_seen: number;
    last_renew: number;
    kwatch_version: string;
    node_count: number;
  };
  transfers_left: number;
};

export type FreeInfo = {
  used: number;
  limit: number;
  scope: 'account' | 'organization';
  domain?: string;
};

export type AccountResponse = {
  account: {email: string; created_at: number};
  licenses: License[];
  trial_available: boolean;
  trials?: FreeInfo;
};


/** GET /account/clusters row (kwatch-api). Times are unix seconds. */
export type Cluster = {
  license: string;
  cluster_uuid: string;
  id_short: string;
  version: string | null;
  nodes: number | null;
  /** Unix seconds of the last anonymous license check. */
  last_seen: number;
};

export type SupportRequest = {license: string; cluster_uuid?: string; topic: string; message: string};

export class ApiError extends Error {
  status: number;
  code?: string;
  /** Extra fields of a limit error: scope and domain. */
  scope?: string;
  domain?: string;
  constructor(status: number, code?: string, extra: {scope?: string; domain?: string} = {}) {
    super(code ?? `HTTP ${status}`);
    this.status = status;
    this.code = code;
    this.scope = extra.scope;
    this.domain = extra.domain;
  }
}

export async function apiFetch<T = unknown>(
  path: string,
  init: {method?: string; body?: unknown} = {},
): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      method: init.method ?? 'GET',
      credentials: 'include',
      headers: init.body ? {'Content-Type': 'application/json'} : undefined,
      body: init.body ? JSON.stringify(init.body) : undefined,
    });
  } catch {
    throw new ApiError(0, 'network');
  }
  if (!res.ok) {
    let code: string | undefined;
    let extra: {scope?: string; domain?: string} = {};
    try {
      const body = await res.json();
      code = typeof body?.error === 'string' ? body.error : undefined;
      extra = {
        scope: typeof body?.scope === 'string' ? body.scope : undefined,
        domain: typeof body?.domain === 'string' ? body.domain : undefined,
      };
    } catch {
      /* no body */
    }
    throw new ApiError(res.status, code, extra);
  }
  const text = await res.text();
  return (text ? JSON.parse(text) : {}) as T;
}

const post = (path: string, body?: unknown) => apiFetch(path, {method: 'POST', body});
const lic = (lid: string, action: string) => `/account/licenses/${encodeURIComponent(lid)}/${action}`;

export const getAccount = () => apiFetch<AccountResponse>('/account');
export const startSignin = (email: string, turnstileToken: string) =>
  post('/auth/start', {email, turnstile_token: turnstileToken});
export const verifySignin = (t: string) => post('/auth/verify', {t});
export const logout = () => post('/auth/logout');
export const getFreeLicense = () => apiFetch<{license?: License; key?: string}>('/account/trial', {method: 'POST'});
export const moveLicense = (lid: string) => post(lic(lid, 'transfer'));
export const replaceKey = (lid: string) => apiFetch<{key?: string}>(lic(lid, 'regenerate'), {method: 'POST'});
export const deleteAccount = () => apiFetch('/account', {method: 'DELETE'});
export const revealKey = (lid: string) => apiFetch<{lid: string; key: string}>(lic(lid, 'key'), {method: 'POST'});

/** Masked key text for a license view; tolerates the pre-masking API shape. */
export function displayKey(l: License): string {
  if (l.key_masked) return l.key_masked;
  return l.key ? maskKey(l.key) : '';
}
export const getClusters = () => apiFetch<{clusters: Cluster[]; srv_time?: number}>('/account/clusters');
export const sendSupport = (req: SupportRequest) => apiFetch<{ref: string}>('/support', {method: 'POST', body: req});
