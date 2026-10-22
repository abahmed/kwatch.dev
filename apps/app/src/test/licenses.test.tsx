import {act, screen, within} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import type {Cluster} from '../api';
import {fmtLastSeenAgo} from '../format';
import {account, license, mockApi, renderAt} from './helpers';

afterEach(() => vi.unstubAllGlobals());

const now = () => Math.floor(Date.now() / 1000);
const cl = (over: Partial<Cluster> = {}): Cluster => ({
  cluster_uuid: 'uuid-1', id_short: '7c1e04ab', license: 'lic_1', version: '1.0.0', nodes: 3,
  last_seen: now() - 240, ...over,
});
const withClusters = (clusters: Cluster[], licenses = [license()]) =>
  mockApi({'GET /account': {body: account({licenses})}, 'GET /account/clusters': {body: {clusters}}});

describe('/licenses', () => {
  it('shows the empty state and never says trial', async () => {
    mockApi({'GET /account': {body: account()}});
    const {container} = renderAt('/licenses');
    expect(await screen.findByRole('heading', {name: 'Get your free Pro license.'})).toBeInTheDocument();
    expect(screen.getByText(/shared across acme.com/)).toBeInTheDocument();
    expect(screen.getByRole('button', {name: 'Get a free Pro license'})).toBeInTheDocument();
    expect(container.textContent).not.toMatch(/trial/i);
  });

  it('maps the organization limit error to the designed message', async () => {
    mockApi({
      'GET /account': {body: account()},
      'POST /account/trial': {status: 409, body: {error: 'trial_limit_reached', scope: 'organization', domain: 'acme.com'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Get a free Pro license'}));
    expect(await screen.findByText('acme.com has used both free Pro clusters')).toBeInTheDocument();
  });

  it('maps the account limit error', async () => {
    mockApi({
      'GET /account': {body: account({trials: {used: 0, limit: 2, scope: 'account'}})},
      'POST /account/trial': {status: 409, body: {error: 'trial_limit_reached', scope: 'account'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Get a free Pro license'}));
    expect(await screen.findByText('You have used both free Pro clusters')).toBeInTheDocument();
  });

  it('lists licenses with the counter, masked key and cluster details', async () => {
    mockApi({
      'GET /account': {
        body: account({
          trial_available: false,
          trials: {used: 2, limit: 2, scope: 'organization', domain: 'acme.com'},
          licenses: [license(), license({lid: 'lic_2', activation: null, key_masked: 'KW1-••••••b81Lmp'})],
        }),
      },
      'GET /account/clusters': {body: {clusters: [cl({})]}},
    });
    renderAt('/licenses');
    expect(await screen.findByText(/free Pro licenses used · acme.com/)).toHaveTextContent('2 of 2 free Pro licenses used · acme.com');
    const first = await screen.findByRole('region', {name: 'License lic_1'});
    expect(within(first).getByText(/KW1-••••••f3a9Qk/)).toBeInTheDocument();
    expect(within(first).getByText('active')).toBeInTheDocument();
    expect(within(first).getByText(/Free during early access · ends/)).toBeInTheDocument();
    expect(within(await screen.findByRole('group', {name: 'Cluster for license lic_1'})).getByText('7c1e04ab')).toBeInTheDocument();
    const second = screen.getByRole('region', {name: 'License lic_2'});
    expect(within(second).getByText(/Not attached yet/)).toBeInTheDocument();
    expect(within(second).queryByRole('button', {name: 'Move to another cluster'})).toBeNull();
    expect(screen.queryByRole('button', {name: 'Get a free Pro license'})).not.toBeInTheDocument();
  });

  it('orders actions Copy, Show, Move, Replace with no toggle state or Signal', async () => {
    withClusters([cl()]);
    renderAt('/licenses');
    const card = await screen.findByRole('region', {name: 'License lic_1'});
    await within(card).findByText('7c1e04ab');
    const names = within(card).getAllByRole('button').map((b) => b.getAttribute('aria-label') ?? b.textContent);
    expect(names).toEqual(['Copy key', 'Show key', 'Move to another cluster', 'Replace key']);
    expect(within(card).getByRole('group', {name: 'Key actions'})).toBeInTheDocument();
    expect(within(card).getByRole('group', {name: 'Manage license'})).toBeInTheDocument();
    expect(within(card).getByRole('button', {name: 'Show key'})).not.toHaveAttribute('aria-pressed');
    expect(card.querySelector('.btn-signal')).toBeNull();
  });

  it('shows Showing while the key loads', async () => {
    mockApi({'GET /account': {body: account({licenses: [license()]})}});
    const base = globalThis.fetch;
    vi.stubGlobal('fetch', (url: RequestInfo | URL, init?: RequestInit) =>
      String(url).endsWith('/key') ? new Promise<Response>(() => {}) : base(url, init),
    );
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Show key'}));
    const b = await screen.findByRole('button', {name: 'Showing…'});
    expect(b).toBeDisabled();
    expect(b).toHaveAttribute('aria-busy', 'true');
  });

  it('shows the key on demand and forgets it on hide', async () => {
    const {calls} = mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'POST /account/licenses/lic_1/key': {body: {lid: 'lic_1', key: 'KW1-abcdefghijklmnopqrstuvwxyz-f3a9Qk'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    const card = await screen.findByRole('region', {name: 'License lic_1'});
    expect(calls.some((c) => c.key.endsWith('/key'))).toBe(false);
    await user.click(within(card).getByRole('button', {name: 'Show key'}));
    expect(await within(card).findByText(/KW1-abcdefghijklmnopqrstuvwxyz-f3a9Qk/)).toBeInTheDocument();
    await user.click(within(card).getByRole('button', {name: 'Hide key'}));
    expect(card.textContent).not.toContain('abcdefghijkl');
    expect(card.textContent).toContain('KW1-••••••f3a9Qk');
  });

  it('copies without revealing', async () => {
    const writeText = vi.fn(async () => {});
    mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'POST /account/licenses/lic_1/key': {body: {lid: 'lic_1', key: 'KW1-fullkey'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    const card = await screen.findByRole('region', {name: 'License lic_1'});
    vi.spyOn(navigator.clipboard, 'writeText').mockImplementation(writeText);
    await user.click(within(card).getByRole('button', {name: 'Copy key'}));
    expect(await within(card).findByRole('button', {name: 'Copied'})).toBeInTheDocument();
    expect(writeText).toHaveBeenCalledWith('KW1-fullkey');
    expect(card.textContent).not.toContain('fullkey');
  });

  it('maps key reveal errors', async () => {
    mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'POST /account/licenses/lic_1/key': {status: 429, body: {error: 'rate_limited'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Show key'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('Too many key requests');
  });

  it('falls back to masking a legacy full key', async () => {
    mockApi({'GET /account': {body: account({licenses: [license({key_masked: undefined, key: 'KW1-abcdefghijklmnopqrstuvwxyz-f3a9Qk'})]})}});
    renderAt('/licenses');
    const card = await screen.findByRole('region', {name: 'License lic_1'});
    expect(card.textContent).toContain('KW1-••••••f3a9Qk');
    expect(card.textContent).not.toContain('abcdefgh');
  });

  it('shows the new free license key once', async () => {
    let created = false;
    mockApi({
      'GET /account': () => ({body: account({licenses: created ? [license()] : []})}),
      'POST /account/trial': () => {
        created = true;
        return {body: {license: license(), key: 'KW1-trialfullkey'}};
      },
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Get a free Pro license'}));
    const card = await screen.findByRole('region', {name: 'License lic_1'});
    expect(card).toHaveTextContent('KW1-trialfullkey');
    await user.click(within(card).getByRole('button', {name: 'Hide key'}));
    expect(card).not.toHaveTextContent('trialfullkey');
  });

  it('moves a license to another cluster', async () => {
    const { calls } = mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'GET /account/clusters': {body: {clusters: [cl()]}},
      'POST /account/licenses/lic_1/transfer': {body: {ok: true, released: true, transfers_left: 1}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Move to another cluster'}));
    expect(screen.getByText(/2 moves left this month/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', {name: 'Move license'}));
    expect(await screen.findByRole('status')).toHaveTextContent('License released');
    expect(calls.some((c) => c.key === 'POST /account/licenses/lic_1/transfer')).toBe(true);
  });

  it('replaces the key only after the confirm', async () => {
    const { calls } = mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'POST /account/licenses/lic_1/regenerate': {body: {key: 'KW1-brandnewkey-000000'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Replace key'}));
    expect(calls.some((c) => c.key.endsWith('/regenerate'))).toBe(false);
    const dialog = screen.getByRole('dialog', {name: 'Replace key'});
    expect(dialog).toHaveTextContent('The old key stops working');
    await user.click(within(dialog).getByRole('button', {name: 'Replace key'}));
    expect(await screen.findByText(/KW1-brandnewkey-000000/)).toBeInTheDocument();
  });

  it('cancelling the replace confirm makes no request', async () => {
    const { calls } = mockApi({'GET /account': {body: account({licenses: [license()]})}});
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Replace key'}));
    await user.click(screen.getByRole('button', {name: 'Cancel'}));
    expect(calls.filter((c) => c.key.startsWith('POST'))).toHaveLength(0);
  });

  it('shows the move limit message', async () => {
    mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'GET /account/clusters': {body: {clusters: [cl()]}},
      'POST /account/licenses/lic_1/transfer': {status: 429, body: {error: 'transfer_limit'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Move to another cluster'}));
    await user.click(screen.getByRole('button', {name: 'Move license'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('No moves left');
  });

  it('shows version, nodes and last seen, with no status pill or check-in copy', async () => {
    withClusters([cl(), cl({license: 'lic_x', id_short: 'zzzz', version: null, nodes: null})], [license(), license({lid: 'lic_x', issued_at: 5})]);
    renderAt('/licenses');
    expect(await screen.findByText('7c1e04ab')).toHaveClass('mono');
    expect(screen.getByText('v1.0.0')).toBeInTheDocument();
    expect(screen.getByText('3 nodes')).toBeInTheDocument();
    expect(screen.getAllByText(/^Last seen /).length).toBe(2);
    expect(screen.queryByText(/Inactive|Stopped|Waiting|check-in/i)).toBeNull();
    expect(screen.getByRole('link', {name: /dead man.s switch/})).toHaveAttribute('href', 'https://docs.kwatch.dev/heartbeat-monitor-configuration');
    expect(screen.queryByText(/reach kwatch.dev/)).toBeNull();
  });

  it('shows relative last seen, keeps the UTC tooltip and refreshes every minute', async () => {
    vi.useFakeTimers({shouldAdvanceTime: true, toFake: ['Date', 'setInterval', 'clearInterval']});
    try {
      const t = Math.floor(Date.now() / 1000);
      withClusters([cl({last_seen: t - 20 * 60})]);
      renderAt('/licenses');
      const el = await screen.findByText('Last seen 20 min ago');
      expect(el).toHaveAttribute('title', expect.stringMatching(/^\d{4}-\d\d-\d\d \d\d:\d\d UTC$/));
      await act(async () => { await vi.advanceTimersByTimeAsync(60_000); });
      expect(screen.getByText('Last seen 21 min ago')).toBeInTheDocument();
    } finally {
      vi.useRealTimers();
    }
  });

  it('formats last-seen ages', () => {
    const n = 1_000_000 * 1000;
    expect(fmtLastSeenAgo(1_000_000 - 30, n)).toBe('just now');
    expect(fmtLastSeenAgo(1_000_000 - 3 * 3600, n)).toBe('3 h ago');
    expect(fmtLastSeenAgo(1_000_000 - 86400, n)).toBe('1 day ago');
    expect(fmtLastSeenAgo(1_000_000 - 2 * 86400, n)).toBe('2 days ago');
  });

  it('uses srv_time to correct clock skew', async () => {
    const t = now();
    mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'GET /account/clusters': {body: {clusters: [cl({last_seen: t - 600})], srv_time: t + 3600}},
    });
    renderAt('/licenses');
    expect(await screen.findByText('Last seen 1 h ago')).toBeInTheDocument();
  });

  it('sorts non-active licenses first, then newest first', async () => {
    const ls = [
      license({lid: 'lic_old', issued_at: 100}),
      license({lid: 'lic_new', issued_at: 200}),
      license({lid: 'lic_exp', status: 'expired', issued_at: 50}),
    ];
    withClusters([cl({license: 'lic_old'}), cl({license: 'lic_new'})], ls);
    renderAt('/licenses');
    await screen.findAllByText('7c1e04ab');
    const order = screen.getAllByRole('region').map((r) => r.getAttribute('aria-label'));
    expect(order).toEqual(['License lic_exp', 'License lic_new', 'License lic_old']);
    expect(screen.getByText(/This license ended on/)).toBeInTheDocument();
  });

  it('keeps the license when clusters fail and retries', async () => {
    let fail = true;
    mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'GET /account/clusters': () => (fail ? {status: 500, body: {}} : {body: {clusters: [cl()]}}),
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    expect(await screen.findByText('Cluster status unavailable. Try again.')).toBeInTheDocument();
    expect(screen.getByRole('region', {name: 'License lic_1'})).toBeInTheDocument();
    expect(screen.queryByText(/Not attached yet/)).toBeNull();
    fail = false;
    await user.click(screen.getByRole('button', {name: 'Try again'}));
    expect(await screen.findByText('7c1e04ab')).toBeInTheDocument();
  });

  it('offers another license while under the limit, with no Signal', async () => {
    withClusters([cl()]);
    const {container} = renderAt('/licenses');
    const b = await screen.findByRole('button', {name: 'Get another free Pro license'});
    expect(b.className).not.toMatch(/signal/);
    expect(container.querySelector('.btn-signal')).toBeNull();
  });

  it('refresh reloads clusters', async () => {
    const {calls} = withClusters([]);
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Refresh'}));
    await screen.findByRole('region', {name: 'License lic_1'});
    expect(calls.filter((c) => c.key === 'GET /account/clusters').length).toBeGreaterThanOrEqual(2);
  });

  it('refresh shows a busy state, then Last refreshed', async () => {
    withClusters([]);
    const user = userEvent.setup();
    renderAt('/licenses');
    const status = await screen.findByText('Last refreshed just now');
    expect(status).not.toHaveAttribute('aria-live');
    const sr = document.querySelector('.sr-only[aria-live="polite"]') as HTMLElement;
    expect(sr).toHaveAttribute('aria-live', 'polite');
    expect(sr).toBeEmptyDOMElement();
    expect(status).toHaveAttribute('title', expect.stringMatching(/UTC$/));
    await user.click(screen.getByRole('button', {name: 'Refresh'}));
    const busy = screen.getByRole('button', {name: /Refreshing/});
    expect(busy).toBeDisabled();
    expect(busy).toHaveAttribute('aria-busy', 'true');
    expect(document.querySelector('div[aria-busy="true"] [aria-label="License lic_1"]')).not.toBeNull();
    expect(await screen.findByRole('button', {name: 'Refresh'})).toBeEnabled();
    expect(document.querySelector('[aria-busy="true"]')).toBeNull();
    expect(document.querySelector('.sr-only[aria-live]')).toHaveTextContent('Refreshed');
  });

  it('refresh error shows an alert and keeps the old timestamp', async () => {
    let n = 0;
    mockApi({
      'GET /account': () => (++n === 1 ? {body: account({licenses: [license()]})} : {status: 500, body: {}}),
      'GET /account/clusters': {body: {clusters: []}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await screen.findByText('Last refreshed just now');
    await user.click(screen.getByRole('button', {name: 'Refresh'}));
    expect(await screen.findAllByText('Could not refresh. Check your connection and try again.')).toHaveLength(2);
    expect(document.querySelector('.sr-only[aria-live]')).toHaveTextContent('Could not refresh');
    expect(screen.getAllByText(/Could not refresh/)).toHaveLength(2);
    expect(screen.getByText('Last refreshed just now')).toBeInTheDocument();
    expect(screen.getByRole('region', {name: 'License lic_1'})).toBeInTheDocument();
  });

  it('/clusters redirects to /licenses and the nav has one item', async () => {
    withClusters([cl()]);
    renderAt('/clusters');
    expect(await screen.findByRole('heading', {name: 'Licenses'})).toBeInTheDocument();
    expect(screen.queryByRole('link', {name: 'Clusters'})).toBeNull();
    expect(screen.getAllByRole('link', {name: 'Licenses'})).toHaveLength(1);
  });

  describe('update available', () => {
    const withLatest = (version: string | null, latest?: string | null) =>
      mockApi({
        'GET /account': {body: account({licenses: [license()]})},
        'GET /account/clusters': {body: {clusters: [cl({version})], ...(latest === undefined ? {} : {latest_version: latest})}},
      });
    const run = async (version: string | null, latest?: string | null) => {
      withLatest(version, latest);
      renderAt('/licenses');
      await screen.findByText('7c1e04ab');
    };
    it('shows a badge linking to the upgrade page when older', async () => {
      await run('1.0.0', '1.0.3');
      const a = await screen.findByRole('link', {name: 'Update available: v1.0.3'});
      expect(a.getAttribute('href')).toMatch(/\/update$/);
    });
    it('shows a badge for an rc older than the release', async () => {
      await run('1.0.3-rc.1', '1.0.3');
      expect(await screen.findByText('Update available: v1.0.3')).toBeInTheDocument();
    });
    it.each([['1.0.3', '1.0.3'], ['1.1.0', '1.0.3'], ['1.0.3', null], ['1.0.0', undefined], ['dev', '1.0.3'], [null, '1.0.3']])(
      'shows nothing for %s vs %s', async (v, latest) => {
        await run(v, latest);
        expect(screen.queryByText(/Update available/)).toBeNull();
      });
  });
});
