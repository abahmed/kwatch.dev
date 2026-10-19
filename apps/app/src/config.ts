const env = import.meta.env;

export const API_URL: string = (env.VITE_API_URL || 'https://api.kwatch.dev').replace(/\/+$/, '');

/** Empty string disables the widget (local development against a DEV_MODE API). */
export const TURNSTILE_SITEKEY: string = env.VITE_TURNSTILE_SITEKEY ?? '0x4AAAAAAFXDDMTb_URieNVZ';

export const SITE_URL = 'https://kwatch.dev';
export const DOCS_URL = 'https://docs.kwatch.dev';
export const CONTACT_URL = 'mailto:hello@kwatch.dev';
export const ISSUES_URL = 'https://github.com/abahmed/kwatch/issues/new';
