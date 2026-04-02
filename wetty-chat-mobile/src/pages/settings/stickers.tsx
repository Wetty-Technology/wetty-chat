import { useCallback, useEffect, useState } from 'react';
import {
  IonBackButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonListHeader,
  IonNote,
  IonPage,
  IonTitle,
  IonToolbar,
  useIonAlert,
  useIonToast,
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

interface StickerSettingsCoreProps {
  backAction?: BackAction;
  onOpenPack?: (packId: string) => void;
}

export function StickerSettingsCore({ backAction, onOpenPack }: StickerSettingsCoreProps) {
  const history = useHistory();
  const [presentAlert] = useIonAlert();
  const [presentToast] = useIonToast();
  const [ownedPacks, setOwnedPacks] = useState<StickerPackSummary[]>([]);
  const [subscribedPacks, setSubscribedPacks] = useState<StickerPackSummary[]>([]);

  const loadPacks = useCallback(async () => {
    try {
      const [ownedRes, subscribedRes] = await Promise.all([getOwnedStickerPacks(), getSubscribedStickerPacks()]);
      setOwnedPacks(ownedRes.data.packs);
      setSubscribedPacks(
        subscribedRes.data.packs.filter((pack) => !ownedRes.data.packs.some((ownedPack) => ownedPack.id === pack.id)),
      );
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
            {backAction ? <BackButton action={backAction} /> : <IonBackButton defaultHref="/settings" />}
          </IonButtons>
          <IonTitle>
            <Trans>Stickers</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <IonListHeader>
          <IonLabel>
            <Trans>My Packs</Trans>
          </IonLabel>
        </IonListHeader>
        <IonList inset>
          {ownedPacks.map((pack) => (
            <IonItem key={pack.id} button detail onClick={() => handleOpenPack(pack.id)}>
              {pack.previewSticker ? (
                <StickerImage
                  slot="start"
                  src={pack.previewSticker.media.url}
                  alt=""
                  style={{ width: 32, height: 32, objectFit: 'contain', borderRadius: 4 }}
                />
              ) : (
                <IonIcon aria-hidden="true" icon={cubeOutline} slot="start" color="medium" />
              )}
              <IonLabel>{pack.name}</IonLabel>
              <IonNote slot="end" color="medium">
                {pack.stickerCount}
              </IonNote>
            </IonItem>
          ))}
          <IonItem button detail={false} onClick={handleCreatePack}>
            <IonIcon aria-hidden="true" icon={addOutline} slot="start" color="primary" />
            <IonLabel color="primary">
              <Trans>Create New Pack</Trans>
            </IonLabel>
          </IonItem>
        </IonList>

        <IonListHeader>
          <IonLabel>
            <Trans>Subscribed Packs</Trans>
          </IonLabel>
        </IonListHeader>
        <IonList inset>
          {subscribedPacks.length === 0 ? (
            <IonItem>
              <IonIcon aria-hidden="true" icon={cubeOutline} slot="start" color="medium" />
              <IonLabel color="medium">
                <Trans>No subscribed packs</Trans>
              </IonLabel>
            </IonItem>
          ) : (
            subscribedPacks.map((pack) => (
              <IonItem key={pack.id} button detail onClick={() => handleOpenPack(pack.id)}>
                {pack.previewSticker ? (
                  <StickerImage
                    slot="start"
                    src={pack.previewSticker.media.url}
                    alt=""
                    style={{ width: 32, height: 32, objectFit: 'contain', borderRadius: 4 }}
                  />
                ) : (
                  <IonIcon aria-hidden="true" icon={cubeOutline} slot="start" color="medium" />
                )}
                <IonLabel>{pack.name}</IonLabel>
                <IonNote slot="end" color="medium">
                  {pack.stickerCount}
                </IonNote>
              </IonItem>
            ))
          )}
        </IonList>
      </IonContent>
    </IonPage>
  );
}

export default function StickerSettingsPage() {
  return <StickerSettingsCore />;
}
