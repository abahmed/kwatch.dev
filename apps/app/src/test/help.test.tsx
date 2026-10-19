import {screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {account, license, mockApi, renderAt} from './helpers';

afterEach(() => vi.unstubAllGlobals());

const base = {
  'GET /account': {body: account({licenses: [license()]})},
  'GET /account/clusters': {
    body: {clusters: [{name: 'prod', id_short: '7c1e04ab', cluster_uuid: 'uuid-1', license: 'lic_1', version: '1.0.0', nodes: 3, last_seen: Math.floor(Date.now() / 1000) - 60, checkins: true, state: 'ok'}]},
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
    expect(await screen.findByLabelText('Your email')).toHaveValue('ab@acme.com');
    expect(await screen.findByRole('option', {name: /prod \(7c1e04ab/})).toBeInTheDocument();
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
    expect(screen.getByText(/We will reply by e-mail to ab@acme.com/)).toBeInTheDocument();
    const body = JSON.parse(String(calls.find((c) => c.key === 'POST /support')!.init.body));
    expect(body).toEqual({license: 'lic_1', topic: 'installing', message: text});
  });
  it.each([
    [429, /You have sent 3 requests today/],
    [503, /Support is busy/],
    [500, /We could not send your request. Nothing was sent/],
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
    expect(await screen.findByRole('alert')).toHaveTextContent(/nothing was sent/i);
  });
});
