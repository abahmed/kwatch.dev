import {screen, waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {account, license, mockApi, renderAt} from './helpers';

afterEach(() => vi.unstubAllGlobals());

const base = {
  'GET /account': {body: account({licenses: [license()]})},
  'GET /account/clusters': {
    body: {clusters: [{id_short: '7c1e04ab', cluster_uuid: 'uuid-1', license: 'lic_1', version: '1.0.0', nodes: 3, last_seen: Math.floor(Date.now() / 1000) - 60}]},
  },
};
const text = 'The alerts never arrive in Slack since upgrading.';

async function fill(user: ReturnType<typeof userEvent.setup>) {
  await user.type(await screen.findByLabelText('Tell us what happened'), text);
}

describe('/help', () => {
  it('prefills email and lists clusters', async () => {
    mockApi(base);
    renderAt('/help');
    expect(await screen.findByText('Reply to')).toBeInTheDocument();
    expect(screen.getByText('ab@acme.com')).toBeInTheDocument();
    expect(await screen.findByRole('option', {name: /Cluster 7c1e04ab/})).toBeInTheDocument();
  });
  it('non-Pro sees the GitHub route', async () => {
    mockApi({'GET /account': {body: account({licenses: [license({status: 'expired'})]})}});
    renderAt('/help');
    expect(await screen.findByText('Get help is for Pro. Community support is on GitHub.')).toBeInTheDocument();
    expect(screen.getByRole('link', {name: 'Open an issue'})).toBeInTheDocument();
  });
  it('validates length and disables send', async () => {
    mockApi(base);
    const user = userEvent.setup();
    renderAt('/help');
    const send = await screen.findByRole('button', {name: 'Send request'});
    expect(send).toBeDisabled();
    await user.type(screen.getByLabelText('Tell us what happened'), 'short');
    await user.tab();
    expect(screen.getByText('Please write at least 20 characters so we can help.')).toBeInTheDocument();
    expect(send).toBeDisabled();
  });
  it('sends and shows the success screen', async () => {
    const {calls} = mockApi({...base, 'POST /support': {status: 202, body: {ref: 'KW-4F7A2C'}}});
    const user = userEvent.setup();
    renderAt('/help');
    await fill(user);
    await user.click(screen.getByRole('button', {name: 'Send request'}));
    expect(await screen.findByRole('heading', {name: 'Request sent'})).toHaveFocus();
    expect(screen.getByText('KW-4F7A2C')).toBeInTheDocument();
    expect(screen.getByText(/We reply by email to ab@acme.com/)).toBeInTheDocument();
    expect(screen.getByText('Reply with your diagnostics file attached.')).toBeInTheDocument();
    const body = JSON.parse(String(calls.find((c) => c.key === 'POST /support')!.init.body));
    expect(body).toEqual({license: 'lic_1', topic: 'installing', message: text});
  });
  it.each([
    [429, /You have used today's requests/],
    [503, /Help is at capacity/],
    [500, /Nothing was sent. Try again, or email support@kwatch.dev/],
  ])('error %i', async (status, re) => {
    mockApi({...base, 'POST /support': {status, body: {}}});
    const user = userEvent.setup();
    renderAt('/help');
    await fill(user);
    await user.click(screen.getByRole('button', {name: 'Send request'}));
    expect(await screen.findByRole('alert')).toHaveTextContent(re);
    expect(screen.getByRole('button', {name: 'Send request'})).toBeEnabled();
  });
  it('offline error', async () => {
    const m = mockApi(base);
    const user = userEvent.setup();
    renderAt('/help');
    await fill(user);
    m.fn.mockRejectedValueOnce(new TypeError('offline'));
    await user.click(screen.getByRole('button', {name: 'Send request'}));
    expect(await screen.findByRole('alert')).toHaveTextContent(/could not reach the kwatch service/);
  });
  it('not Pro on server (403)', async () => {
    mockApi({...base, 'POST /support': {status: 403, body: {error: 'not_pro'}}});
    const user = userEvent.setup();
    renderAt('/help');
    await fill(user);
    await user.click(screen.getByRole('button', {name: 'Send request'}));
    expect(await screen.findByRole('heading', {name: 'Get help'})).toBeInTheDocument();
    expect(screen.getByText('Get help is for Pro. Community support is on GitHub.')).toBeInTheDocument();
  });
  it('401 redirects to sign in', async () => {
    mockApi({...base, 'POST /support': {status: 401, body: {}}});
    const user = userEvent.setup();
    renderAt('/help');
    await fill(user);
    await user.click(screen.getByRole('button', {name: 'Send request'}));
    await waitFor(() => expect(screen.queryByRole('button', {name: 'Send request'})).not.toBeInTheDocument());
  });
  it('shows the new copy', async () => {
    mockApi(base);
    renderAt('/help');
    expect(await screen.findByText('Diagnostics go in your reply, not in this form.')).toBeInTheDocument();
    expect(screen.getByRole('link', {name: 'support@kwatch.dev'})).toHaveAttribute('href', 'mailto:support@kwatch.dev');
    expect(screen.getByText('20 characters minimum')).toBeInTheDocument();
    expect(screen.getByRole('option', {name: 'Check-ins'})).toBeInTheDocument();
  });
});
