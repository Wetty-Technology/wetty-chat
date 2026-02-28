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
        presentToast({ message: err.message || 'Failed to load chat details', duration: 3000 });
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
        presentToast({ message: 'Settings saved', duration: 2000 });
        history.goBack();
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || 'Failed to save settings', duration: 3000 });
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
          <IonTitle>Group Settings</IonTitle>
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
                <IonLabel position="stacked">Group Name</IonLabel>
                <IonInput
                  value={name}
                  placeholder="Enter group name"
                  onIonInput={(e) => setName(e.detail.value ?? '')}
                />
              </IonItem>
              <IonItem>
                <IonLabel position="stacked">Description</IonLabel>
                <IonTextarea
                  value={description}
                  placeholder="Enter group description"
                  onIonInput={(e) => setDescription(e.detail.value ?? '')}
                  rows={3}
                />
              </IonItem>
              <IonItem>
                <IonLabel position="stacked">Avatar URL</IonLabel>
                <IonInput
                  type="url"
                  value={avatar}
                  placeholder="Enter avatar URL"
                  onIonInput={(e) => setAvatar(e.detail.value ?? '')}
                />
              </IonItem>
              <IonItem>
                <IonLabel>Visibility</IonLabel>
                <IonSelect
                  value={visibility}
                  onIonChange={(e) => setVisibility(e.detail.value as 'public' | 'private')}
                >
                  <IonSelectOption value="public">Public</IonSelectOption>
                  <IonSelectOption value="private">Private</IonSelectOption>
                </IonSelect>
              </IonItem>
            </IonList>
            <div style={{ padding: '16px' }}>
              <IonButton expand="block" disabled={saving} onClick={handleSave}>
                {saving ? 'Saving...' : 'Save Settings'}
              </IonButton>
            </div>
          </>
        )}
      </IonContent>
    </IonPage>
  );
}
