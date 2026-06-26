import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { arrowUndoOutline } from 'ionicons/icons';

import styles from './ChatBubble.module.scss';

interface HoverReplyButtonProps {
  interactive: boolean;
  onReply?: () => void;
}

/**
 * Desktop-only reply affordance that appears on bubble hover.
 * Shared by ChatBubbleBase, InviteBubble and StickerBubble — keep in sync
 * with the `.chatRow:hover .hoverReplyBtn` rule in ChatBubble.module.scss.
 */
export function HoverReplyButton({ interactive, onReply }: HoverReplyButtonProps) {
  if (!interactive || !onReply) return null;
  return (
    <button className={styles.hoverReplyBtn} onClick={onReply} aria-label={t`Reply`}>
      <IonIcon icon={arrowUndoOutline} />
    </button>
  );
}
