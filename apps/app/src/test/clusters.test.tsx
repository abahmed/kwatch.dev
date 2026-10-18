import {screen, within} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import type {Cluster} from '../api';
import {account, license, mockApi, renderAt} from './helpers';

afterEach(() => vi.unstubAllGlobals());

const now = () => Math.floor(Date.now() / 1000);
const cl = (over: Partial<Cluster>): Cluster => ({
  name: 'prod', cluster_uuid: 'uuid-1', id_short: '7c1e04ab', license: 'lic_1', version: '1.0.0', nodes: 3,
  last_seen: now() - 240, checkins: true, state: 'ok', ...over,
});

async function show(clusters: Cluster[]) {
  mockApi({'GET /account': {body: account({licenses: [license()]})}, 'GET /account/clusters': {body: {clusters}}});
  renderAt('/clusters');
  await screen.findByRole('heading', {name: 'Clusters'});
}

describe('/clusters', () => {
  it('healthy', async () => {
    await show([cl({})]);
    expect(await screen.findAllByText('Checking in')).not.toHaveLength(0);
    expect(screen.getAllByText('4 minutes ago').length).toBeGreaterThan(0);
  });
  it('waiting', async () => {
    await show([cl({state: 'waiting', last_seen: null})]);
    expect(await screen.findAllByText('Waiting')).not.toHaveLength(0);
    expect(screen.getAllByText('Not yet').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Add the key in the installer, then wait up to 15 minutes.').length).toBeGreaterThan(0);
  });
  it('silent shows time since last ping + 20 min', async () => {
    const last = Date.UTC(2026, 9, 1, 13, 42) / 1000;
    await show([cl({state: 'silent', last_seen: last, silent_since: last + 1800})]);
    expect(await screen.findAllByText('Silent since 14:12 UTC')).not.toHaveLength(0);
    expect(screen.getAllByText(/kwatch stopped talking/).length).toBeGreaterThan(0);
  });
  it('stopped is neutral and not silent', async () => {
    const at = Date.UTC(2026, 9, 1, 18, 5) / 1000;
    await show([cl({state: 'stopped', stopped_since: at})]);
    const pill = (await screen.findAllByText('Stopped · since 18:05 UTC'))[0];
    expect(pill.className).not.toMatch(/silent/);
    expect(screen.getAllByText(/shut down cleanly/).length).toBeGreaterThan(0);
    expect(screen.queryByText(/Silent/)).toBeNull();
  });
  it('back within 24h', async () => {
    const rec = Date.UTC(2026, 9, 1, 14, 41) / 1000;
    await show([cl({state: 'back', recovered_at: now() - 3600, quiet_seconds: 69 * 60, last_seen: now() - 5})]);
    expect(await screen.findAllByText(/^Back at \d\d:\d\d UTC$/)).not.toHaveLength(0);
    expect(screen.getAllByText(/Silent for 39 minutes/).length).toBeGreaterThan(0);
    expect(rec).toBeGreaterThan(0);
  });
  it('old recovery is plain healthy', async () => {
    await show([cl({state: 'back', recovered_at: now() - 3 * 86400, quiet_seconds: 3600})]);
    expect(await screen.findAllByText('Checking in')).not.toHaveLength(0);
  });
  it('check-ins off and not attached', async () => {
    await show([cl({state: 'off'}), cl({state: 'detached', id_short: 'aaaa1111'})]);
    expect(await screen.findAllByText('Check-ins off')).not.toHaveLength(0);
    expect(screen.getAllByText('Not tracked').length).toBeGreaterThan(0);
    expect(screen.getAllByText('Not attached').length).toBeGreaterThan(0);
  });
  it('empty', async () => {
    await show([]);
    expect(await screen.findByText(/No clusters yet/)).toBeInTheDocument();
    expect(screen.getByText('How this works')).toBeInTheDocument();
  });
  it('error', async () => {
    mockApi({'GET /account': {body: account()}, 'GET /account/clusters': {status: 500, body: {}}});
    renderAt('/clusters');
    expect(await screen.findByText(/Could not load your clusters/)).toBeInTheDocument();
  });
  it('refresh reloads', async () => {
    const {calls} = mockApi({'GET /account': {body: account()}, 'GET /account/clusters': {body: {clusters: []}}});
    renderAt('/clusters');
    await user().click(await screen.findByRole('button', {name: 'Refresh'}));
    expect(calls.filter((c) => c.key === 'GET /account/clusters').length).toBe(2);
    void within;
  });
});
const user = () => userEvent.setup();
