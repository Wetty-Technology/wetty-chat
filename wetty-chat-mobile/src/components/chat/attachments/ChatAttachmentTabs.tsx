import { IonSegment, IonSegmentButton } from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import type { ChatAttachmentKindFilter } from '@/api/attachments';
import styles from './ChatAttachmentTabs.module.scss';

interface ChatAttachmentTabsProps {
  value: AttachmentTabFilter;
  onChange: (value: AttachmentTabFilter) => void;
}

export type AttachmentTabFilter = Extract<ChatAttachmentKindFilter, 'image' | 'video'>;

const filters: AttachmentTabFilter[] = ['image', 'video'];

function isAttachmentFilter(value: unknown): value is AttachmentTabFilter {
  return typeof value === 'string' && filters.includes(value as AttachmentTabFilter);
}

export function ChatAttachmentTabs({ value, onChange }: ChatAttachmentTabsProps) {
  return (
    <IonSegment
      className={styles.segment}
      value={value}
      onIonChange={(event) => {
        const nextValue = event.detail.value;
        if (isAttachmentFilter(nextValue)) {
          onChange(nextValue);
        }
      }}
    >
      <IonSegmentButton value="image">
        <Trans>Images</Trans>
      </IonSegmentButton>
      <IonSegmentButton value="video">
        <Trans>Videos</Trans>
      </IonSegmentButton>
    </IonSegment>
  );
}
