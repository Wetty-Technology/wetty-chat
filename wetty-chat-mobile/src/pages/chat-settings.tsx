import { useState, useEffect } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonInput,
  IonTextarea,
  IonSelect,
  IonSelectOption,
  IonButton,
  IonBackButton,
  IonButtons,
  IonSpinner,
  useIonToast,
} from '@ionic/react';
import { useParams, useHistory } from 'react-router-dom';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { getChatDetails, updateChat } from '@/api/chats';

export default function ChatSettingsPage() {
  const { id } = useParams<{ id: string }>();
  const chatId = id ? String(id) : '';
  const history = useHistory();
  const [presentToast] = useIonToast();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [avatar, setAvatar] = useState('');
  const [visibility, setVisibility] = useState<'public' | 'private'>('public');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!chatId) return;
    setLoading(true);
    getChatDetails(chatId)
      .then((res) => {
        setName(res.data.name || '');
        setDescription(res.data.description || '');
        setAvatar(res.data.avatar || '');
        setVisibility(res.data.visibility as 'public' | 'private');
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to load chat details`, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [chatId, presentToast]);

  const handleSave = () => {
    if (!chatId) return;
    setSaving(true);
    updateChat(chatId, {
      name: name.trim() || undefined,
      description: description.trim() || undefined,
      avatar: avatar.trim() || undefined,
      visibility,
    })
      .then(() => {
        presentToast({ message: t`Settings saved`, duration: 2000 });
        history.goBack();
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to save settings`, duration: 3000 });
      })
      .finally(() => setSaving(false));
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref={`/chats/${chatId}`} text="" />
          </IonButtons>
          <IonTitle><Trans>Group Settings</Trans></IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}>
            <IonSpinner />
          </div>
        ) : (
          <>
            <IonList>
              <IonItem>
                <IonLabel position="stacked"><Trans>Group Name</Trans></IonLabel>
                <IonInput
                  value={name}
                  placeholder={t`Enter group name`}
                  onIonInput={(e) => setName(e.detail.value ?? '')}
                />
              </IonItem>
              <IonItem>
                <IonLabel position="stacked"><Trans>Description</Trans></IonLabel>
                <IonTextarea
                  value={description}
                  placeholder={t`Enter group description`}
                  onIonInput={(e) => setDescription(e.detail.value ?? '')}
                  rows={3}
                />
              </IonItem>
              <IonItem>
                <IonLabel position="stacked"><Trans>Avatar URL</Trans></IonLabel>
                <IonInput
                  type="url"
                  value={avatar}
                  placeholder={t`Enter avatar URL`}
                  onIonInput={(e) => setAvatar(e.detail.value ?? '')}
                />
              </IonItem>
              <IonItem>
                <IonLabel><Trans>Visibility</Trans></IonLabel>
                <IonSelect
                  value={visibility}
                  onIonChange={(e) => setVisibility(e.detail.value as 'public' | 'private')}
                >
                  <IonSelectOption value="public"><Trans>Public</Trans></IonSelectOption>
                  <IonSelectOption value="private"><Trans>Private</Trans></IonSelectOption>
                </IonSelect>
              </IonItem>
            </IonList>
            <div style={{ padding: '16px' }}>
              <IonButton expand="block" disabled={saving} onClick={handleSave}>
                {saving ? <Trans>Saving...</Trans> : <Trans>Save Settings</Trans>}
              </IonButton>
            </div>
          </>
        )}
      </IonContent>
    </IonPage>
  );
}
