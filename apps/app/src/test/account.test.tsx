import {screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {account, mockApi, renderAt} from './helpers';

afterEach(() => vi.unstubAllGlobals());

describe('/account', () => {
  it('shows email, organization and member since', async () => {
    mockApi({'GET /account': {body: account()}});
    renderAt('/account');
    expect(await screen.findByRole('heading', {name: 'Account'})).toBeInTheDocument();
    expect(screen.getByText('ab@acme.com', {selector: 'dd'})).toBeInTheDocument();
    expect(screen.getByText(/^acme.com \(from your email/)).toBeInTheDocument();
    expect(screen.getByText('Sep 21, 2026')).toBeInTheDocument();
  });

  it('shows "none" for a free-mail address', async () => {
    mockApi({'GET /account': {body: account({account: {email: 'me@gmail.com', created_at: 1_790_000_000}, trials: {used: 0, limit: 2, scope: 'account'}})}});
    renderAt('/account');
    expect(await screen.findByText('none')).toBeInTheDocument();
  });

  it('only deletes once the typed email matches', async () => {
    let deleted = false;
    const {calls} = mockApi({
      'GET /account': () => (deleted ? {status: 401, body: {error: 'unauthorized'}} : {body: account()}),
      'DELETE /account': () => {
        deleted = true;
        return {body: {ok: true}};
      },
    });
    const user = userEvent.setup();
    renderAt('/account');
    await user.click(await screen.findByRole('button', {name: 'Delete account…'}));
    const del = screen.getByRole('button', {name: 'Permanently delete account'});
    expect(del).toBeDisabled();
    await user.type(screen.getByLabelText(/Type/), 'ab@acme.co');
    expect(del).toBeDisabled();
    await user.type(screen.getByLabelText(/Type/), 'm');
    expect(del).toBeEnabled();
    await user.click(del);
    expect(await screen.findByRole('heading', {name: 'Sign in to kwatch'})).toBeInTheDocument();
    expect(calls.filter((c) => c.key === 'DELETE /account')).toHaveLength(1);
  });

  it('makes no delete request while the email does not match', async () => {
    const {calls} = mockApi({'GET /account': {body: account()}});
    const user = userEvent.setup();
    renderAt('/account');
    await user.click(await screen.findByRole('button', {name: 'Delete account…'}));
    await user.type(screen.getByLabelText(/Type/), 'wrong@acme.com');
    await user.click(screen.getByRole('button', {name: 'Permanently delete account'}));
    expect(calls.some((c) => c.key === 'DELETE /account')).toBe(false);
  });
});
