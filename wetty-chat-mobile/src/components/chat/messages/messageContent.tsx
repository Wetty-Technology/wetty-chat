import type { ReactNode } from 'react';
import type { MentionInfo } from '@/api/messages';
import { MENTION_REGEX, MENTION_TEST, TRAILING_PUNCT, URL_REGEX } from '@/utils/chatTextMeasure';
import { parseInviteCodeFromUrl } from '@/utils/inviteUrl';
import { decodePermalink } from '@/utils/permalinkUrl';
import styles from './ChatBubble.module.scss';
import { InviteLinkInline } from './InviteLinkInline';
import { PermalinkInline } from './PermalinkInline';

const PERMALINK_PATH_RE = /^\/m\/([A-Za-z0-9_-]+)$/;

function parsePermalinkFromUrl(url: string): { chatId: string; messageId: string; encoded: string } | null {
  try {
    const parsed = new URL(url);
    if (parsed.origin !== document.location.origin) return null;
    const match = PERMALINK_PATH_RE.exec(parsed.pathname);
    if (!match) return null;
    const encoded = match[1];
    const { chatId, messageId } = decodePermalink(encoded);
    return { chatId, messageId, encoded };
  } catch {
    return null;
  }
}

function renderMessageWithLinks(message: string): ReactNode[] {
  const parts = message.split(URL_REGEX);
  if (parts.length === 1) return [message];

  return parts.map((part, index) => {
    if (index % 2 === 1) {
      const trimmed = part.replace(TRAILING_PUNCT, '');
      const suffix = part.slice(trimmed.length);
      const inviteCode = parseInviteCodeFromUrl(trimmed);
      const permalink = !inviteCode ? parsePermalinkFromUrl(trimmed) : null;
      return (
        <span key={index}>
          {inviteCode ? (
            <InviteLinkInline code={inviteCode} url={trimmed} />
          ) : permalink ? (
            <PermalinkInline
              targetChatId={permalink.chatId}
              targetMessageId={permalink.messageId}
              encoded={permalink.encoded}
              url={trimmed}
            />
          ) : (
            <a
              href={trimmed}
              className={styles.messageLink}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(event) => event.stopPropagation()}
            >
              {trimmed}
            </a>
          )}
          {suffix}
        </span>
      );
    }

    return part;
  });
}

export function renderMessageContent(
  message: string,
  mentions: MentionInfo[] | undefined,
  currentUserUid: number | null | undefined,
  onMentionClick: ((uid: number) => void) | undefined,
): ReactNode[] {
  if (!MENTION_TEST.test(message)) {
    return renderMessageWithLinks(message);
  }

  const mentionMap = new Map<number, string>();
  if (mentions) {
    for (const mention of mentions) {
      if (mention.username) mentionMap.set(mention.uid, mention.username);
    }
  }

  const regex = new RegExp(MENTION_REGEX);
  const result: ReactNode[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(message)) !== null) {
    if (match.index > lastIndex) {
      result.push(...renderMessageWithLinks(message.slice(lastIndex, match.index)));
    }

    const uid = parseInt(match[1], 10);
    const username = mentionMap.get(uid);
    const isSelf = currentUserUid != null && uid === currentUserUid;
    const clickable = onMentionClick != null;
    result.push(
      <span
        key={`mention-${uid}-${match.index}`}
        className={`${styles.mention}${isSelf ? ` ${styles.mentionSelf}` : ''}${clickable ? ` ${styles.mentionClickable}` : ''}`}
        onClick={
          clickable
            ? (event) => {
                event.stopPropagation();
                onMentionClick(uid);
              }
            : undefined
        }
      >
        @{username ?? `User ${uid}`}
      </span>,
    );
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < message.length) {
    result.push(...renderMessageWithLinks(message.slice(lastIndex)));
  }

  return result;
}
