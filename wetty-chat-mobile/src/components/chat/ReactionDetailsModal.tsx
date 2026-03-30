import { useEffect, useState } from 'react';
import { IonContent, IonIcon, IonModal } from '@ionic/react';
import { close } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { getReactionDetails, type ReactionReactor } from '@/api/messages';
import { useIsDesktop } from '@/hooks/platformHooks';
import { UserAvatar } from '@/components/UserAvatar';

interface ReactionGroup {
  emoji: string;
  reactors: ReactionReactor[];
}

interface ReactionDetailsModalProps {
  chatId: string;
  messageId: string | null;
  initialEmoji?: string;
  onDismiss: () => void;
}

export function ReactionDetailsModal({ chatId, messageId, initialEmoji, onDismiss }: ReactionDetailsModalProps) {
  const isDesktop = useIsDesktop();
  const [groupsState, setGroupsState] = useState<{ messageId: string | null; groups: ReactionGroup[] }>({
    messageId: null,
    groups: [],
  });
  const [selectedState, setSelectedState] = useState<{ messageId: string | null; emoji?: string }>({
    messageId: null,
    emoji: initialEmoji,
  });

  useEffect(() => {
    if (!messageId) return;

    let cancelled = false;
    getReactionDetails(chatId, messageId)
      .then((res) => {
        if (cancelled) return;
        setGroupsState({ messageId, groups: res.data.reactions });
      })
      .catch(() => {
        if (cancelled) return;
        setGroupsState({ messageId, groups: [] });
      });

    return () => {
      cancelled = true;
    };
  }, [chatId, messageId, initialEmoji]);

  const groups = groupsState.messageId === messageId ? groupsState.groups : [];
  const selectedEmoji = selectedState.messageId === messageId ? selectedState.emoji : initialEmoji;
  const loading = messageId != null && groupsState.messageId !== messageId;
  const activeGroup = groups.find((g) => g.emoji === selectedEmoji) ?? groups[0];

  return (
    <IonModal
      isOpen={messageId != null}
      onDidDismiss={onDismiss}
      {...(!isDesktop ? { initialBreakpoint: 0.5, breakpoints: [0, 0.5, 0.75] } : {})}
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

        {/* Emoji tabs */}
        <div style={{ display: 'flex', gap: 8, paddingTop: 8, paddingBottom: 16, flexWrap: 'wrap' }}>
          {groups.map((g) => (
            <button
              key={g.emoji}
              onClick={() => setSelectedState({ messageId, emoji: g.emoji })}
              style={{
                padding: '4px 12px',
                borderRadius: 16,
                border:
                  g.emoji === activeGroup?.emoji
                    ? '2px solid var(--ion-color-primary)'
                    : '1px solid var(--ion-color-light-shade)',
                background: g.emoji === activeGroup?.emoji ? 'rgba(var(--ion-color-primary-rgb), 0.1)' : 'transparent',
                color: 'var(--ion-text-color)',
                cursor: 'pointer',
                fontSize: 18,
              }}
            >
              {g.emoji} {g.reactors.length}
            </button>
          ))}
        </div>

        {/* Reactor list */}
        {loading ? (
          <p style={{ textAlign: 'center', opacity: 0.6 }}>{t`Loading...`}</p>
        ) : activeGroup ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {activeGroup.reactors.map((reactor) => {
              const displayName = reactor.name ?? `User ${reactor.uid}`;
              return (
                <div key={reactor.uid} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <UserAvatar name={displayName} avatarUrl={reactor.avatarUrl} size={36} />
                  <span style={{ fontSize: 15 }}>{displayName}</span>
                </div>
              );
            })}
          </div>
        ) : null}
      </IonContent>
    </IonModal>
  );
}
