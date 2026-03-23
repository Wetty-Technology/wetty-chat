import { IonChip, IonContent, IonIcon, IonLabel, IonModal } from '@ionic/react';
import { close } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import type { Sender } from '@/api/messages';
import { useIsDarkMode, useIsDesktop } from '@/hooks/platformHooks';
import { UserAvatar } from '@/components/UserAvatar';
import { FeatureGate } from '../FeatureGate';

interface UserProfileModalProps {
  sender: Sender | null;
  onDismiss: () => void;
}

export function UserProfileModal({ sender, onDismiss }: UserProfileModalProps) {
  const isDesktop = useIsDesktop();
  const isDarkMode = useIsDarkMode();
  const displayName = sender?.name ?? (sender ? `User ${sender.uid}` : '');
  const groupName = sender?.user_group?.name?.trim() || null;
  const groupNameColor = isDarkMode
    ? sender?.user_group?.chat_group_color_dark || sender?.user_group?.chat_group_color || undefined
    : sender?.user_group?.chat_group_color || undefined;

  return (
    <IonModal
      isOpen={sender != null}
      onDidDismiss={onDismiss}
      {...(!isDesktop ? { initialBreakpoint: 0.5, breakpoints: [0, 0.5] } : {})}
    >
      <IonContent className="ion-padding">
        <button
          onClick={onDismiss}
          aria-label={t`Close`}
          style={{
            position: 'absolute',
            top: 12,
            right: 12,
            background: 'var(--ion-color-light)',
            border: 'none',
            borderRadius: '50%',
            width: 32,
            height: 32,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            zIndex: 1,
          }}
        >
          <IonIcon icon={close} style={{ fontSize: 20 }} />
        </button>
        {sender && (
          <div style={{ textAlign: 'center', paddingTop: 24 }}>
            <UserAvatar name={displayName} avatarUrl={sender.avatar_url} size={80} style={{ display: 'inline-flex' }} />
            <h2>{displayName}</h2>
            {groupName && (
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'center',
                  marginTop: 4,
                }}
              >
                <IonChip
                  outline
                  style={groupNameColor ? { color: groupNameColor, borderColor: groupNameColor } : undefined}
                >
                  <IonLabel>{groupName}</IonLabel>
                </IonChip>
              </div>
            )}
            <FeatureGate>
              <p style={{ color: 'var(--ion-color-medium)' }}>UID: {sender.uid}</p>
            </FeatureGate>
          </div>
        )}
      </IonContent>
    </IonModal>
  );
}
