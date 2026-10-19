import type {ReactNode} from 'react';
import type {Cluster} from '../api';
import {usePageTitle} from '../components';
import {DOCS_URL} from '../config';
import {fmtAgoLong, fmtUtcFull, fmtUtcTime, plural} from '../format';
import {useClusters} from '../useClusters';

const SILENT_AFTER = 60 * 60;
const BACK_WINDOW = 24 * 3600;

type View = {
  tone: 'ok' | 'stopped' | 'waiting' | 'silent' | 'back' | 'off' | 'detached';
  pill: string;
  lastSeen: string;
  detail?: ReactNode;
};

/** Maps an API cluster to the copy of spec 1.6. */
export function clusterView(c: Cluster, nowMs = Date.now()): View {
  const now = nowMs / 1000;
  const last = c.last_seen ?? 0;
  const seen = last ? fmtAgoLong(last, nowMs) : 'Not yet';
  switch (c.state) {
    case 'detached':
      return {tone: 'detached', pill: 'Not attached', lastSeen: ''};
    case 'off':
      return {
        tone: 'off',
        pill: 'Check-ins off',
        lastSeen: 'Not tracked',
        detail: 'Turn them on in the installer: License / Pro > Cluster check-ins.',
      };
    case 'stopped':
      return {
        tone: 'stopped',
        pill: `Stopped · since ${fmtUtcTime(c.stopped_since ?? last)}`,
        lastSeen: seen,
        detail: 'kwatch was shut down cleanly. It will show Healthy again when it starts.',
      };
    case 'waiting':
      return {
        tone: 'waiting',
        pill: 'Waiting',
        lastSeen: 'Not yet',
        detail: 'Add the key in the installer, then wait up to 30 minutes.',
      };
    case 'silent':
      return {
        tone: 'silent',
        pill: `Silent since ${fmtUtcTime(c.silent_since ?? last + SILENT_AFTER)}`,
        lastSeen: seen,
        detail: (
          <>
            kwatch stopped talking. Your apps may be fine, but kwatch cannot alert you while it is silent. Run{' '}
            <code className="mono">kubectl -n kwatch get pods</code>.
          </>
        ),
      };
    case 'back': {
      if (c.recovered_at && now - c.recovered_at < BACK_WINDOW) {
        const mins = Math.max(1, Math.round(Math.max(0, (c.quiet_seconds ?? 0) - SILENT_AFTER) / 60));
        return {
          tone: 'back',
          pill: `Back at ${fmtUtcTime(c.recovered_at)}`,
          lastSeen: seen,
          detail: `Silent for ${plural(mins, 'minute', 'minutes')}. Anything that broke in that time may not have been reported.`,
        };
      }
      return {tone: 'ok', pill: 'Checking in', lastSeen: seen};
    }
    default:
      return {tone: 'ok', pill: 'Checking in', lastSeen: seen};
  }
}

function Pill({view}: {view: View}) {
  return <span className={`pill pill-${view.tone}`}>{view.pill}</span>;
}

function Name({c}: {c: Cluster}) {
  return (
    <>
      <div>{c.name || 'Unnamed cluster'}</div>
      <div className="mono cluster-id">{c.id_short}</div>
    </>
  );
}

function lastSeenCell(c: Cluster, v: View) {
  if (!v.lastSeen) return null;
  return c.last_seen ? <span title={fmtUtcFull(c.last_seen)}>{v.lastSeen}</span> : v.lastSeen;
}

export default function Clusters() {
  usePageTitle('Clusters');
  const {clusters, failed, nowMs, reload} = useClusters();

  return (
    <>
      <div className="page-head">
        <h1>Clusters</h1>
        <button type="button" className="link small" onClick={() => void reload()}>
          Refresh
        </button>
      </div>

      {failed && (
        <div className="alert" role="alert">
          Could not load your clusters. Reload the page; if it keeps failing, use Get help.
        </div>
      )}

      {!clusters && !failed && (
        <div aria-busy="true" aria-label="Loading clusters">
          <div className="skeleton" />
          <div className="skeleton" />
          <div className="skeleton" />
        </div>
      )}

      {clusters && clusters.length === 0 && (
        <p className="body">
          No clusters yet. Add a key in the installer (License / Pro &gt; Add or replace key) and it appears here within
          30 minutes.
        </p>
      )}

      {clusters && clusters.length > 0 && (
        <>
          <table className="clusters">
            <thead>
              <tr>
                <th scope="col">Cluster</th>
                <th scope="col">License</th>
                <th scope="col">Last seen</th>
                <th scope="col">Status</th>
                <th scope="col">Version</th>
                <th scope="col">Nodes</th>
              </tr>
            </thead>
            <tbody>
              {clusters.map((c) => {
                const v = clusterView(c, nowMs);
                return (
                  <tr key={c.cluster_uuid || `${c.license}-${c.id_short}`}>
                    <td><Name c={c} /></td>
                    <td className="mono small">{c.license}</td>
                    <td>{lastSeenCell(c, v)}</td>
                    <td>
                      <Pill view={v} />
                      {v.detail && <p className="detail">{v.detail}</p>}
                    </td>
                    <td className="mono small">{c.version ? `v${c.version.replace(/^v/, '')}` : ''}</td>
                    <td>{c.nodes ?? ''}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <ul className="cluster-cards" style={{listStyle: 'none', padding: 0}}>
            {clusters.map((c) => {
              const v = clusterView(c, nowMs);
              return (
                <li key={c.cluster_uuid || `${c.license}-${c.id_short}`} className="cluster-card">
                  <Name c={c} />
                  <div><Pill view={v} /></div>
                  {v.detail && <p className="detail small muted">{v.detail}</p>}
                  <p className="small muted">
                    {v.lastSeen && <>Last seen {lastSeenCell(c, v)} · </>}
                    {c.version ? `v${c.version.replace(/^v/, '')} · ` : ''}
                    {c.nodes != null ? plural(c.nodes, 'node', 'nodes') : ''}
                  </p>
                  <p className="small muted mono">{c.license}</p>
                </li>
              );
            })}
          </ul>
        </>
      )}

      <section className="panel">
        <h2>How this works</h2>
        <p>
          kwatch checks in every 30 minutes. After 60 minutes without a check-in we mark the cluster silent here. We do
          not send messages. Want one?{' '}
          <a href={`${DOCS_URL}/heartbeat-monitor-configuration`}>kwatch can ping a monitor you own.</a>
        </p>
      </section>
    </>
  );
}
