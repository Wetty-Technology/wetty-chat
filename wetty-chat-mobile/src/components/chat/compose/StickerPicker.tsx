import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { IonIcon, useIonAlert, useIonToast } from '@ionic/react';
import { heart, heartDislike } from 'ionicons/icons';
import { starOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { StickerImage } from '@/components/shared/StickerImage';
import { AddStickerModal } from './AddStickerModal';
import styles from './StickerPicker.module.scss';
import {
  createStickerPack,
  getFavoriteStickers,
  getOwnedStickerPacks,
  getStickerPack,
  getSubscribedStickerPacks,
  type StickerPackDetailResponse,
  type StickerPackSummary,
  type StickerSummary,
  favoriteSticker,
  unfavoriteSticker,
} from '@/api/stickers';
import { useAddSticker } from '@/hooks/useAddSticker';

interface StickerPickerProps {
  isOpen: boolean;
  onStickerSelect: (sticker: StickerSummary) => void;
  overlayActiveRef: React.RefObject<boolean>;
}

interface PickerPack {
  id: string;
  name: string;
  previewUrl: string | null;
  owned: boolean;
  stickers: StickerSummary[];
  isLoading: boolean;
}

export function StickerPicker({ isOpen, onStickerSelect, overlayActiveRef }: StickerPickerProps) {
  const [ownedPacks, setOwnedPacks] = useState<StickerPackSummary[]>([]);
  const [subscribedPacks, setSubscribedPacks] = useState<StickerPackSummary[]>([]);
  const [favoriteStickers, setFavoriteStickers] = useState<StickerSummary[]>([]);
  const [packDetails, setPackDetails] = useState<Record<string, StickerPackDetailResponse>>({});
  const [selectedPackId, setSelectedPackId] = useState('favorites');
  const [isLibraryLoading, setIsLibraryLoading] = useState(false);
  const hasLoaded = useRef(false);
  const [loadingPackIds, setLoadingPackIds] = useState<Record<string, boolean>>({});
  const [popover, setPopover] = useState<{ sticker: StickerSummary; rect: DOMRect } | null>(null);
  const [presentAlert] = useIonAlert();
  const [presentToast] = useIonToast();

  const loadPackDetail = useCallback(async (packId: string) => {
    setLoadingPackIds((prev) => ({ ...prev, [packId]: true }));
    try {
      const res = await getStickerPack(packId);
      setPackDetails((prev) => ({ ...prev, [packId]: res.data }));
      return res.data;
    } finally {
      setLoadingPackIds((prev) => {
        const next = { ...prev };
        delete next[packId];
        return next;
      });
    }
  }, []);

  const loadLibrary = useCallback(async () => {
    if (!hasLoaded.current) {
      setIsLibraryLoading(true);
    }
    try {
      const [ownedRes, subscribedRes, favoritesRes] = await Promise.all([
        getOwnedStickerPacks(),
        getSubscribedStickerPacks(),
        getFavoriteStickers(),
      ]);
      setOwnedPacks(ownedRes.data.packs);
      setSubscribedPacks(
        subscribedRes.data.packs.filter((pack) => !ownedRes.data.packs.some((ownedPack) => ownedPack.id === pack.id)),
      );
      setFavoriteStickers(favoritesRes.data.stickers);
      hasLoaded.current = true;
    } catch (error) {
      console.error('Failed to load sticker library', error);
      presentToast({ message: t`Failed to load stickers`, duration: 2000, position: 'bottom' });
    } finally {
      setIsLibraryLoading(false);
    }
  }, [presentToast]);

  useEffect(() => {
    if (!isOpen) return;
    void loadLibrary();
  }, [isOpen, loadLibrary]);

  const packs = useMemo<PickerPack[]>(() => {
    const packEntries = [...ownedPacks, ...subscribedPacks].map((pack) => ({
      id: pack.id,
      name: pack.name,
      previewUrl: pack.previewSticker?.media.url ?? null,
      owned: ownedPacks.some((ownedPack) => ownedPack.id === pack.id),
      stickers: packDetails[pack.id]?.stickers ?? [],
      isLoading: !!loadingPackIds[pack.id],
    }));

    return [
      {
        id: 'favorites',
        name: t`Favorites`,
        previewUrl: null,
        owned: false,
        stickers: favoriteStickers,
        isLoading: isLibraryLoading,
      },
      ...packEntries,
    ];
  }, [favoriteStickers, isLibraryLoading, loadingPackIds, ownedPacks, packDetails, subscribedPacks]);

  useEffect(() => {
    if (!packs.some((pack) => pack.id === selectedPackId)) {
      setSelectedPackId('favorites');
    }
  }, [packs, selectedPackId]);

  useEffect(() => {
    if (!isOpen || selectedPackId === 'favorites' || packDetails[selectedPackId] || loadingPackIds[selectedPackId]) {
      return;
    }
    void loadPackDetail(selectedPackId);
  }, [isOpen, loadPackDetail, loadingPackIds, packDetails, selectedPackId]);

  const activePack = packs.find((pack) => pack.id === selectedPackId) ?? packs[0];

  const { addStickerFile, setAddStickerFile, fileInputRef, handleFileChange, handleAddSticker } = useAddSticker({
    packId: activePack.owned && activePack.id !== 'favorites' ? activePack.id : undefined,
    onSuccess: (newSticker) => {
      if (!activePack.owned || activePack.id === 'favorites') return;
      setPackDetails((prev) => {
        const detail = prev[activePack.id];
        if (!detail) return prev;
        return {
          ...prev,
          [activePack.id]: {
            ...detail,
            stickerCount: detail.stickerCount + 1,
            stickers: [...detail.stickers, newSticker],
          },
        };
      });
      setOwnedPacks((prev) =>
        prev.map((pack) => (pack.id === activePack.id ? { ...pack, stickerCount: pack.stickerCount + 1 } : pack)),
      );
    },
  });

  useEffect(() => {
    overlayActiveRef.current = popover !== null || addStickerFile !== null;
    return () => {
      overlayActiveRef.current = false;
    };
  }, [popover, addStickerFile, overlayActiveRef]);

  if (!isOpen) return null;

  const handleCreatePack = () => {
    presentAlert({
      header: t`New Sticker Pack`,
      inputs: [{ name: 'name', type: 'text', placeholder: t`Pack name` }],
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Create`,
          handler: async (data: { name: string }) => {
            const name = data.name.trim();
            if (!name) return false;
            try {
              const res = await createStickerPack({ name });
              setOwnedPacks((prev) => [res.data, ...prev]);
              setPackDetails((prev) => ({
                ...prev,
                [res.data.id]: { ...res.data, stickers: [] },
              }));
              setSelectedPackId(res.data.id);
            } catch (error) {
              console.error('Failed to create pack', error);
              presentToast({ message: t`Failed to create sticker pack`, duration: 2000, position: 'bottom' });
            }
          },
        },
      ],
    });
  };

  const handleStickerLongPress = (sticker: StickerSummary, rect: DOMRect) => {
    setPopover({ sticker, rect });
  };

  const handleFavoriteToggle = async () => {
    if (!popover) return;
    const { sticker } = popover;
    const isFav = sticker.isFavorited;
    setPopover(null);

    try {
      if (isFav) {
        await unfavoriteSticker(sticker.id);
        setFavoriteStickers((prev) => prev.filter((item) => item.id !== sticker.id));
      } else {
        await favoriteSticker(sticker.id);
        setFavoriteStickers((prev) => [...prev, { ...sticker, isFavorited: true }]);
      }
      setPackDetails((prev) =>
        Object.fromEntries(
          Object.entries(prev).map(([packId, detail]) => [
            packId,
            {
              ...detail,
              stickers: detail.stickers.map((item) =>
                item.id === sticker.id ? { ...item, isFavorited: !isFav } : item,
              ),
            },
          ]),
        ),
      );
    } catch (error) {
      console.error('Failed to update favorite sticker', error);
      presentToast({ message: t`Failed to update favorites`, duration: 2000, position: 'bottom' });
    }
  };

  return (
    <div className={styles.container}>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*,video/webm"
        style={{ display: 'none' }}
        onChange={handleFileChange}
      />

      <div className={styles.stickerGrid} role="grid" aria-label={activePack.name}>
        {activePack.owned && activePack.id !== 'favorites' && (
          <button
            type="button"
            className={`${styles.stickerItem} ${styles.addStickerBtn}`}
            aria-label={t`Add sticker`}
            onClick={() => fileInputRef.current?.click()}
          >
            <span className={styles.addStickerIcon} aria-hidden="true">
              +
            </span>
          </button>
        )}
        {activePack.stickers.map((sticker) => (
          <StickerButton
            key={sticker.id}
            sticker={sticker}
            onSelect={onStickerSelect}
            onLongPress={handleStickerLongPress}
          />
        ))}
        {!activePack.isLoading && activePack.stickers.length === 0 && (
          <div className={styles.emptyState}>{t`No stickers`}</div>
        )}
      </div>

      <div className={styles.packBar} role="tablist" aria-label={t`Sticker packs`}>
        {packs.map((pack) => (
          <button
            key={pack.id}
            type="button"
            role="tab"
            aria-selected={pack.id === selectedPackId}
            aria-label={pack.name}
            className={`${styles.packTab}${pack.id === selectedPackId ? ` ${styles.packTabActive}` : ''}`}
            onClick={() => setSelectedPackId(pack.id)}
          >
            <span className={styles.packIcon} aria-hidden="true">
              {pack.previewUrl ? (
                <StickerImage src={pack.previewUrl} alt="" className={styles.packIconImg} />
              ) : (
                <IonIcon icon={starOutline} />
              )}
            </span>
          </button>
        ))}
        <button
          type="button"
          className={`${styles.packTab} ${styles.createPackBtn}`}
          aria-label={t`Create new sticker pack`}
          onClick={handleCreatePack}
        >
          <span className={styles.packIcon} aria-hidden="true">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
              <path d="M10 4a1 1 0 011 1v4h4a1 1 0 110 2h-4v4a1 1 0 11-2 0v-4H5a1 1 0 110-2h4V5a1 1 0 011-1z" />
            </svg>
          </span>
        </button>
      </div>

      <AddStickerModal file={addStickerFile} onDismiss={() => setAddStickerFile(null)} onAdd={handleAddSticker} />

      {popover &&
        createPortal(
          <>
            <div className={styles.popoverBackdrop} onClick={() => setPopover(null)} />
            <div
              className={styles.popover}
              style={{ top: popover.rect.top, left: popover.rect.left + popover.rect.width / 2 }}
            >
              <button type="button" className={styles.popoverItem} onClick={handleFavoriteToggle}>
                <IonIcon icon={popover.sticker.isFavorited ? heartDislike : heart} />
                {popover.sticker.isFavorited ? t`Remove from Favorites` : t`Add to Favorites`}
              </button>
            </div>
          </>,
          document.body,
        )}
    </div>
  );
}

function StickerButton({
  sticker,
  onSelect,
  onLongPress,
}: {
  sticker: StickerSummary;
  onSelect: (sticker: StickerSummary) => void;
  onLongPress?: (sticker: StickerSummary, rect: DOMRect) => void;
}) {
  const longPressTimeoutRef = useRef<number | null>(null);
  const btnRef = useRef<HTMLButtonElement>(null);
  const touchStartPos = useRef<{ x: number; y: number } | null>(null);

  const clearLongPress = () => {
    if (longPressTimeoutRef.current != null) {
      window.clearTimeout(longPressTimeoutRef.current);
      longPressTimeoutRef.current = null;
    }
  };

  const fireLongPress = () => {
    if (btnRef.current) {
      onLongPress?.(sticker, btnRef.current.getBoundingClientRect());
    }
  };

  const startLongPress = (e: React.TouchEvent) => {
    if (!onLongPress) return;
    const touch = e.touches[0];
    touchStartPos.current = { x: touch.clientX, y: touch.clientY };
    longPressTimeoutRef.current = window.setTimeout(() => {
      longPressTimeoutRef.current = null;
      fireLongPress();
    }, 450);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    if (!touchStartPos.current) return;
    const touch = e.touches[0];
    const dx = touch.clientX - touchStartPos.current.x;
    const dy = touch.clientY - touchStartPos.current.y;
    if (dx * dx + dy * dy > 100) {
      clearLongPress();
    }
  };

  const handleClick = () => {
    clearLongPress();
    onSelect(sticker);
  };

  return (
    <button
      ref={btnRef}
      type="button"
      aria-label={sticker.name || sticker.emoji}
      className={styles.stickerItem}
      onClick={handleClick}
      onTouchStart={startLongPress}
      onTouchMove={handleTouchMove}
      onTouchEnd={clearLongPress}
      onTouchCancel={clearLongPress}
      onContextMenu={(e) => {
        e.preventDefault();
        fireLongPress();
      }}
    >
      <StickerImage src={sticker.media.url} alt="" className={styles.stickerThumb} />
    </button>
  );
}
