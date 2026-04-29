import React from 'react';
import { UserAvatar } from '@/components/UserAvatar';
import type { User } from '@/api/messages';
import type { GroupedUser } from '@/hooks/useReactionGrouping';

interface ReactionUserItemProps {
  user: GroupedUser;
  showEmojis: boolean;
  style?: React.CSSProperties;
  onAvatarClick?: (sender: User) => void;
}

export function ReactionUserItem({ user, showEmojis, style, onAvatarClick }: ReactionUserItemProps) {
  const displayName = user.name || `User ${user.uid}`;
  const endsWithEmoji = /\p{Extended_Pictographic}\s*$/u.test(displayName);

  const handleClick = onAvatarClick
    ? () =>
        onAvatarClick({
          uid: user.uid,
          name: user.name,
          avatarUrl: user.avatarUrl,
          gender: 0, // Fallback since it's not provided in group API
        })
    : undefined;

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        padding: '8px 12px',
        borderRadius: '8px',
        cursor: onAvatarClick ? 'pointer' : 'default',
        maxWidth: '100%',
        boxSizing: 'border-box',
        ...style,
      }}
      onClick={handleClick}
    >
      <div style={{ flexShrink: 0 }}>
        <UserAvatar name={displayName} avatarUrl={user.avatarUrl} size={36} />
      </div>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span
          style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            fontSize: '16px',
            fontWeight: 500,
            color: 'var(--ion-text-color)',
          }}
          title={displayName}
        >
          {displayName}
        </span>
        {showEmojis && user.emojis && user.emojis.length > 0 && (
          <div style={{ display: 'flex', alignItems: 'center', flexShrink: 0 }}>
            {endsWithEmoji && (
              <span
                style={{
                  width: '4px',
                  height: '4px',
                  borderRadius: '50%',
                  backgroundColor: 'var(--ion-text-color)',
                  opacity: 0.15,
                  flexShrink: 0,
                  margin: '0 10px',
                }}
              />
            )}
            <span
              style={{
                display: 'flex',
                alignItems: 'center',
                flexShrink: 0,
                gap: '4px',
                fontSize: '16px',
                marginLeft: endsWithEmoji ? 0 : '8px',
              }}
            >
              {user.emojis.map((emoji, index) => (
                <span key={index}>{emoji}</span>
              ))}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}
