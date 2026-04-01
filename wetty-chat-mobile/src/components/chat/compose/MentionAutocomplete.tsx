import { t } from '@lingui/core/macro';
import type { MemberResponse } from '@/api/group';
import { UserAvatar } from '@/components/UserAvatar';
import styles from './MentionAutocomplete.module.scss';

interface MentionAutocompleteProps {
  results: MemberResponse[];
  selectedIndex: number;
  loading: boolean;
  query: string;
  onSelect: (member: MemberResponse) => void;
}

export function MentionAutocomplete({ results, selectedIndex, loading, query, onSelect }: MentionAutocompleteProps) {
  if (!loading && results.length === 0) {
    return null;
  }

  return (
    <div className={styles.popup} role="listbox" aria-label={t`Mention suggestions`}>
      {loading && results.length === 0 && <div className={styles.loadingRow}>{t`Searching...`}</div>}

      {results.map((member, index) => (
        <button
          key={member.uid}
          type="button"
          className={`${styles.row} ${index === selectedIndex ? styles.rowSelected : ''}`}
          role="option"
          aria-selected={index === selectedIndex}
          onMouseDown={(e) => {
            e.preventDefault();
            onSelect(member);
          }}
        >
          <UserAvatar name={member.username ?? `User ${member.uid}`} avatarUrl={member.avatarUrl} size={28} />
          <span className={styles.username}>{highlightMatch(member.username ?? `User ${member.uid}`, query)}</span>
        </button>
      ))}
    </div>
  );
}

function highlightMatch(text: string, query: string) {
  if (!query) return text;
  const lower = text.toLowerCase();
  const idx = lower.indexOf(query.toLowerCase());
  if (idx < 0) return text;

  return (
    <>
      {text.slice(0, idx)}
      <strong>{text.slice(idx, idx + query.length)}</strong>
      {text.slice(idx + query.length)}
    </>
  );
}
