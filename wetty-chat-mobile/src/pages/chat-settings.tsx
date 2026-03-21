import { useState, useEffect, useMemo } from 'react';
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
  IonButtons,
  IonSpinner,
  IonListHeader,
  useIonToast,
  useIonActionSheet,
} from '@ionic/react';
import { useParams, useHistory } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { selectChatMeta, setChatMeta, selectChatMutedUntil, setChatMutedUntil } from '@/store/chatsSlice';
import type { RootState } from '@/store/index';
import { getGroupInfo, updateGroupInfo, muteChat, unmuteChat } from '@/api/group';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';

interface ChatSettingsCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

function getInitialFormState(cachedMeta?: {
  name?: string | null;
  description?: string | null;
  avatar?: string | null;
  visibility?: string;
}) {
  return {
    name: cachedMeta?.name || '',
    description: cachedMeta?.description || '',
    avatar: cachedMeta?.avatar || '',
    visibility: (cachedMeta?.visibility as 'public' | 'private') || 'public',
    loading: !cachedMeta?.visibility,
  };
}

function ChatSettingsSession({ chatId, backAction }: { chatId: string; backAction?: BackAction }) {
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const [presentActionSheet] = useIonActionSheet();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));
  const mutedUntil = useSelector((state: RootState) => selectChatMutedUntil(state, chatId));
  const isMuted = useMemo(() => mutedUntil ? new Date(mutedUntil) > new Date() : false, [mutedUntil]);
  const initialState = getInitialFormState(cachedMeta);

  const handleMute = (durationSeconds: number | null) => {
    muteChat(chatId, { duration_seconds: durationSeconds })
      .then((res) => {
        dispatch(setChatMutedUntil({ chatId, mutedUntil: res.data.muted_until }));
        presentToast({ message: t`Notifications muted`, duration: 2000 });
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to mute`, duration: 3000 });
      });
  };

  const handleUnmute = () => {
    unmuteChat(chatId)
      .then(() => {
        dispatch(setChatMutedUntil({ chatId, mutedUntil: null }));
        presentToast({ message: t`Notifications unmuted`, duration: 2000 });
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to unmute`, duration: 3000 });
      });
  };

  const showMuteActionSheet = () => {
    presentActionSheet({
      header: t`Mute notifications`,
      buttons: [
        { text: t`30 minutes`, handler: () => handleMute(1800) },
        { text: t`1 hour`, handler: () => handleMute(3600) },
        { text: t`8 hours`, handler: () => handleMute(28800) },
        { text: t`1 day`, handler: () => handleMute(86400) },
        { text: t`7 days`, handler: () => handleMute(604800) },
        { text: t`Cancel`, role: 'cancel' },
      ],
    });
  };

  const [name, setName] = useState(initialState.name);
  const [description, setDescription] = useState(initialState.description);
  const [avatar, setAvatar] = useState(initialState.avatar);
  const [visibility, setVisibility] = useState<'public' | 'private'>(initialState.visibility);
  const [loading, setLoading] = useState(initialState.loading);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (cachedMeta?.visibility) {
      return;
    }

    getGroupInfo(chatId)
      .then((res) => {
        const { id, muted_until, ...meta } = res.data;
        void id;
        dispatch(setChatMeta({ chatId, meta }));
        dispatch(setChatMutedUntil({ chatId, mutedUntil: muted_until }));
        setName(meta.name || '');
        setDescription(meta.description || '');
        setAvatar(meta.avatar || '');
        setVisibility((meta.visibility as 'public' | 'private') || 'public');
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to load chat details`, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [chatId, cachedMeta, dispatch, presentToast]);

  const handleSave = () => {
    if (!chatId) return;
    setSaving(true);
    updateGroupInfo(chatId, {
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
    <div className="ion-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction && <BackButton action={backAction} />}
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
            <IonList>
              <IonListHeader><Trans>Notifications</Trans></IonListHeader>
              {isMuted ? (
                <IonItem button onClick={handleUnmute}>
                  <IonLabel>
                    <h2><Trans>Unmute This Group</Trans></h2>
                    <p>
                      {mutedUntil && new Date(mutedUntil).getFullYear() >= 9000
                        ? <Trans>Muted indefinitely</Trans>
                        : <Trans>Muted until {new Date(mutedUntil!).toLocaleString()}</Trans>}
                    </p>
                  </IonLabel>
                </IonItem>
              ) : (
                <IonItem button onClick={showMuteActionSheet}>
                  <IonLabel><Trans>Mute This Group</Trans></IonLabel>
                </IonItem>
              )}
            </IonList>
          </>
        )}
      </IonContent>
    </div>
  );
}

export default function ChatSettingsCore({ chatId: propChatId, backAction }: ChatSettingsCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');

  if (!chatId) {
    return null;
  }

  return <ChatSettingsSession key={chatId} chatId={chatId} backAction={backAction} />;
}

export function ChatSettingsPage() {
  const { id } = useParams<{ id: string }>();
  return (
    <IonPage>
      <ChatSettingsCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}` }} />
    </IonPage>
  );
}
