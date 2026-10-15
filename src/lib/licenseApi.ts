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
};

export class ApiError extends Error {
  status: number;
  code?: string;
  constructor(status: number, code?: string) {
    super(code ?? `HTTP ${status}`);
    this.status = status;
    this.code = code;
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
    try {
      code = (await res.json())?.error;
    } catch {
      /* no body */
    }
    throw new ApiError(res.status, code);
  }
  const text = await res.text();
  return (text ? JSON.parse(text) : {}) as T;
}
