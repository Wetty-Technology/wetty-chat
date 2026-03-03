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
import { useDispatch, useSelector } from 'react-redux';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { getChatDetails, updateChat } from '@/api/chats';
import { selectChatMeta, setChatMeta } from '@/store/chatsSlice';
import type { RootState } from '@/store/index';

export default function ChatSettingsPage() {
  const { id } = useParams<{ id: string }>();
  const chatId = id ? String(id) : '';
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [avatar, setAvatar] = useState('');
  const [visibility, setVisibility] = useState<'public' | 'private'>('public');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!chatId) return;

    const applyDetails = (data: { name?: string | null; description?: string | null; avatar?: string | null; visibility?: string }) => {
      setName(data.name || '');
      setDescription(data.description || '');
      setAvatar(data.avatar || '');
      setVisibility((data.visibility as 'public' | 'private') || 'public');
    };

    // If we already have full details in the store (visibility is present from getChatDetails), use them
    if (cachedMeta?.visibility) {
      applyDetails(cachedMeta);
      setLoading(false);
      return;
    }

    setLoading(true);
    getChatDetails(chatId)
      .then((res) => {
        const { id: _, ...meta } = res.data;
        dispatch(setChatMeta({ chatId, meta }));
        applyDetails(meta);
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to load chat details`, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [chatId]);

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
        dispatch(setChatMeta({
          chatId, meta: {
            name: name.trim() || null,
            description: description.trim() || null,
            avatar: avatar.trim() || null,
            visibility,
          }
        }));
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
            <IonBackButton defaultHref={`/chats/chat/${chatId}`} text="" />
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
