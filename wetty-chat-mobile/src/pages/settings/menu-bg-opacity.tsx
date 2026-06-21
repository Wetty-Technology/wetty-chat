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
  IonRange,
  IonTitle,
  IonToolbar,
} from '@ionic/react';
import { t } from '@lingui/core/macro';
import { useState } from 'react';
import { Trans } from '@lingui/react/macro';
import { checkmark } from 'ionicons/icons';
import {
  MENU_BG_OPACITY_MIN,
  MENU_BG_OPACITY_MAX,
  getMenuBgOpacityPresets,
  isCustomMenuBgOpacity,
  setMenuBgOpacity,
  useMenuBgOpacity,
} from '@/store/advancedSettingsStore';
import type { BackAction } from '@/types/back-action';
import { BackButton } from '@/components/BackButton';

interface MenuBgOpacityCoreProps {
  backAction?: BackAction;
}

export function MenuBgOpacityCore({ backAction }: MenuBgOpacityCoreProps) {
  const currentOpacity = useMenuBgOpacity();
  const presets = getMenuBgOpacityPresets();
  const hasCustomValue = isCustomMenuBgOpacity(currentOpacity);
  const [customSelected, setCustomSelected] = useState(hasCustomValue);

  const handlePresetTap = (value: number) => {
    setCustomSelected(false);
    setMenuBgOpacity(value);
  };

  const handleCustomTap = () => {
    setCustomSelected(true);
  };

  const handleSliderChange = (value: number) => {
    setMenuBgOpacity(value);
  };

  const isCurrentlyCustom = customSelected || hasCustomValue;

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction ? (
              <BackButton action={backAction} />
            ) : (
              <IonBackButton text={t`Back`} defaultHref="/settings/advanced" />
            )}
          </IonButtons>
          <IonTitle>
            <Trans>Menu Background Opacity</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <IonList>
          {presets.map((preset) => (
            <IonItem key={preset.value} button detail={false} onClick={() => handlePresetTap(preset.value)}>
              <IonLabel>{preset.label}</IonLabel>
              {!isCurrentlyCustom && currentOpacity === preset.value && (
                <IonIcon icon={checkmark} slot="end" color="primary" />
              )}
            </IonItem>
          ))}
          <IonItem button detail={false} onClick={handleCustomTap}>
            <IonLabel>{t`Custom`}</IonLabel>
            {isCurrentlyCustom && <IonIcon icon={checkmark} slot="end" color="primary" />}
          </IonItem>
        </IonList>

        {isCurrentlyCustom && (
          <IonList>
            <IonItem>
              <IonLabel position="stacked">
                {t`Opacity`}: {currentOpacity}%
              </IonLabel>
              <IonRange
                min={MENU_BG_OPACITY_MIN}
                max={MENU_BG_OPACITY_MAX}
                step={1}
                value={currentOpacity}
                onIonInput={(e) => handleSliderChange(e.detail.value as number)}
              >
                <IonLabel slot="start">{t`Transparent`}</IonLabel>
                <IonLabel slot="end">{t`Opaque`}</IonLabel>
              </IonRange>
            </IonItem>
          </IonList>
        )}
      </IonContent>
    </IonPage>
  );
}

export default function MenuBgOpacityPage() {
  return <MenuBgOpacityCore />;
}
