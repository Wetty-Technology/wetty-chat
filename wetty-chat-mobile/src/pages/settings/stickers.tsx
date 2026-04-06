import { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
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
import { addOutline, cubeOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { BackButton } from '@/components/BackButton';
import { StickerImage } from '@/components/shared/StickerImage';
import {
  createStickerPack,
  getOwnedStickerPacks,
  getSubscribedStickerPacks,
  type StickerPackSummary,
} from '@/api/stickers';
import type { BackAction } from '@/types/back-action';
import {
  fetchRemoteSettings,
  selectAutoSortStickerPacks,
  selectStickerPackOrder,
  setAutoSortStickerPacks,
  setStickerPackOrder,
} from '@/store/settingsSlice';

interface StickerSettingsCoreProps {
  backAction?: BackAction;
  onOpenPack?: (packId: string) => void;
}

export function StickerSettingsCore({ backAction, onOpenPack }: StickerSettingsCoreProps) {
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentAlert] = useIonAlert();
  const [presentToast] = useIonToast();
  const [ownedPacks, setOwnedPacks] = useState<StickerPackSummary[]>([]);
  const [allPacks, setAllPacks] = useState<StickerPackSummary[]>([]);

  const autoSort = useSelector(selectAutoSortStickerPacks);
  const packOrder = useSelector(selectStickerPackOrder);

  const loadPacks = useCallback(async () => {
    try {
      const [ownedRes, subscribedRes] = await Promise.all([getOwnedStickerPacks(), getSubscribedStickerPacks()]);
      setOwnedPacks(ownedRes.data.packs);
      const subs = subscribedRes.data.packs.filter(
        (pack) => !ownedRes.data.packs.some((ownedPack) => ownedPack.id === pack.id),
      );

      const merged = [...ownedRes.data.packs, ...subs];

      if (packOrder.length > 0) {
        merged.sort((a, b) => {
          const indexA = packOrder.indexOf(a.id);
          const indexB = packOrder.indexOf(b.id);
          if (indexA === -1 && indexB === -1) return 0;
          if (indexA === -1) return 1;
          if (indexB === -1) return -1;
          return indexA - indexB;
        });
      }

      setAllPacks(merged);
    } catch (error) {
      console.error('Failed to load sticker packs', error);
      presentToast({ message: t`Failed to load sticker packs`, duration: 2000, position: 'bottom' });
    }
  }, [presentToast, packOrder]);

  useEffect(() => {
    const run = async () => {
      dispatch(fetchRemoteSettings() as any);
      await loadPacks();
    };

    void run();
  }, [loadPacks, dispatch]);

  const handleReorder = (event: CustomEvent<ItemReorderEventDetail>) => {
    const newItems = event.detail.complete(allPacks);
    setAllPacks(newItems);
    const newOrder = newItems.map((p: StickerPackSummary) => p.id);
    dispatch(setStickerPackOrder(newOrder));
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
              setAllPacks((prev) => {
                const newAll = [res.data, ...prev];
                const newOrder = newAll.map((p) => p.id);
                dispatch(setStickerPackOrder(newOrder));
                return newAll;
              });
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
                dispatch(setAutoSortStickerPacks(e.detail.checked));
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

          <IonReorderGroup disabled={false} onIonItemReorder={handleReorder}>
            {allPacks.map((pack) => {
              const isOwned = ownedPacks.some((p) => p.id === pack.id);
              return (
                <IonItem key={pack.id} button detail={false} onClick={() => handleOpenPack(pack.id)}>
                  <span
                    slot="start"
                    style={{ width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
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
              );
            })}
          </IonReorderGroup>
        </IonList>
      </IonContent>
    </IonPage>
  );
}

export default function StickerSettingsPage() {
  return <StickerSettingsCore />;
}
