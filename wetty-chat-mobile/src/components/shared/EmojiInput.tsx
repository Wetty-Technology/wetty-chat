import { useEffect, useState } from 'react';
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonInput,
  IonModal,
  IonPopover,
  IonTitle,
  IonToolbar,
} from '@ionic/react';
import EmojiPicker, { EmojiStyle, Theme, type EmojiClickData } from 'emoji-picker-react';
import { happyOutline, close } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import styles from './EmojiInput.module.scss';

interface EmojiInputProps {
  value: string;
  onChange: (value: string) => void;
  label: string;
  placeholder?: string;
  required?: boolean;
  invalid?: boolean;
  errorText?: string;
  maxEmojiCount?: number;
}

const MOBILE_BREAKPOINT = '(max-width: 767px)';

function getGraphemes(str: string): string[] {
  if (!str) return [];
  const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
  return Array.from(segmenter.segment(str)).map((s) => s.segment);
}

export function EmojiInput({
  value,
  onChange,
  label,
  placeholder,
  required = false,
  invalid = false,
  errorText,
  maxEmojiCount = 4,
}: EmojiInputProps) {
  const [isPickerOpen, setIsPickerOpen] = useState(false);
  const [triggerEvent, setTriggerEvent] = useState<Event | undefined>();
  const [isCompact, setIsCompact] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia(MOBILE_BREAKPOINT);
    const handleChange = () => {
      setIsCompact(mediaQuery.matches);
    };

    handleChange();
    mediaQuery.addEventListener('change', handleChange);

    return () => {
      mediaQuery.removeEventListener('change', handleChange);
    };
  }, []);

  const handleEmojiClick = (emojiData: EmojiClickData) => {
    const currentGraphemes = getGraphemes(value);
    if (currentGraphemes.length >= maxEmojiCount) return;
    const nextGraphemes = getGraphemes(`${value}${emojiData.emoji}`);
    onChange(nextGraphemes.slice(0, maxEmojiCount).join(''));
  };

  const picker = (
    <div className={styles.pickerCard}>
      <EmojiPicker
        onEmojiClick={handleEmojiClick}
        theme={Theme.AUTO}
        emojiStyle={EmojiStyle.NATIVE}
        lazyLoadEmojis
        searchPlaceholder={t`Search emoji`}
        previewConfig={{ showPreview: false }}
        skinTonesDisabled
        width="100%"
      />
    </div>
  );

  return (
    <>
      <div className={styles.fieldRow}>
        <IonInput
          value={value}
          label={`${label}${required ? ' *' : ''}`}
          labelPlacement="stacked"
          placeholder={placeholder}
          counter
          maxlength={maxEmojiCount * 10}
          counterFormatter={() => `${getGraphemes(value).length} / ${maxEmojiCount}`}
          errorText={errorText ?? t`Please choose at least one emoji`}
          className={`${styles.input}${invalid ? ' ion-invalid ion-touched' : ''}`}
          onIonInput={(event) => {
            const cleanValue = (event.detail.value ?? '').replace(/\s+/g, '');
            onChange(getGraphemes(cleanValue).slice(0, maxEmojiCount).join(''));
          }}
        />
        <IonButton
          type="button"
          fill="clear"
          aria-label={t`Open emoji picker`}
          className={styles.triggerButton}
          onClick={(event) => {
            setTriggerEvent(event.nativeEvent);
            setIsPickerOpen(true);
          }}
        >
          <IonIcon slot="icon-only" icon={happyOutline} />
        </IonButton>
      </div>

      {isCompact ? (
        <IonModal isOpen={isPickerOpen} onDidDismiss={() => setIsPickerOpen(false)}>
          <IonHeader>
            <IonToolbar>
              <IonTitle>
                <Trans>Choose Emoji</Trans>
              </IonTitle>
              <IonButtons slot="end">
                <IonButton onClick={() => setIsPickerOpen(false)} aria-label={t`Close emoji picker`}>
                  <IonIcon slot="icon-only" icon={close} />
                </IonButton>
              </IonButtons>
            </IonToolbar>
          </IonHeader>
          <IonContent className={styles.modalContent}>{picker}</IonContent>
        </IonModal>
      ) : (
        <IonPopover
          isOpen={isPickerOpen}
          event={triggerEvent}
          onDidDismiss={() => {
            setIsPickerOpen(false);
            setTriggerEvent(undefined);
          }}
          alignment="end"
          side="bottom"
          className={styles.popover}
        >
          {picker}
        </IonPopover>
      )}
    </>
  );
}
