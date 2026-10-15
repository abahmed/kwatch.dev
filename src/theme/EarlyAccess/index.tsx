import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';

import styles from './styles.module.css';

type Props = {
  /** "badge" is a small pill; "banner" is a full-width note with details. */
  variant?: 'badge' | 'banner';
  /** Pill on a dark background (the home hero). */
  onDark?: boolean;
  /** Where the badge links to. Pass null for no link. */
  to?: string | null;
};

export default function EarlyAccess({
  variant = 'badge',
  onDark = false,
  to = '/pricing',
}: Props): ReactElement {
  if (variant === 'banner') {
    return (
      <div className={styles.banner} role="note">
        <span className={styles.tag}>Early access</span>
        <p>
          kwatch Pro is free while we are in early access: 3-month licenses that
          may be renewed, up to 2 clusters per account (per company domain for
          work emails). No payment details.
        </p>
      </div>
    );
  }
  const className = `${styles.badge} ${onDark ? styles.onDark : ''}`;
  const content = (
    <>
      <span className={styles.dot} aria-hidden="true" />
      Early access: kwatch Pro is free
    </>
  );
  return to ? (
    <Link className={className} to={to}>
      {content}
    </Link>
  ) : (
    <span className={className}>{content}</span>
  );
}
