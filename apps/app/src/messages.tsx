import type {ReactNode} from 'react';
import {ApiError} from './api';
import {CONTACT_URL} from './config';

const NETWORK = 'Could not reach the kwatch service. Check your connection and try again.';

export function LimitNotice({
  scope,
  domain,
  limit,
}: {
  scope?: string;
  domain?: string;
  limit?: number;
}) {
  const all = limit && limit !== 2 ? `all ${limit}` : 'both';
  const org = scope === 'organization';
  return (
    <div className="limit" role="alert">
      <p className="limit-title">
        {org ? `${domain ?? 'Your organization'} has` : 'You have'} used {all} free Pro clusters
      </p>
      <p>
        {org
          ? "Free licenses are shared by everyone on your company's email domain."
          : 'Free licenses are limited per account.'}{' '}
        Need more for early access? <a href={CONTACT_URL}>Tell us about your setup</a>.
      </p>
    </div>
  );
}

/** Maps an API failure to the text shown to the person. */
export function errorMessage(err: unknown, fallback: string, limit?: number): ReactNode {
  const e = err as ApiError;
  switch (e?.code) {
    case 'network':
      return NETWORK;
    case 'trial_limit_reached':
    case 'trial_already_used':
      return <LimitNotice scope={e.scope} domain={e.domain} limit={limit} />;
    case 'transfer_limit':
      return 'No moves left for this license this month. Email hello@kwatch.dev if you need another.';
    case 'regenerate_limit':
      return 'You can replace keys 3 times a day. Try again tomorrow.';
    case 'revoked':
      return 'This license was revoked, so its key cannot be replaced.';
    case 'disposable_email':
      return 'Disposable email addresses are not accepted. Please use a permanent address.';
    case 'invalid_email':
      return 'That does not look like a valid email address.';
    case 'turnstile_failed':
      return 'The verification check failed. Please try again.';
  }
  if (e?.status === 429) return 'Too many attempts. Please wait a few minutes and try again.';
  if (e?.status === 401) return 'Your session expired. Please sign in again.';
  return fallback;
}
