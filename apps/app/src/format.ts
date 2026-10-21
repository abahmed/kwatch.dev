const dateFmt = new Intl.DateTimeFormat('en-US', {year: 'numeric', month: 'short', day: 'numeric'});

export function fmtDate(unix: number): string {
  return dateFmt.format(new Date(unix * 1000));
}

export function fmtAgo(unix: number, nowMs = Date.now()): string {
  const s = Math.max(0, Math.floor(nowMs / 1000 - unix));
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return `${Math.floor(s / 86400)} d ago`;
}

export function maskKey(key: string): string {
  if (key.length <= 12) return '•'.repeat(key.length);
  return key.slice(0, 4) + '••••••' + key.slice(-6);
}

export function plural(n: number, one: string, many: string): string {
  return `${n} ${n === 1 ? one : many}`;
}

/** "Just now", "4 minutes ago", "3 hours ago", "2 days ago". */
export function fmtAgoLong(unix: number, nowMs = Date.now()): string {
  const s = Math.max(0, Math.floor(nowMs / 1000 - unix));
  if (s < 60) return 'Just now';
  if (s < 3600) return `${plural(Math.floor(s / 60), 'minute', 'minutes')} ago`;
  if (s < 86400) return `${plural(Math.floor(s / 3600), 'hour', 'hours')} ago`;
  return `${plural(Math.floor(s / 86400), 'day', 'days')} ago`;
}

/** "14:02 UTC" */
export function fmtUtcTime(unix: number): string {
  return `${new Date(unix * 1000).toISOString().slice(11, 16)} UTC`;
}

export function fmtUtcFull(unix: number): string {
  return `${new Date(unix * 1000).toISOString().slice(0, 16).replace('T', ' ')} UTC`;
}

/** "Last refreshed just now", "Last refreshed 2 min ago". */
export function fmtRefreshed(updatedAtMs: number, nowMs = Date.now()): string {
  return `Last refreshed ${fmtAgo(updatedAtMs / 1000, nowMs)}`;
}

/** "just now", "20 min ago", "3 h ago", "2 days ago". */
export function fmtLastSeenAgo(unix: number, nowMs = Date.now()): string {
  const s = Math.max(0, Math.floor(nowMs / 1000 - unix));
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  const d = Math.floor(s / 86400);
  return `${d} ${d === 1 ? 'day' : 'days'} ago`;
}

type Semver = {core: [number, number, number]; pre: string[]};
function parseSemver(v: string | null | undefined): Semver | null {
  const m = /^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec((v ?? '').trim());
  if (!m) return null;
  return {core: [+m[1], +m[2], +m[3]], pre: m[4] ? m[4].split('.') : []};
}
function cmpPre(a: string[], b: string[]): number {
  if (!a.length || !b.length) return a.length === b.length ? 0 : a.length ? -1 : 1;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if (a[i] === undefined) return -1;
    if (b[i] === undefined) return 1;
    const an = /^\d+$/.test(a[i]), bn = /^\d+$/.test(b[i]);
    if (an && bn) { if (+a[i] !== +b[i]) return +a[i] < +b[i] ? -1 : 1; }
    else if (an !== bn) return an ? -1 : 1;
    else if (a[i] !== b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return 0;
}
/** True when the cluster version is a valid semver older than the latest release. Unparseable: false. */
export function isOutdated(version: string | null | undefined, latest: string | null | undefined): boolean {
  const a = parseSemver(version), b = parseSemver(latest);
  if (!a || !b) return false;
  for (let i = 0; i < 3; i++) if (a.core[i] !== b.core[i]) return a.core[i] < b.core[i];
  return cmpPre(a.pre, b.pre) < 0;
}
