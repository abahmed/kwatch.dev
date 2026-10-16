import {screen, waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach, describe, expect, it, vi} from 'vitest';
import {account, mockApi, renderAt} from './helpers';

// The real widget needs Cloudflare: the stub gives a token on click.
vi.mock('../turnstile', () => ({
  Turnstile: ({onToken}: {onToken: (t: string) => void}) => (
    <button type="button" onClick={() => onToken('tok')}>
      pass check
    </button>
  ),
}));

afterEach(() => vi.unstubAllGlobals());
const signedOut = {'GET /account': {status: 401, body: {error: 'unauthorized'}}};

describe('/signin email form', () => {
  it('requires the check, then shows "check your inbox"', async () => {
    const {calls} = mockApi({...signedOut, 'POST /auth/start': {body: {ok: true}}});
    const user = userEvent.setup();
    renderAt('/signin');
    await user.type(await screen.findByLabelText('Email'), ' ab@acme.com ');
    await user.click(screen.getByRole('button', {name: 'Email me a sign-in link'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('complete the verification');
    expect(calls.some((c) => c.key === 'POST /auth/start')).toBe(false);

    await user.click(screen.getByRole('button', {name: 'pass check'}));
    await user.click(screen.getByRole('button', {name: 'Email me a sign-in link'}));
    expect(await screen.findByRole('heading', {name: 'Check your inbox'})).toBeInTheDocument();
    expect(screen.getByText('ab@acme.com')).toBeInTheDocument();
    expect(screen.getByText(/works once, for 15 minutes/)).toBeInTheDocument();
    const start = calls.find((c) => c.key === 'POST /auth/start')!;
    expect(JSON.parse(start.init.body as string)).toEqual({email: 'ab@acme.com', turnstile_token: 'tok'});
  });

  it('can go back to use a different email', async () => {
    mockApi({...signedOut, 'POST /auth/start': {body: {ok: true}}});
    const user = userEvent.setup();
    renderAt('/signin');
    await user.type(await screen.findByLabelText('Email'), 'ab@acme.com');
    await user.click(screen.getByRole('button', {name: 'pass check'}));
    await user.click(screen.getByRole('button', {name: 'Email me a sign-in link'}));
    await user.click(await screen.findByRole('button', {name: 'Use a different email'}));
    expect(await screen.findByLabelText('Email')).toHaveValue('');
  });

  it('shows the disposable-email error', async () => {
    mockApi({...signedOut, 'POST /auth/start': {status: 400, body: {error: 'disposable_email'}}});
    const user = userEvent.setup();
    renderAt('/signin');
    await user.type(await screen.findByLabelText('Email'), 'x@mailinator.com');
    await user.click(screen.getByRole('button', {name: 'pass check'}));
    await user.click(screen.getByRole('button', {name: 'Email me a sign-in link'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('Disposable email addresses are not accepted');
  });

  it('shows the expired state for a legacy /signup?error=link_expired link', async () => {
    mockApi(signedOut);
    renderAt('/signup?error=link_expired');
    expect(await screen.findByText('Link expired')).toBeInTheDocument();
    expect(screen.getByRole('heading', {name: 'Sign in to kwatch'})).toBeInTheDocument();
  });

  it('goes to /licenses when already signed in', async () => {
    mockApi({'GET /account': {body: account({licenses: []})}});
    renderAt('/signin');
    expect(await screen.findByRole('heading', {name: 'Get your free Pro license.'})).toBeInTheDocument();
  });
});

describe('/signin?t=', () => {
  it('only consumes the link when Sign in is pressed, then opens the licenses', async () => {
    const {calls} = mockApi({
      'POST /auth/verify': {body: {ok: true}},
      'GET /account': {body: account()},
    });
    const user = userEvent.setup();
    renderAt('/signin?t=abc_123');
    expect(await screen.findByRole('heading', {name: 'Continue to kwatch'})).toBeInTheDocument();
    expect(calls).toHaveLength(0);
    await user.click(screen.getByRole('button', {name: 'Sign in'}));
    expect(await screen.findByRole('heading', {name: 'Get your free Pro license.'})).toBeInTheDocument();
    const verify = calls.find((c) => c.key === 'POST /auth/verify')!;
    expect(JSON.parse(verify.init.body as string)).toEqual({t: 'abc_123'});
  });

  it('shows "Link expired" for an expired or used link', async () => {
    mockApi({'POST /auth/verify': {status: 400, body: {error: 'link_expired'}}});
    const user = userEvent.setup();
    renderAt('/signin?t=old');
    await user.click(await screen.findByRole('button', {name: 'Sign in'}));
    expect(await screen.findByText('Link expired')).toBeInTheDocument();
    expect(screen.getByRole('link', {name: 'Get a new one'})).toHaveAttribute('href', '/signin');
    expect(screen.queryByRole('button', {name: 'Sign in'})).not.toBeInTheDocument();
  });

  it('shows a network error and keeps the button', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('down')));
    const user = userEvent.setup();
    renderAt('/signin?t=abc');
    await user.click(await screen.findByRole('button', {name: 'Sign in'}));
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('Could not reach'));
    expect(screen.getByRole('button', {name: 'Sign in'})).toBeEnabled();
  });
});

describe('routing', () => {
  it('sends / to /signin when signed out', async () => {
    mockApi(signedOut);
    renderAt('/');
    expect(await screen.findByRole('heading', {name: 'Sign in to kwatch'})).toBeInTheDocument();
  });

  it('sends a 401 on /licenses to /signin', async () => {
    mockApi(signedOut);
    renderAt('/licenses');
    expect(await screen.findByRole('heading', {name: 'Sign in to kwatch'})).toBeInTheDocument();
  });

  it('shows a 404 page', async () => {
    mockApi(signedOut);
    renderAt('/nope');
    expect(await screen.findByRole('heading', {name: 'Page not found'})).toBeInTheDocument();
  });
});
