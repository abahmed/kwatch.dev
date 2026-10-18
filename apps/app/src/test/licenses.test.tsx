import {screen, within} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {account, license, mockApi, renderAt} from './helpers';

afterEach(() => vi.unstubAllGlobals());

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
          licenses: [license(), license({lid: 'lic_2', activation: null, key: 'KW1-zzzzzzzzzzzzzzzzzzzzzzzz-b81Lmp'})],
        }),
      },
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    expect(await screen.findByText('Free Pro clusters: 2 of 2 used · acme.com')).toBeInTheDocument();
    const first = screen.getByRole('region', {name: 'License lic_1'});
    expect(within(first).getByText(/KW1-••••••f3a9Qk/)).toBeInTheDocument();
    expect(within(first).getByText('active')).toBeInTheDocument();
    expect(within(first).getByText(/7c1e04ab · v1.0.0 · 6 nodes/)).toBeInTheDocument();
    expect(within(first).getByText(/last check 2 h ago/)).toBeInTheDocument();
    await user.click(within(first).getByRole('button', {name: 'Show key'}));
    expect(within(first).getByText(/KW1-abcdefghijklmnopqrstuvwxyz-f3a9Qk/)).toBeInTheDocument();
    const second = screen.getByRole('region', {name: 'License lic_2'});
    expect(within(second).getByText('not activated')).toBeInTheDocument();
    expect(screen.queryByRole('button', {name: 'Get a free Pro license'})).not.toBeInTheDocument();
  });

  it('moves a license to another cluster', async () => {
    const { calls } = mockApi({
      'GET /account': {body: account({licenses: [license()]})},
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
      'POST /account/licenses/lic_1/transfer': {status: 429, body: {error: 'transfer_limit'}},
    });
    const user = userEvent.setup();
    renderAt('/licenses');
    await user.click(await screen.findByRole('button', {name: 'Move to another cluster'}));
    await user.click(screen.getByRole('button', {name: 'Move license'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('No moves left');
  });
});
