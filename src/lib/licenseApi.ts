import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

export type License = {
  lid: string;
  plan: 'trial' | 'pro';
  status: 'active' | 'revoked' | 'suspended' | 'expired';
  issued_at: number;
  expires_at: number;
  key: string;
  activation: null | {
    cluster: string;
    first_seen: number;
    last_renew: number;
    kwatch_version: string;
    node_count: number;
  };
  transfers_left: number;
};

export type AccountResponse = {
  account: {email: string; created_at: number};
  licenses: License[];
  trial_available: boolean;
  trials?: TrialInfo;
};

export type TrialInfo = {
  used: number;
  limit: number;
  scope: 'account' | 'organization';
  domain?: string;
};

export class ApiError extends Error {
  status: number;
  code?: string;
  /** Extra fields of an error response, e.g. trial_limit_reached has scope and domain. */
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

export function useSiteConfig(): {apiUrl: string; turnstileSiteKey: string} {
  const {siteConfig} = useDocusaurusContext();
  const fields = siteConfig.customFields as {
    apiUrl?: string;
    turnstileSiteKey?: string;
  };
  return {
    apiUrl: (fields.apiUrl || 'https://api.kwatch.dev').replace(/\/+$/, ''),
    turnstileSiteKey: fields.turnstileSiteKey || '',
  };
}

export async function apiFetch<T = unknown>(
  apiUrl: string,
  path: string,
  init: {method?: string; body?: unknown} = {},
): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${apiUrl}${path}`, {
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
      code = body?.error;
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
