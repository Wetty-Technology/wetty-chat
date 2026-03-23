import { IonChip, IonItem, IonLabel } from '@ionic/react';
import { t } from '@lingui/core/macro';
import type { MemberResponse } from '@/api/group';
import { UserAvatar } from '@/components/UserAvatar';
import styles from './ChatMemberRow.module.scss';
import { FeatureGate } from '../FeatureGate';

interface ChatMemberRowProps {
  member: MemberResponse;
  isAdmin: boolean;
  isCurrentUser: boolean;
  onSelect: (member: MemberResponse) => void;
}

export function ChatMemberRow({ member, isAdmin, isCurrentUser, onSelect }: ChatMemberRowProps) {
  const displayName = member.username || t`User ${member.uid}`;
  return (
    <IonItem className={styles.row} button={isAdmin && !isCurrentUser} detail={false} onClick={() => onSelect(member)}>
      <UserAvatar name={displayName} avatarUrl={member.avatar_url} size={40} className={styles.avatar} />
      <IonLabel>{displayName}</IonLabel>
      <FeatureGate>
        <IonChip className={styles.roleChip} color={member.role === 'admin' ? 'primary' : 'medium'} slot="end">
          {member.role}
        </IonChip>
      </FeatureGate>
    </IonItem>
  );
}
