import {render, screen} from '@testing-library/react';
import {describe, expect, it} from 'vitest';
import {ApiError} from '../api';
import {errorMessage} from '../messages';

const show = (n: unknown) => render(<div>{n as never}</div>);

describe('errorMessage', () => {
  it('shows the organization limit with the domain and the contact link', () => {
    show(errorMessage(new ApiError(409, 'trial_limit_reached', {scope: 'organization', domain: 'acme.com'}), 'x', 2));
    expect(screen.getByText('acme.com has used both free Pro clusters')).toBeInTheDocument();
    expect(screen.getByText(/shared by everyone on your company's email domain/)).toBeInTheDocument();
    expect(screen.getByRole('link', {name: 'Tell us about your setup'})).toHaveAttribute('href', 'mailto:hello@kwatch.dev');
  });

  it('shows the account limit', () => {
    show(errorMessage(new ApiError(409, 'trial_limit_reached', {scope: 'account'}), 'x', 2));
    expect(screen.getByText('You have used both free Pro clusters')).toBeInTheDocument();
  });

  it('maps the other codes', () => {
    expect(errorMessage(new ApiError(0, 'network'), 'f')).toMatch(/Could not reach/);
    expect(errorMessage(new ApiError(429, 'transfer_limit'), 'f')).toMatch(/No moves left/);
    expect(errorMessage(new ApiError(429, 'regenerate_limit'), 'f')).toMatch(/3 times a day/);
    expect(errorMessage(new ApiError(400, 'disposable_email'), 'f')).toMatch(/Disposable/);
    expect(errorMessage(new ApiError(400, 'invalid_email'), 'f')).toMatch(/valid email/);
    expect(errorMessage(new ApiError(429, 'rate_limited'), 'f')).toMatch(/Too many/);
    expect(errorMessage(new ApiError(401, 'unauthorized'), 'f')).toMatch(/sign in again/);
    expect(errorMessage(new ApiError(500), 'fallback text')).toBe('fallback text');
  });

  it('never says trial', () => {
    const codes = ['network', 'transfer_limit', 'regenerate_limit', 'disposable_email', 'invalid_email', 'turnstile_failed'];
    for (const c of codes) expect(String(errorMessage(new ApiError(400, c), 'f'))).not.toMatch(/trial/i);
  });
});
