import { Trans } from '@lingui/react/macro';
import { UserAvatar } from '@/components/UserAvatar';
import styles from './GroupProfile.module.scss';

interface GroupProfileProps {
  chatId: string;
  name?: string | null;
  description?: string | null;
  avatarUrl?: string | null;
  visibility?: 'public' | 'private';
}

function getDisplayName(chatId: string, name?: string | null): string {
  const trimmedName = name?.trim();
  if (trimmedName) {
    return trimmedName;
  }

  return `Chat ${chatId}`;
}

export function GroupProfile({ chatId, name, description, avatarUrl }: GroupProfileProps) {
  const displayName = getDisplayName(chatId, name);
  const trimmedDescription = description?.trim() || null;

  return (
    <section className={styles.card}>
      <UserAvatar name={displayName} avatarUrl={avatarUrl} size={80} className={styles.avatar} />
      <h2 className={styles.title}>{displayName}</h2>
      <p className={trimmedDescription ? styles.description : styles.descriptionMuted}>
        {trimmedDescription ?? <Trans>No group description yet.</Trans>}
      </p>
    </section>
  );
}
