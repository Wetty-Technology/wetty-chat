import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  IonBackButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonPage,
  IonTitle,
  IonToggle,
  IonToolbar,
  useIonAlert,
  useIonToast,
  IonBadge,
  IonReorder,
  IonReorderGroup,
  type ItemReorderEventDetail,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { addOutline, cubeOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { STICKER_AUTO_SORT_LIMIT } from '@/constants/stickers';
import { BackButton } from '@/components/BackButton';
import { StickerImage } from '@/components/shared/StickerImage';
import {
  createStickerPack,
  getOwnedStickerPacks,
  getSubscribedStickerPacks,
  type StickerPackSummary,
} from '@/api/stickers';
import type { AppDispatch } from '@/store/index';
import {
  selectStickerAutoSortEnabled,
  selectStickerPackOrder,
  setAutoSortEnabled,
  sortStickerPacksByPreference,
  syncStickerPackOrder,
  upsertStickerPackOrderItem,
} from '@/store/stickerPreferencesSlice';
import type { BackAction } from '@/types/back-action';

interface StickerSettingsCoreProps {
  backAction?: BackAction;
  onOpenPack?: (packId: string) => void;
}

export function StickerSettingsCore({ backAction, onOpenPack }: StickerSettingsCoreProps) {
  const dispatch = useDispatch<AppDispatch>();
  const history = useHistory();
  const [presentAlert] = useIonAlert();
  const [presentToast] = useIonToast();
  const [ownedPacks, setOwnedPacks] = useState<StickerPackSummary[]>([]);
  const [allPacks, setAllPacks] = useState<StickerPackSummary[]>([]);
  const [itemHeight, setItemHeight] = useState(0);
  const listRef = useRef<HTMLIonReorderGroupElement>(null);
  const autoSort = useSelector(selectStickerAutoSortEnabled);
  const packOrder = useSelector(selectStickerPackOrder);
  const ownedPackIds = useMemo(() => new Set(ownedPacks.map((pack) => pack.id)), [ownedPacks]);
  const orderedPacks = useMemo(() => sortStickerPacksByPreference(allPacks, packOrder), [allPacks, packOrder]);

  useEffect(() => {
    if (listRef.current) {
      setTimeout(() => {
        const firstItem = listRef.current?.querySelector('ion-item');
        if (firstItem) {
          setItemHeight(firstItem.offsetHeight);
        }
      }, 100);
    }
  }, [orderedPacks.length]);

  const loadPacks = useCallback(async () => {
    try {
      const [ownedRes, subscribedRes] = await Promise.all([getOwnedStickerPacks(), getSubscribedStickerPacks()]);
      setOwnedPacks(ownedRes.data.packs);
      const subs = subscribedRes.data.packs.filter(
        (pack) => !ownedRes.data.packs.some((ownedPack) => ownedPack.id === pack.id),
      );
      setAllPacks([...ownedRes.data.packs, ...subs]);
    } catch (error) {
      console.error('Failed to load sticker packs', error);
      presentToast({ message: t`Failed to load sticker packs`, duration: 2000, position: 'bottom' });
    }
  }, [presentToast]);

  useEffect(() => {
    const run = async () => {
      await loadPacks();
    };

    void run();
  }, [loadPacks]);

  const handleReorder = (event: CustomEvent<ItemReorderEventDetail>) => {
    const toIndex = event.detail.to;
    const newItems = event.detail.complete(orderedPacks);
    setAllPacks(newItems);

    const movedPack = newItems[toIndex];
    const prevPack = toIndex > 0 ? newItems[toIndex - 1] : null;
    const nextPack = toIndex < newItems.length - 1 ? newItems[toIndex + 1] : null;

    let newLastUsedOn = Date.now();
    if (prevPack && nextPack) {
      const pLast = packOrder.find((o) => o.stickerPackId === prevPack.id)?.lastUsedOn ?? 0;
      const nLast = packOrder.find((o) => o.stickerPackId === nextPack.id)?.lastUsedOn ?? 0;
      if (pLast === nLast) {
        newLastUsedOn = pLast - 10000;
      } else {
        newLastUsedOn = Math.floor((pLast + nLast) / 2);
      }
    } else if (prevPack) {
      const pLast = packOrder.find((o) => o.stickerPackId === prevPack.id)?.lastUsedOn ?? 0;
      newLastUsedOn = pLast - 10000;
    } else if (nextPack) {
      const nLast = packOrder.find((o) => o.stickerPackId === nextPack.id)?.lastUsedOn ?? 0;
      newLastUsedOn = nLast + 10000;
    }

    const updatedItem = { stickerPackId: movedPack.id, lastUsedOn: newLastUsedOn };
    dispatch(upsertStickerPackOrderItem(updatedItem));
    void dispatch(syncStickerPackOrder([updatedItem]));
  };

  const handleOpenPack = (packId: string) => {
    if (onOpenPack) {
      onOpenPack(packId);
      return;
    }
    history.push(`/settings/stickers/${packId}`);
  };

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
              setAllPacks((prev) => [res.data, ...prev]);
              dispatch(
                upsertStickerPackOrderItem({
                  stickerPackId: res.data.id,
                  lastUsedOn: Date.now(),
                }),
              );

              handleOpenPack(res.data.id);
            } catch (error) {
              console.error('Failed to create sticker pack', error);
              presentToast({ message: t`Failed to create sticker pack`, duration: 2000, position: 'bottom' });
            }
          },
        },
      ],
    });
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction ? <BackButton action={backAction} /> : <IonBackButton text={t`Back`} defaultHref="/settings" />}
          </IonButtons>
          <IonTitle>
            <Trans>Stickers</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <IonList inset>
          <IonItem lines="none">
            <IonLabel>
              <Trans>Auto-sort packs by recent use</Trans>
            </IonLabel>
            <IonToggle
              slot="end"
              checked={autoSort}
              onIonChange={(e) => {
                dispatch(setAutoSortEnabled(e.detail.checked));
              }}
            />
          </IonItem>
        </IonList>

        <IonList inset>
          <IonItem button detail={false} onClick={handleCreatePack}>
            <IonIcon aria-hidden="true" icon={addOutline} slot="start" color="primary" />
            <IonLabel color="primary">
              <Trans>Create New Pack</Trans>
            </IonLabel>
          </IonItem>

          <div style={{ position: 'relative' }}>
            <IonReorderGroup ref={listRef} disabled={false} onIonItemReorder={handleReorder}>
              {orderedPacks.map((pack) => {
                if (!pack) return null; // Safety check
                const isOwned = ownedPackIds.has(pack.id);
                return (
                  <React.Fragment key={pack.id}>
                    <IonItem button detail={false} onClick={() => handleOpenPack(pack.id)}>
                      <span
                        slot="start"
                        style={{
                          width: 32,
                          height: 32,
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                      >
                        {pack.previewSticker ? (
                          <StickerImage
                            src={pack.previewSticker.media.url}
                            alt=""
                            style={{ width: '100%', height: '100%', objectFit: 'contain', borderRadius: 4 }}
                          />
                        ) : (
                          <IonIcon aria-hidden="true" icon={cubeOutline} color="medium" style={{ fontSize: 24 }} />
                        )}
                      </span>
                      <IonLabel>
                        <h2 style={{ display: 'flex', alignItems: 'center' }}>
                          {isOwned && (
                            <IonBadge
                              color="primary"
                              style={{ marginRight: 8, fontSize: '0.55rem', fontWeight: 'normal', flexShrink: 0 }}
                            >
                              <Trans>Owned</Trans>
                            </IonBadge>
                          )}
                          <span style={{ textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                            {pack.name}
                          </span>
                        </h2>
                        <p style={{ fontSize: '0.85em', color: 'var(--ion-color-medium)', marginTop: 2 }}>
                          {pack.stickerCount} <Trans>stickers</Trans>
                        </p>
                      </IonLabel>
                      <IonReorder slot="end" onClick={(e) => e.stopPropagation()} />
                    </IonItem>
                  </React.Fragment>
                );
              })}
            </IonReorderGroup>

            {autoSort && orderedPacks.length > STICKER_AUTO_SORT_LIMIT && itemHeight > 0 && (
              <div
                style={{
                  position: 'absolute',
                  top: STICKER_AUTO_SORT_LIMIT * itemHeight,
                  left: 16,
                  right: 16,
                  zIndex: 10,
                  pointerEvents: 'none',
                  transform: 'translateY(-50%)',
                  opacity: 0.8,
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <div style={{ width: '100%', height: '1px', background: 'var(--ion-color-step-300)' }} />
                <span
                  style={{
                    fontSize: '10px',
                    padding: '2px 8px',
                    margin: '4px 0',
                    color: 'var(--ion-color-medium)',
                    textAlign: 'center',
                    background: 'var(--ion-item-background, var(--ion-background-color, #fff))',
                    borderRadius: '12px',
                  }}
                >
                  <Trans>Packs below this line are not auto-sorted</Trans>
                </span>
                <div style={{ width: '100%', height: '1px', background: 'var(--ion-color-step-300)' }} />
              </div>
            )}
          </div>
        </IonList>
      </IonContent>
    </IonPage>
  );
}

export default function StickerSettingsPage() {
  return <StickerSettingsCore />;
}
