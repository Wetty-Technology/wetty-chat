import type { GroupedUser } from '@/hooks/useReactionGrouping';
import type { Sender } from '@/api/messages';
import { ReactionUserItem } from '@/components/chat/reactions/ReactionUserItem';

interface ReactionUserGridProps {
  users: GroupedUser[];
  showEmojis: boolean;
  onAvatarClick?: (sender: Sender) => void;
}

export function ReactionUserGrid({ users, showEmojis, onAvatarClick }: ReactionUserGridProps) {
  if (showEmojis) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', padding: '0 8px' }}>
        {users.map((user, index) => (
          <ReactionUserItem
            key={`${user.uid}-${index}`}
            user={user}
            showEmojis={showEmojis}
            onAvatarClick={onAvatarClick}
            style={{ width: '100%' }}
          />
        ))}
      </div>
    );
  }

  return (
    <div
      style={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: '8px 12px',
        padding: '0 8px',
      }}
    >
      {users.map((user, index) => (
        <ReactionUserItem
          key={`${user.uid}-${index}`}
          user={user}
          showEmojis={showEmojis}
          onAvatarClick={onAvatarClick}
        />
      ))}
    </div>
  );
}
