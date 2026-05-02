import { useEffect, useState } from 'react';
import { IonContent, IonIcon, IonModal } from '@ionic/react';
import { close, addCircleOutline, removeCircleOutline, settingsOutline } from 'ionicons/icons';
import { useHistory, useLocation } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import type { RootState } from '@/store';
import { t } from '@lingui/core/macro';
import { StickerImage } from '@/components/shared/StickerImage';
import { Trans } from '@lingui/react/macro';
import {
  getStickerDetail,
  getStickerPack,
  subscribeStickerPack,
  unsubscribeStickerPack,
  type StickerDetailResponse,
  type StickerPackDetailResponse,
} from '@/api/stickers';
import { useIsDesktop } from '@/hooks/platformHooks';
import type { AppDispatch } from '@/store/index';
import { removeStickerPackOrderItem, upsertStickerPackOrderItem } from '@/store/stickerPreferencesSlice';
import styles from './StickerPreviewModal.module.scss';

interface StickerPreviewModalProps {
  stickerId: string | null;
  onDismiss: () => void;
}

interface StickerPreviewModalContentProps {
  stickerId: string;
  isDesktop: boolean;
  onDismiss: () => void;
}

export function StickerPreviewModal({ stickerId, onDismiss }: StickerPreviewModalProps) {
  const isDesktop = useIsDesktop();
  const isOpen = stickerId != null;

  if (!isOpen) return null;

  return (
    <StickerPreviewModalContent key={stickerId} stickerId={stickerId} isDesktop={isDesktop} onDismiss={onDismiss} />
  );
}

function StickerPreviewModalContent({ stickerId, isDesktop, onDismiss }: StickerPreviewModalContentProps) {
  const dispatch = useDispatch<AppDispatch>();
  const history = useHistory();
  const location = useLocation();
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const [detail, setDetail] = useState<{ id: string; data: StickerDetailResponse } | null>(null);
  const [packDetail, setPackDetail] = useState<{ id: string; data: StickerPackDetailResponse } | null>(null);
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [selectedStickerId, setSelectedStickerId] = useState<string | null>(null);

  const loading = detail?.id !== stickerId || !packDetail;
  const stickerData = detail?.id === stickerId ? detail.data : null;
  const pack = packDetail?.data ?? null;

  const heroSticker = selectedStickerId
    ? (pack?.stickers.find((sticker) => sticker.id === selectedStickerId) ?? stickerData)
    : stickerData;
  const heroUrl = heroSticker?.media.url ?? null;

  useEffect(() => {
    let cancelled = false;

    getStickerDetail(stickerId)
      .then((res) => {
        if (cancelled) return;
        setDetail({ id: stickerId, data: res.data });

        const firstPack = res.data.packs[0];
        if (!firstPack) return;

        setIsSubscribed(firstPack.isSubscribed);

        return getStickerPack(firstPack.id).then((packRes) => {
          if (cancelled) return;
          setPackDetail({ id: firstPack.id, data: packRes.data });
        });
      })
      .catch((err) => {
        if (cancelled) return;
        console.error('Failed to load sticker detail', err);
      });

    return () => {
      cancelled = true;
    };
  }, [stickerId]);

  async function handleSubscriptionToggle() {
    if (!pack) return;
    const prev = isSubscribed;
    setIsSubscribed(!prev);
    try {
      if (prev) {
        await unsubscribeStickerPack(pack.id);
        dispatch(removeStickerPackOrderItem(pack.id));
      } else {
        await subscribeStickerPack(pack.id);
        dispatch(upsertStickerPackOrderItem({ stickerPackId: pack.id, lastUsedOn: Date.now() }));
      }
    } catch {
      setIsSubscribed(prev);
    }
  }

  const packName = pack?.name ?? stickerData?.packs[0]?.name ?? '';
  const stickerCount = pack?.stickers.length ?? stickerData?.packs[0]?.stickerCount ?? 0;
  const stickers = pack?.stickers ?? [];

  function renderContent() {
    if (loading) {
      return (
        <div className={styles.heroSection}>
          <p style={{ opacity: 0.5 }}>{t`Loading...`}</p>
        </div>
      );
    }

    return (
      <>
        <div className={styles.heroSection}>
          {heroUrl && <StickerImage src={heroUrl} alt={t`Sticker preview`} className={styles.heroMedia} />}
          {heroSticker && <span className={styles.heroEmoji}>{heroSticker.emoji}</span>}
        </div>

        <div className={styles.packHeader}>
          <span className={styles.packName}>{packName}</span>
          <span className={styles.packCount}>
            {stickerCount} <Trans>stickers</Trans>
          </span>
        </div>

        <div className={styles.grid}>
          {stickers.map((sticker) => (
            <button
              key={sticker.id}
              type="button"
              className={`${styles.gridCell} ${(selectedStickerId ?? stickerId) === sticker.id ? styles.gridCellActive : ''}`}
              onClick={() => setSelectedStickerId(sticker.id)}
              aria-label={sticker.name || sticker.emoji}
            >
              <StickerImage src={sticker.media.url} alt="" className={styles.gridMedia} />
            </button>
          ))}
        </div>
        <div className={styles.gridBottomSpacer} />
      </>
    );
  }

  function renderActionButton() {
    if (loading || !pack) return null;

    if (pack.ownerUid === currentUserId) {
      return (
        <button
          type="button"
          className={`${styles.floatingAction} ${styles.subscribeBtn}`}
          onClick={() => {
            onDismiss();

            const chatMatch = location.pathname.match(/^\/chats\/chat\/([^/]+)/);
            if (!isDesktop && chatMatch) {
              const chatId = chatMatch[1];
              history.push(`/chats/chat/${chatId}/stickers/${pack.id}`);
            } else {
              history.push({
                pathname: `/settings/stickers/${pack.id}`,
                state: { backgroundPath: location.pathname, fromChat: true },
              });
            }
          }}
        >
          <IonIcon icon={settingsOutline} />
          <Trans>Manage</Trans>
        </button>
      );
    }

    return (
      <button
        type="button"
        className={`${styles.floatingAction} ${isSubscribed ? styles.unsubscribeBtn : styles.subscribeBtn}`}
        onClick={handleSubscriptionToggle}
      >
        <IonIcon icon={isSubscribed ? removeCircleOutline : addCircleOutline} />
        {isSubscribed ? <Trans>Unsubscribe</Trans> : <Trans>Subscribe</Trans>}
      </button>
    );
  }

  if (isDesktop) {
    return (
      <IonModal isOpen onDidDismiss={onDismiss}>
        <IonContent className={styles.desktopModalContent}>
          <button type="button" className={styles.desktopCloseBtn} onClick={onDismiss} aria-label={t`Close`}>
            <IonIcon icon={close} />
          </button>
          {renderContent()}
        </IonContent>
        {renderActionButton()}
      </IonModal>
    );
  }

  return (
    <>
      <div className={styles.backdrop} onClick={onDismiss} />
      <div className={styles.sheet}>
        <div className={styles.sheetHeader}>
          <button type="button" className={styles.sheetCloseBtn} onClick={onDismiss} aria-label={t`Close`}>
            <IonIcon icon={close} />
          </button>
          <span className={styles.sheetTitle}>{packName}</span>
        </div>
        <div className={styles.sheetBody}>{renderContent()}</div>
        {renderActionButton()}
      </div>
    </>
  );
}
