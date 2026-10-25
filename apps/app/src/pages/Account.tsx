import {useState} from 'react';
import type {ReactNode} from 'react';
import {useNavigate} from 'react-router-dom';
import {deleteAccount, logoutAll} from '../api';
import {usePageTitle} from '../components';
import {fmtDate} from '../format';
import {errorMessage} from '../messages';
import {useSession} from '../session';

export default function Account() {
  usePageTitle('Account');
  const {data} = useSession();
  const navigate = useNavigate();
  const [confirming, setConfirming] = useState(false);
  const [typed, setTyped] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<ReactNode>('');
  const email = data.account.email;
  const org = data.trials?.scope === 'organization' ? data.trials.domain : undefined;
  const matches = typed.trim().toLowerCase() === email.toLowerCase();

  async function remove() {
    if (!matches) return;
    setBusy(true);
    setError('');
    try {
      await deleteAccount();
      navigate('/signin', {replace: true});
    } catch (err) {
      setError(errorMessage(err, 'Could not delete the account. Please try again.'));
      setBusy(false);
    }
  }

  const [allBusy, setAllBusy] = useState(false);
  const [allError, setAllError] = useState<ReactNode>('');

  async function signOutEverywhere() {
    setAllBusy(true);
    setAllError('');
    try {
      await logoutAll();
      navigate('/signin', {replace: true});
    } catch (err) {
      setAllError(errorMessage(err, 'Could not sign you out everywhere. Please try again.'));
      setAllBusy(false);
    }
  }

  return (
    <>
      <h1>Account</h1>
      <dl className="facts">
        <dt>Email</dt>
        <dd>{email}</dd>
        <dt>Organization</dt>
        <dd>{org ? `${org} (from your email; personal addresses like Gmail have none)` : 'none'}</dd>
        <dt>Member since</dt>
        <dd>{fmtDate(data.account.created_at)}</dd>
      </dl>
      <section>
        <p className="danger-title">Sign-in sessions</p>
        <p className="body">Signs you out on every browser and device, including this one.</p>
        {allError && <div className="alert" role="alert">{allError}</div>}
        <button type="button" className="btn btn-sm" disabled={allBusy} onClick={signOutEverywhere}>
          {allBusy ? 'Logging out…' : 'Log out of all devices'}
        </button>
      </section>
      <section className="danger">
        <p className="danger-title">Delete account</p>
        <p className="body">
          Removes your account, licenses and sessions. Clusters using your keys fall back to Community. You'll be
          asked to type your email to confirm.
        </p>
        {error && <div className="alert" role="alert">{error}</div>}
        {!confirming ? (
          <button type="button" className="btn btn-danger btn-sm" onClick={() => setConfirming(true)}>
            Delete account…
          </button>
        ) : (
          <>
            <label htmlFor="confirm">
              Type <strong>{email}</strong> to confirm
            </label>
            <input id="confirm" value={typed} autoComplete="off" onChange={(e) => setTyped(e.target.value)} />
            <div className="row">
              <button type="button" className="btn btn-danger" disabled={busy || !matches} onClick={remove}>
                {busy ? 'Deleting…' : 'Permanently delete account'}
              </button>
              <button
                type="button"
                className="btn"
                onClick={() => {
                  setConfirming(false);
                  setTyped('');
                }}
              >
                Cancel
              </button>
            </div>
          </>
        )}
      </section>
    </>
  );
}
