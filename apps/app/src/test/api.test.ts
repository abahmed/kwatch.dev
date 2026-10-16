import {afterEach, describe, expect, it, vi} from 'vitest';
import {ApiError, apiFetch} from '../api';
import {mockApi} from './helpers';

afterEach(() => vi.unstubAllGlobals());

describe('apiFetch', () => {
  it('sends cookies and JSON to the unversioned API path', async () => {
    const {fn} = mockApi({'POST /auth/start': {body: {ok: true}}});
    await expect(apiFetch('/auth/start', {method: 'POST', body: {email: 'a@b.co'}})).resolves.toEqual({ok: true});
    const [url, init] = fn.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://api.kwatch.dev/auth/start');
    expect(init.credentials).toBe('include');
    expect(init.body).toBe('{"email":"a@b.co"}');
  });

  it('maps a network failure to code "network"', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('down')));
    await expect(apiFetch('/account')).rejects.toMatchObject({status: 0, code: 'network'});
  });

  it('keeps status, code, scope and domain of an error body', async () => {
    mockApi({'POST /account/trial': {status: 409, body: {error: 'trial_limit_reached', scope: 'organization', domain: 'acme.com'}}});
    const err = await apiFetch('/account/trial', {method: 'POST'}).catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({status: 409, code: 'trial_limit_reached', scope: 'organization', domain: 'acme.com'});
  });

  it('survives an error without a JSON body', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('boom', {status: 500})));
    await expect(apiFetch('/account')).rejects.toMatchObject({status: 500, code: undefined});
  });

  it('reports 401 as unauthorized', async () => {
    mockApi({'GET /account': {status: 401, body: {error: 'unauthorized'}}});
    await expect(apiFetch('/account')).rejects.toMatchObject({status: 401, code: 'unauthorized'});
  });
});
