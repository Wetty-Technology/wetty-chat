import { useEffect, useState } from 'react';
import {
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonInput,
  IonItem,
  IonLabel,
  IonList,
  IonListHeader,
  IonPage,
  IonSelect,
  IonSelectOption,
  IonSpinner,
  IonTextarea,
  IonTitle,
  IonToolbar,
  useIonToast,
} from '@ionic/react';
import { useHistory, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { documentText, eye, image, people, save } from 'ionicons/icons';
import { selectChatMeta, selectChatMutedUntil, setChatMeta, setChatMutedUntil } from '@/store/chatsSlice';
import type { RootState } from '@/store/index';
import { getGroupInfo, updateGroupInfo } from '@/api/group';
import { BackButton } from '@/components/BackButton';
import { GroupProfile } from '@/components/chat/GroupProfile';
import { ChatMuteSettingItem } from '@/components/chat/settings/ChatMuteSettingItem';
import type { BackAction } from '@/types/back-action';
import styles from './ChatSettings.module.scss';
import { FeatureGate } from '@/components/FeatureGate';

interface ChatSettingsCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

interface ChatSettingsFormState {
  name: string;
  description: string;
  avatar: string;
  visibility: 'public' | 'private';
}

function getInitialFormState(cachedMeta?: {
  name?: string | null;
  description?: string | null;
  avatar?: string | null;
  visibility?: string;
}): ChatSettingsFormState {
  return {
    name: cachedMeta?.name || '',
    description: cachedMeta?.description || '',
    avatar: cachedMeta?.avatar || '',
    visibility: (cachedMeta?.visibility as 'public' | 'private') || 'public',
  };
}

interface ChatSettingsContentProps {
  chatId: string;
  formState: ChatSettingsFormState;
  mutedUntil: string | null;
  saving: boolean;
  onNameChange: (value: string) => void;
  onDescriptionChange: (value: string) => void;
  onAvatarChange: (value: string) => void;
  onVisibilityChange: (value: 'public' | 'private') => void;
  onSave: () => void;
}

function ChatSettingsContent({
  chatId,
  formState,
  mutedUntil,
  saving,
  onNameChange,
  onDescriptionChange,
  onAvatarChange,
  onVisibilityChange,
  onSave,
}: ChatSettingsContentProps) {
  return (
    <>
      <GroupProfile
        chatId={chatId}
        name={formState.name}
        description={formState.description}
        avatarUrl={formState.avatar}
      />

      <IonListHeader>
        <IonLabel>
          <Trans>Notifications</Trans>
        </IonLabel>
      </IonListHeader>
      <IonList inset>
        <ChatMuteSettingItem chatId={chatId} mutedUntil={mutedUntil} />
      </IonList>

      <FeatureGate>
        <IonListHeader>
          <IonLabel>
            <Trans>Group</Trans>
          </IonLabel>
        </IonListHeader>
        <IonList inset>
          <IonItem>
            <IonIcon aria-hidden="true" icon={people} slot="start" color="primary" />
            <IonLabel position="stacked">
              <Trans>Group Name</Trans>
            </IonLabel>
            <IonInput
              value={formState.name}
              placeholder={t`Enter group name`}
              onIonInput={(event) => onNameChange(event.detail.value ?? '')}
            />
          </IonItem>
          <IonItem>
            <IonIcon aria-hidden="true" icon={documentText} slot="start" color="tertiary" />
            <IonLabel position="stacked">
              <Trans>Description</Trans>
            </IonLabel>
            <IonTextarea
              value={formState.description}
              placeholder={t`Enter group description`}
              onIonInput={(event) => onDescriptionChange(event.detail.value ?? '')}
              rows={3}
            />
          </IonItem>
          <IonItem>
            <IonIcon aria-hidden="true" icon={image} slot="start" color="medium" />
            <IonLabel position="stacked">
              <Trans>Avatar URL</Trans>
            </IonLabel>
            <IonInput
              type="url"
              value={formState.avatar}
              placeholder={t`Enter avatar URL`}
              onIonInput={(event) => onAvatarChange(event.detail.value ?? '')}
            />
          </IonItem>
          <IonItem>
            <IonIcon aria-hidden="true" icon={eye} slot="start" color="secondary" />
            <IonLabel>
              <Trans>Visibility</Trans>
            </IonLabel>
            <IonSelect
              value={formState.visibility}
              onIonChange={(event) => onVisibilityChange(event.detail.value as 'public' | 'private')}
            >
              <IonSelectOption value="public">
                <Trans>Public</Trans>
              </IonSelectOption>
              <IonSelectOption value="private">
                <Trans>Private</Trans>
              </IonSelectOption>
            </IonSelect>
          </IonItem>
          <IonItem button detail={false} disabled={saving} onClick={onSave}>
            <IonIcon aria-hidden="true" icon={save} slot="start" color="primary" />
            <IonLabel color="primary">{saving ? <Trans>Saving...</Trans> : <Trans>Save Settings</Trans>}</IonLabel>
          </IonItem>
        </IonList>
      </FeatureGate>
    </>
  );
}

function ChatSettingsSession({ chatId, backAction }: { chatId: string; backAction?: BackAction }) {
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));
  const mutedUntil = useSelector((state: RootState) => selectChatMutedUntil(state, chatId));
  const [formState, setFormState] = useState<ChatSettingsFormState>(() => getInitialFormState(cachedMeta));
  const [loading, setLoading] = useState(() => !cachedMeta?.visibility);
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
        setFormState(getInitialFormState(meta));
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to load chat details`, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [chatId, cachedMeta, dispatch, presentToast]);

  const handleSave = () => {
    setSaving(true);

    const name = formState.name.trim();
    const description = formState.description.trim();
    const avatar = formState.avatar.trim();

    updateGroupInfo(chatId, {
      name: name || undefined,
      description: description || undefined,
      avatar: avatar || undefined,
      visibility: formState.visibility,
    })
      .then(() => {
        dispatch(
          setChatMeta({
            chatId,
            meta: {
              name: name || null,
              description: description || null,
              avatar: avatar || null,
              visibility: formState.visibility,
            },
          }),
        );
        presentToast({ message: t`Settings saved`, duration: 2000 });
        history.goBack();
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to save settings`, duration: 3000 });
      })
      .finally(() => setSaving(false));
  };

  const updateFormState = <K extends keyof ChatSettingsFormState>(key: K, value: ChatSettingsFormState[K]) => {
    setFormState((current) => ({ ...current, [key]: value }));
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
          <IonTitle>
            <Trans>Group Settings</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        {loading ? (
          <div className={styles.loadingState}>
            <IonSpinner />
          </div>
        ) : (
          <ChatSettingsContent
            chatId={chatId}
            formState={formState}
            mutedUntil={mutedUntil}
            saving={saving}
            onNameChange={(value) => updateFormState('name', value)}
            onDescriptionChange={(value) => updateFormState('description', value)}
            onAvatarChange={(value) => updateFormState('avatar', value)}
            onVisibilityChange={(value) => updateFormState('visibility', value)}
            onSave={handleSave}
          />
        )}
      </IonContent>
    </IonPage>
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
  return <ChatSettingsCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}` }} />;
}
