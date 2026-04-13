import { IonSkeletonText } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { UserAvatar } from '@/components/UserAvatar';
import styles from './SettingsProfileHero.module.scss';

interface SettingsProfileHeroProps {
  uid: number | null;
  username: string | null;
  avatarUrl: string | null;
  loading: boolean;
}

function getDisplayName(uid: number | null, username: string | null) {
  const trimmedUsername = username?.trim();
  if (trimmedUsername) return trimmedUsername;
  if (uid) return t`User ${uid}`;
  return t`Your account`;
}

export function SettingsProfileHero({ uid, username, avatarUrl, loading }: SettingsProfileHeroProps) {
  const displayName = getDisplayName(uid, username);

  return (
    <section className={styles.wrapper}>
      <UserAvatar name={displayName} avatarUrl={avatarUrl} size={88} />
      {loading ? (
        <div className={styles.loadingCopy} aria-hidden="true">
          <IonSkeletonText animated={true} className={styles.titleSkeleton} />
        </div>
      ) : (
        <h2 className={styles.title}>{displayName}</h2>
      )}
    </section>
  );
}
