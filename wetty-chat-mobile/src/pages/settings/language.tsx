import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonIcon,
  IonButtons,
  IonBackButton,
} from '@ionic/react';
import { checkmark } from 'ionicons/icons';
import { useSelector, useDispatch } from 'react-redux';
import { useHistory } from 'react-router-dom';
import { Trans } from '@lingui/react/macro';
import { selectLocale, setLocale } from '@/store/settingsSlice';
import { dynamicActivate, activateDetectedLocale } from '@/i18n';

const locales = [
  { code: 'en', label: 'English' },
  { code: 'zh-CN', label: '简体中文' },
] as const;

export default function LanguagePage() {
  const dispatch = useDispatch();
  const history = useHistory();
  const currentLocale = useSelector(selectLocale);

  const handleSelect = async (code: string) => {
    dispatch(setLocale(code));
    await dynamicActivate(code);
    history.goBack();
  };

  const handleSelectAuto = async () => {
    dispatch(setLocale(null));
    await activateDetectedLocale();
    history.goBack();
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref="/settings" />
          </IonButtons>
          <IonTitle>Language</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <IonList>
          <IonItem button detail={false} onClick={handleSelectAuto}>
            <IonLabel><Trans>Auto</Trans></IonLabel>
            {currentLocale === null && (
              <IonIcon icon={checkmark} slot="end" color="primary" />
            )}
          </IonItem>
          {locales.map(({ code, label }) => (
            <IonItem key={code} button detail={false} onClick={() => handleSelect(code)}>
              <IonLabel>{label}</IonLabel>
              {currentLocale === code && (
                <IonIcon icon={checkmark} slot="end" color="primary" />
              )}
            </IonItem>
          ))}
        </IonList>
      </IonContent>
    </IonPage>
  );
}
