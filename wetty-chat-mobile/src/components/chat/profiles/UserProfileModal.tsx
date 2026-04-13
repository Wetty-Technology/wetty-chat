import { IonButton, IonChip, IonContent, IonIcon, IonLabel, IonModal } from '@ionic/react';
import { close, openOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { useState } from 'react';
import type { Sender } from '@/api/messages';
import { useIsDarkMode, useIsDesktop } from '@/hooks/platformHooks';
import { UserAvatar } from '@/components/UserAvatar';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store';

interface UserProfileModalProps {
  sender: Sender | null;
  onDismiss: () => void;
}

export function UserProfileModal({ sender, onDismiss }: UserProfileModalProps) {
  const isDesktop = useIsDesktop();
  const isDarkMode = useIsDarkMode();

  const [prevSender, setPrevSender] = useState<Sender | null>(sender);
  const [localSender, setLocalSender] = useState<Sender | null>(sender);

  if (sender !== prevSender) {
    setPrevSender(sender);
    if (sender) {
      setLocalSender(sender);
    }
  }

  const displaySender = sender || localSender;
  const displayName = displaySender?.name ?? (displaySender ? `User ${displaySender.uid}` : '');
  const groupName = displaySender?.userGroup?.name?.trim() || null;
  const groupNameColor = isDarkMode
    ? displaySender?.userGroup?.chatGroupColorDark || displaySender?.userGroup?.chatGroupColor || undefined
    : displaySender?.userGroup?.chatGroupColor || undefined;
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const isOwn = displaySender?.uid === currentUserId;

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
            background: 'rgba(128, 128, 128, 0.2)',
            border: 'none',
            borderRadius: '50%',
            width: 32,
            height: 32,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            zIndex: 10,
            transition: 'transform 0.2s',
          }}
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.1)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        >
          <IonIcon icon={close} style={{ fontSize: 20, color: 'var(--ion-text-color)' }} />
        </button>
        {displaySender && (
          <div style={{ textAlign: 'center', paddingTop: 44 }}>
            <UserAvatar
              name={displayName}
              avatarUrl={displaySender.avatarUrl}
              size={80}
              style={{ display: 'inline-flex' }}
            />
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
              href={'https://www.shireyishunjian.com/main/home.php?mod=space&uid=' + displaySender.uid}
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
          </div>
        )}
      </IonContent>
    </IonModal>
  );
}
