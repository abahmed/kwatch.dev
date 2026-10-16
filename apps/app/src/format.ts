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
