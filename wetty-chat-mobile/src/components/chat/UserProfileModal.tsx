import { IonButton, IonChip, IonContent, IonIcon, IonLabel, IonModal } from '@ionic/react';
import { close, openOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import type { Sender } from '@/api/messages';
import { useIsDarkMode, useIsDesktop } from '@/hooks/platformHooks';
import { UserAvatar } from '@/components/UserAvatar';
import { FeatureGate } from '../FeatureGate';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store';

interface UserProfileModalProps {
  sender: Sender | null;
  onDismiss: () => void;
}

export function UserProfileModal({ sender, onDismiss }: UserProfileModalProps) {
  const isDesktop = useIsDesktop();
  const isDarkMode = useIsDarkMode();
  const displayName = sender?.name ?? (sender ? `User ${sender.uid}` : '');
  const groupName = sender?.userGroup?.name?.trim() || null;
  const groupNameColor = isDarkMode
    ? sender?.userGroup?.chatGroupColorDark || sender?.userGroup?.chatGroupColor || undefined
    : sender?.userGroup?.chatGroupColor || undefined;
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const isOwn = sender?.uid === currentUserId;

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
            <UserAvatar name={displayName} avatarUrl={sender.avatarUrl} size={80} style={{ display: 'inline-flex' }} />
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
            <IonButton
              fill="outline"
              href={'https://www.shireyishunjian.com/main/home.php?mod=space&uid=' + sender.uid}
              target="_blank"
              size="small"
            >
              个人空间
              <IonIcon slot="end" icon={openOutline}></IonIcon>
            </IonButton>
            {isOwn && (
              <>
                <IonButton
                  fill="outline"
                  href="https://www.shireyishunjian.com/main/forum.php?mod=viewthread&tid=209934"
                  target="_blank"
                  size="small"
                >
                  修改用户名
                  <IonIcon slot="end" icon={openOutline}></IonIcon>
                </IonButton>
                <IonButton
                  fill="outline"
                  href="https://www.shireyishunjian.com/main/home.php?mod=spacecp&ac=avatar"
                  target="_blank"
                  size="small"
                >
                  修改头像
                  <IonIcon slot="end" icon={openOutline}></IonIcon>
                </IonButton>
              </>
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
