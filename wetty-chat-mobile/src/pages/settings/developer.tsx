import {
  IonBackButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonItem,
  IonLabel,
  IonList,
  IonNote,
  IonPage,
  IonTitle,
  IonToggle,
  IonToolbar,
} from '@ionic/react';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useHistory } from 'react-router-dom';
import { BackButton } from '@/components/BackButton';
import { FEATURES, type Feature } from '@/features';
import { useHasGlobalPermission } from '@/hooks/useHasGlobalPermission';
import {
  resetFeatureOverrides,
  selectFeatureOverrideEntryByUid,
  setDeveloperModeEnabled,
  setFeatureOverride,
} from '@/store/featureOverridesSlice';
import type { RootState } from '@/store/index';
import type { BackAction } from '@/types/back-action';

interface DeveloperSettingsCoreProps {
  backAction?: BackAction;
}

const featureKeys = Object.keys(FEATURES) as Feature[];

export function DeveloperSettingsCore({ backAction }: DeveloperSettingsCoreProps) {
  const dispatch = useDispatch();
  const history = useHistory();
  const uid = useSelector((state: RootState) => state.user.uid);
  const entry = useSelector((state: RootState) => selectFeatureOverrideEntryByUid(state, uid));
  const canAccessDeveloperSettings = useHasGlobalPermission('developer.access');

  useEffect(() => {
    if (!canAccessDeveloperSettings) {
      history.replace('/settings/general');
    }
  }, [canAccessDeveloperSettings, history]);

  if (!canAccessDeveloperSettings) return null;

  const handleToggleDeveloperMode = (enabled: boolean) => {
    if (uid == null) return;
    dispatch(setDeveloperModeEnabled({ uid, enabled }));
  };

  const handleFeatureToggle = (feature: Feature, enabled: boolean) => {
    if (uid == null) return;
    dispatch(setFeatureOverride({ uid, feature, enabled }));
  };

  const handleReset = () => {
    if (uid == null) return;
    dispatch(resetFeatureOverrides({ uid }));
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction ? (
              <BackButton action={backAction} />
            ) : (
              <IonBackButton text={t`Back`} defaultHref="/settings/general" />
            )}
          </IonButtons>
          <IonTitle>
            <Trans>Developer Settings</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        <IonList inset>
          <IonItem>
            <IonToggle checked={entry.enabled} onIonChange={(e) => handleToggleDeveloperMode(e.detail.checked)}>
              <Trans>Enable Developer Settings</Trans>
            </IonToggle>
          </IonItem>
          <IonItem button detail={false} onClick={handleReset}>
            <IonLabel color="primary">
              <Trans>Reset to defaults</Trans>
            </IonLabel>
          </IonItem>
        </IonList>

        {entry.enabled ? (
          <IonList inset>
            {featureKeys.map((feature) => (
              <IonItem key={feature}>
                <IonToggle
                  checked={entry.overrides[feature] ?? FEATURES[feature].enabled}
                  onIonChange={(e) => handleFeatureToggle(feature, e.detail.checked)}
                >
                  <IonLabel>
                    <div>{feature}</div>
                    <IonNote color="medium">{FEATURES[feature].description}</IonNote>
                  </IonLabel>
                </IonToggle>
              </IonItem>
            ))}
          </IonList>
        ) : null}
      </IonContent>
    </IonPage>
  );
}

export default function DeveloperSettingsPage() {
  return <DeveloperSettingsCore />;
}
