import { useEffect, useState } from 'react';
import { IonContent, IonIcon, IonModal } from '@ionic/react';
import { close } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { getReactionDetails, type ReactionReactor, type User } from '@/api/messages';
import { useIsDesktop } from '@/hooks/platformHooks';
import { useReactionGrouping } from '@/hooks/useReactionGrouping';
import { ReactionUserGrid } from '@/components/chat/reactions/ReactionUserGrid';

interface ReactionGroup {
  emoji: string;
  reactors: ReactionReactor[];
}

interface ReactionDetailsModalProps {
  chatId: string;
  messageId: string | null;
  initialEmoji?: string;
  onDismiss: () => void;
  onAvatarClick?: (sender: User) => void;
}

export function ReactionDetailsModal({
  chatId,
  messageId,
  initialEmoji,
  onDismiss,
  onAvatarClick,
}: ReactionDetailsModalProps) {
  const isDesktop = useIsDesktop();
  const [groupsState, setGroupsState] = useState<{ messageId: string | null; groups: ReactionGroup[] }>({
    messageId: null,
    groups: [],
  });
  const [selectedState, setSelectedState] = useState<{ messageId: string | null; categoryKey?: string }>({
    messageId: null,
    categoryKey: initialEmoji || 'all',
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

  // Use the new hook for categorization and layout prep
  const { categories } = useReactionGrouping(groups);

  const selectedCategoryKey = selectedState.messageId === messageId ? selectedState.categoryKey : initialEmoji;
  const loading = messageId != null && groupsState.messageId !== messageId;
  const activeCategory = categories.find((c) => c.key === selectedCategoryKey) ?? categories[0];

  // Translation helpers for special tabs
  const getCategoryLabel = (key: string, originalLabel: string) => {
    if (key === 'all') return t`All`;
    if (key === 'more') return t`More`;
    return originalLabel;
  };

  const showEmojis = activeCategory?.key === 'all' || activeCategory?.key === 'more';

  // Desktop vs Mobile layout
  const renderLayout = () => {
    if (isDesktop) {
      return (
        <div style={{ display: 'flex', height: '100%', paddingTop: isDesktop ? 0 : 44 }}>
          {/* Left Column: Navigation */}
          <div
            style={{
              paddingTop: isDesktop ? 44 : undefined,
              minWidth: '100px',
              maxWidth: '200px',
              width: 'max-content',
              borderRight: '1px solid rgba(128, 128, 128, 0.2)',
              overflowY: 'auto',
              padding: '16px 8px',
            }}
          >
            {categories.map((c) => (
              <button
                key={c.key}
                onClick={() => setSelectedState({ messageId, categoryKey: c.key })}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '16px',
                  width: '100%',
                  padding: '12px 16px',
                  borderRadius: 8,
                  border: 'none',
                  background: c.key === activeCategory?.key ? 'rgba(var(--ion-color-primary-rgb), 0.1)' : 'transparent',
                  color: c.key === activeCategory?.key ? 'var(--ion-color-primary)' : 'var(--ion-text-color)',
                  cursor: 'pointer',
                  fontSize: 16,
                  textAlign: 'left',
                  marginBottom: 4,
                }}
              >
                <span>{getCategoryLabel(c.key, c.label)}</span>
                <span style={{ opacity: 0.6, fontSize: 14 }}>{c.count}</span>
              </button>
            ))}
          </div>

          {/* Right Column: Content */}
          <div
            style={{ flex: 1, padding: 16, paddingTop: isDesktop ? 60 : 16, overflowY: 'auto', position: 'relative' }}
          >
            {loading ? (
              <p style={{ textAlign: 'center', opacity: 0.6 }}>{t`Loading...`}</p>
            ) : activeCategory ? (
              <ReactionUserGrid users={activeCategory.users} showEmojis={showEmojis} onAvatarClick={onAvatarClick} />
            ) : null}
          </div>
        </div>
      );
    }

    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', paddingTop: 44 }}>
        {/* Top: Scrollable Tabs */}
        <div
          style={{
            display: 'flex',
            overflowX: 'auto',
            padding: '16px',
            gap: 12,
            borderBottom: '1px solid rgba(128, 128, 128, 0.2)',
            WebkitOverflowScrolling: 'touch',
            scrollbarWidth: 'none',
          }}
        >
          {categories.map((c) => (
            <button
              key={c.key}
              onClick={() => setSelectedState({ messageId, categoryKey: c.key })}
              style={{
                flexShrink: 0,
                padding: '6px 16px',
                borderRadius: 20,
                border:
                  c.key === activeCategory?.key
                    ? '2px solid var(--ion-color-primary)'
                    : '1px solid var(--ion-color-step-200, #cccccc)',
                background: c.key === activeCategory?.key ? 'rgba(var(--ion-color-primary-rgb), 0.1)' : 'transparent',
                color: 'var(--ion-text-color)',
                cursor: 'pointer',
                fontSize: 15,
                fontWeight: c.key === activeCategory?.key ? 600 : 400,
                display: 'flex',
                alignItems: 'center',
                gap: 6,
              }}
            >
              <span>{getCategoryLabel(c.key, c.label)}</span>
              <span style={{ opacity: 0.8 }}>{c.count}</span>
            </button>
          ))}
        </div>

        {/* Bottom: Content */}
        <div style={{ flex: 1, padding: 16, overflowY: 'auto' }}>
          {loading ? (
            <p style={{ textAlign: 'center', opacity: 0.6 }}>{t`Loading...`}</p>
          ) : activeCategory ? (
            <ReactionUserGrid users={activeCategory.users} showEmojis={showEmojis} onAvatarClick={onAvatarClick} />
          ) : null}
        </div>
      </div>
    );
  };

  return (
    <IonModal
      isOpen={messageId != null}
      onDidDismiss={onDismiss}
      {...(!isDesktop ? { initialBreakpoint: 0.5, breakpoints: [0, 0.5, 0.75, 1] } : {})}
      className={isDesktop ? 'desktop-modal' : ''}
    >
      <IonContent>
        {/* Close Button */}
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

        <div style={{ height: '100%', boxSizing: 'border-box' }}>{renderLayout()}</div>
      </IonContent>
    </IonModal>
  );
}
