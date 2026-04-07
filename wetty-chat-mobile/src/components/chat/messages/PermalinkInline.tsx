import { useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { useHistory } from 'react-router-dom';
import { openPermalinkTarget } from '@/utils/openPermalinkTarget';
import styles from './ChatBubble.module.scss';
import { useChatContext } from './ChatContext';

interface PermalinkInlineProps {
  targetChatId: string;
  targetMessageId: string;
  encoded: string;
  url: string;
}

export function PermalinkInline({ targetChatId, targetMessageId, encoded, url }: PermalinkInlineProps) {
  const history = useHistory();
  const ctx = useChatContext();
  const [presentToast] = useIonToast();

  return (
    <a
      href={url}
      className={styles.messageLink}
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        console.debug('[PermalinkInline] link click', {
          currentChatId: ctx?.chatId ?? null,
          targetChatId,
          targetMessageId,
          encoded,
          url,
        });

        if (ctx && ctx.chatId === targetChatId) {
          // Same chat — try in-place jump first (works for both main chat and thread scope)
          console.debug('[PermalinkInline] jumping within current chat', { targetMessageId });
          void ctx.jumpToMessage(targetMessageId, { silent: true }).then((found) => {
            if (found) return;
            // Target is in a different scope (thread vs main chat) — resolve and navigate
            console.debug('[PermalinkInline] in-place jump missed, resolving permalink', {
              targetChatId,
              targetMessageId,
              encoded,
            });
            void openPermalinkTarget({
              chatId: targetChatId,
              messageId: targetMessageId,
              preserveCurrentEntry: true,
            }).catch((err) => {
              console.debug('[PermalinkInline] permalink navigation failed', {
                targetChatId,
                targetMessageId,
                encoded,
                status: err?.response?.status,
                err,
              });
              presentToast({
                message: err?.response?.status === 404 ? t`Message not found` : t`Failed to open link`,
                duration: 2000,
                color: 'danger',
              });
              history.push(`/m/${encoded}`);
            });
          });
        } else {
          // Different chat — resolve the destination directly to avoid flashing the resolver page
          console.debug('[PermalinkInline] resolving direct permalink navigation', {
            targetChatId,
            targetMessageId,
            encoded,
          });
          void openPermalinkTarget({
            chatId: targetChatId,
            messageId: targetMessageId,
            preserveCurrentEntry: true,
          }).catch((err) => {
            console.debug('[PermalinkInline] direct permalink navigation failed, falling back to resolver route', {
              targetChatId,
              targetMessageId,
              encoded,
              status: err?.response?.status,
              err,
            });
            presentToast({
              message: err?.response?.status === 404 ? t`Message not found` : t`Failed to open link`,
              duration: 2000,
              color: 'danger',
            });
            history.push(`/m/${encoded}`);
          });
        }
      }}
    >
      {url}
    </a>
  );
}
