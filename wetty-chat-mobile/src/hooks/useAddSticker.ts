import { useState, useRef } from 'react';
import { useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { uploadStickerToPack, MAX_STICKER_FILE_BYTES, type StickerSummary } from '@/api/stickers';

interface UseAddStickerOptions {
  packId?: string;
  onSuccess: (newSticker: StickerSummary) => void;
}

export function useAddSticker({ packId, onSuccess }: UseAddStickerOptions) {
  const [addStickerFile, setAddStickerFile] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [presentToast] = useIonToast();

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    e.target.value = '';
    if (!file) return;
    if (file.size > MAX_STICKER_FILE_BYTES) {
      presentToast({
        message: t`File is too large. Maximum sticker size is 10 MB.`,
        duration: 3000,
        position: 'bottom',
      });
      return;
    }
    setAddStickerFile(file);
  };

  const handleAddSticker = async (file: File, emoji: string, name: string) => {
    if (!packId) return;
    try {
      const res = await uploadStickerToPack(packId, { file, emoji, name });
      setAddStickerFile(null);
      presentToast({ message: t`Sticker added`, duration: 1500, position: 'bottom' });
      onSuccess(res.data);
    } catch (error) {
      console.error('Failed to add sticker', error);
      presentToast({ message: t`Failed to add sticker`, duration: 2000, position: 'bottom' });
    }
  };

  return {
    addStickerFile,
    setAddStickerFile,
    fileInputRef,
    handleFileChange,
    handleAddSticker,
  };
}
