import {describe, expect, it} from 'vitest';
import {fmtRefreshed} from '../format';

describe('fmtRefreshed', () => {
  const t = 1_800_000_000_000;
  it('says just now under a minute', () => {
    expect(fmtRefreshed(t, t)).toBe('Last refreshed just now');
    expect(fmtRefreshed(t, t + 59_000)).toBe('Last refreshed just now');
  });
  it('uses minutes, hours and days', () => {
    expect(fmtRefreshed(t, t + 120_000)).toBe('Last refreshed 2 min ago');
    expect(fmtRefreshed(t, t + 3 * 3600_000)).toBe('Last refreshed 3 h ago');
    expect(fmtRefreshed(t, t + 2 * 86400_000)).toBe('Last refreshed 2 d ago');
  });
  it('never goes negative', () => {
    expect(fmtRefreshed(t, t - 5000)).toBe('Last refreshed just now');
  });
});
