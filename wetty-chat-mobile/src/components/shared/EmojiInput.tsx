import { useState, useCallback } from 'react';
import { IonButton, IonIcon, IonInput, IonPopover } from '@ionic/react';
import EmojiPicker, { EmojiStyle, Theme, type EmojiClickData } from 'emoji-picker-react';
import { happyOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
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

function getGraphemes(str: string): string[] {
  if (!str) return [];
  const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
  return Array.from(segmenter.segment(str)).map((s) => s.segment);
}

function isEmojiGrapheme(grapheme: string): boolean {
  if (!grapheme) return false;
  return /^\p{RGI_Emoji}$/v.test(grapheme);
}

export function EmojiInput({
  value = '',
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
  const [popoverSide, setPopoverSide] = useState<'top' | 'bottom'>('bottom');
  const [pickerHeight, setPickerHeight] = useState(350);

  const handleEmojiClick = useCallback(
    (emojiData: EmojiClickData) => {
      const currentGraphemes = getGraphemes(value);
      if (currentGraphemes.length >= maxEmojiCount) return;

      const nextGraphemes = [...currentGraphemes, emojiData.emoji];
      onChange(nextGraphemes.slice(0, maxEmojiCount).join(''));
    },
    [value, maxEmojiCount, onChange],
  );

  const handleKeyDown = useCallback((event: React.KeyboardEvent<HTMLIonInputElement>) => {
    if (event.nativeEvent.isComposing || event.key.length > 1) {
      return;
    }
    if (!isEmojiGrapheme(event.key)) {
      event.preventDefault();
    }
  }, []);

  const handlePaste = useCallback(
    (event: React.ClipboardEvent<HTMLIonInputElement>) => {
      event.preventDefault();

      const pastedText = event.clipboardData.getData('text');
      if (!pastedText) return;

      const validEmojis = getGraphemes(pastedText).filter(isEmojiGrapheme);
      if (validEmojis.length === 0) return;

      const currentGraphemes = getGraphemes(value);
      const newGraphemes = [...currentGraphemes, ...validEmojis].slice(0, maxEmojiCount);
      onChange(newGraphemes.join(''));
    },
    [value, maxEmojiCount, onChange],
  );

  const handleIonInput = useCallback(
    (event: Event) => {
      const customEvent = event as CustomEvent;
      const target = event.target as HTMLIonInputElement;
      const rawValue = customEvent.detail.value ?? '';

      const cleanValue = rawValue.replace(/\s+/g, '');
      const validEmojis = getGraphemes(cleanValue).filter(isEmojiGrapheme);
      const finalValue = validEmojis.slice(0, maxEmojiCount).join('');

      if (rawValue !== finalValue) {
        target.value = finalValue;
      }

      onChange(finalValue);
    },
    [maxEmojiCount, onChange],
  );

  const handleOpenPicker = useCallback((event: React.MouseEvent<HTMLIonButtonElement>) => {
    const y = event.clientY;
    const vh = window.innerHeight;
    const margin = 24;
    const openUp = y > vh / 2;

    setPopoverSide(openUp ? 'top' : 'bottom');
    setPickerHeight(Math.min(350, Math.max(200, (openUp ? y : vh - y) - margin)));
    setTriggerEvent(event.nativeEvent);
    setIsPickerOpen(true);
  }, []);

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
          onKeyDown={handleKeyDown}
          onPaste={handlePaste}
          onIonInput={handleIonInput}
        />
        <IonButton
          type="button"
          fill="clear"
          aria-label={t`Open emoji picker`}
          className={styles.triggerButton}
          onClick={handleOpenPicker}
        >
          <IonIcon slot="icon-only" icon={happyOutline} />
        </IonButton>
      </div>

      <IonPopover
        isOpen={isPickerOpen}
        event={triggerEvent}
        onDidDismiss={() => {
          setIsPickerOpen(false);
          setTriggerEvent(undefined);
        }}
        alignment="end"
        side={popoverSide}
        className={styles.popover}
      >
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
            height={pickerHeight}
          />
        </div>
      </IonPopover>
    </>
  );
}
