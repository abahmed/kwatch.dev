import {act, screen, waitFor} from '@testing-library/react';
import {afterEach, beforeEach, describe, expect, it, vi} from 'vitest';
import {account, license, mockApi, renderAt} from './helpers';

const setHidden = (h: boolean) => {
  Object.defineProperty(document, 'hidden', {configurable: true, get: () => h});
  document.dispatchEvent(new Event('visibilitychange'));
};

beforeEach(() => vi.useFakeTimers({shouldAdvanceTime: true}));
afterEach(() => {
  setHidden(false);
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

const count = (calls: {key: string}[], key: string) => calls.filter((c) => c.key === key).length;

describe('refresh on return', () => {
  it('reloads account and clusters once, quietly, and throttles', async () => {
    const {calls} = mockApi({
      'GET /account': {body: account({licenses: [license()]})},
      'GET /account/clusters': {body: {clusters: []}},
    });
    renderAt('/licenses');
    await screen.findByRole('heading', {name: 'Licenses'});
    expect(count(calls, 'GET /account')).toBe(1);
    await waitFor(() => expect(count(calls, 'GET /account/clusters')).toBe(1));

    // Too soon: throttled.
    act(() => { setHidden(true); setHidden(false); });
    expect(count(calls, 'GET /account')).toBe(1);

    await act(async () => { vi.advanceTimersByTime(16_000); });
    act(() => { setHidden(true); });
    expect(count(calls, 'GET /account')).toBe(1); // hidden: skipped
    await act(async () => {
      setHidden(false);
      window.dispatchEvent(new Event('focus')); // same return: deduped
    });
    expect(count(calls, 'GET /account')).toBe(2);
    expect(count(calls, 'GET /account/clusters')).toBe(2);
    // Content stayed on screen: no skeleton or loading text.
    expect(screen.queryByLabelText('Loading cluster')).toBeNull();
    expect(screen.queryByText('Loading…')).toBeNull();
    expect(document.querySelector('[role="status"]')).toBeNull();

    act(() => { setHidden(true); setHidden(false); });
    expect(count(calls, 'GET /account')).toBe(2);
  });
});
