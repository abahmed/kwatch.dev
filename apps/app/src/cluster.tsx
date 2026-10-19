import type {ReactNode} from 'react';
import type {Cluster} from './api';
import {INACTIVE_AFTER_MINUTES} from './config';
import {fmtUtcTime} from './format';

const INACTIVE_AFTER = INACTIVE_AFTER_MINUTES * 60;

export type ClusterView = {
  tone: 'active' | 'inactive' | 'stopped' | 'waiting' | 'off';
  pill: string;
  /** "Last check-in 14:00 UTC", empty when not tracked. */
  lastCheckin: string;
  /** "Inactive after 15:00", shown only while Active. */
  inactiveAfter?: string;
  detail?: ReactNode;
};

const hhmm = (unix: number) => fmtUtcTime(unix).replace(' UTC', '');

/** Maps an API cluster to the pills of the licenses-and-clusters spec. */
export function clusterView(c: Cluster): ClusterView {
  const last = c.last_seen ?? 0;
  const lastCheckin = last ? `Last check-in ${fmtUtcTime(last)}` : '';
  switch (c.state) {
    case 'off':
      return {
        tone: 'off',
        pill: 'Check-ins off',
        lastCheckin: '',
        detail: 'Check-ins are off for this cluster.',
      };
    case 'stopped':
      return {
        tone: 'stopped',
        pill: `Stopped at ${fmtUtcTime(c.stopped_since ?? last)}`,
        lastCheckin,
        detail: 'kwatch was shut down cleanly. It shows Active again when it starts.',
      };
    case 'waiting':
      return {
        tone: 'waiting',
        pill: 'Waiting',
        lastCheckin: '',
        detail: 'Add the key in the installer. It appears here after the cluster’s first check-in.',
      };
    case 'silent':
      return {
        tone: 'inactive',
        pill: `Inactive since ${fmtUtcTime(c.inactive_since ?? c.silent_since ?? last + INACTIVE_AFTER + 60)}`,
        lastCheckin,
        detail: (
          <>
            kwatch stopped talking. Your apps may be fine, but kwatch cannot alert you while it is inactive. Run{' '}
            <code className="mono">kubectl -n kwatch get pods</code>.
          </>
        ),
      };
    default:
      return {
        tone: 'active',
        pill: 'Active',
        lastCheckin,
        inactiveAfter: last ? `Inactive after ${hhmm(last + INACTIVE_AFTER)}` : undefined,
      };
  }
}

/** Attention order: Inactive, Stopped, Waiting and Check-ins off, Active. */
export function clusterRank(c: Cluster | undefined): number {
  if (!c) return 2;
  switch (clusterView(c).tone) {
    case 'inactive': return 0;
    case 'stopped': return 1;
    case 'waiting':
    case 'off': return 2;
    default: return 3;
  }
}

export function Pill({view}: {view: ClusterView}) {
  return <span className={`pill pill-${view.tone}`}>{view.pill}</span>;
}
