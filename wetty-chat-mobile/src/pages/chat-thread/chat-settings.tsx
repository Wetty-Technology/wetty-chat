import { useEffect, useState } from 'react';
import {
  IonButtons,
  IonContent,
  IonHeader,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToolbar,
  useIonToast,
} from '@ionic/react';
import { linkOutline } from 'ionicons/icons';
import { useHistory, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { selectChatMeta, selectChatMutedUntil, setChatMeta } from '@/store/chatsSlice';
import type { RootState } from '@/store/index';
import { getGroupInfo, requestGroupAvatarUploadUrl, updateGroupInfo, type GroupRole } from '@/api/group';
import { uploadFileToS3 } from '@/api/upload';
import { BackButton } from '@/components/BackButton';
import { GroupProfile } from '@/components/chat/GroupProfile';
import { ChatRoleGate } from '@/components/chat/permissions/ChatRoleGate';
import { ChatMuteSettingItem } from '@/components/chat/settings/ChatMuteSettingItem';
import type { BackAction } from '@/types/back-action';
import styles from './ChatSettings.module.scss';
import { FeatureGate } from '@/components/FeatureGate';
import { ChatAdminSettings } from './ChatAdminSettings';
import { ShareInviteModal } from '@/components/chat/settings/ShareInviteModal';
import { GroupSettingsActionButton } from '@/components/chat/settings/GroupSettingsActionButton';

interface ChatSettingsCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

interface ChatSettingsFormState {
  name: string;
  description: string;
  avatarUrl: string;
  avatarImageId: string | null;
  visibility: 'public' | 'private';
  myRole: GroupRole | null;
}

function getInitialFormState(cachedMeta?: {
  name?: string | null;
  description?: string | null;
  avatar_image_id?: string | null;
  avatar?: string | null;
  visibility?: string;
  my_role?: GroupRole | null;
}): ChatSettingsFormState {
  return {
    name: cachedMeta?.name || '',
    description: cachedMeta?.description || '',
    avatarUrl: cachedMeta?.avatar || '',
    avatarImageId: cachedMeta?.avatar_image_id || null,
    visibility: (cachedMeta?.visibility as 'public' | 'private') || 'public',
    myRole: cachedMeta?.my_role ?? null,
  };
}

interface ChatSettingsContentProps {
  chatId: string;
  formState: ChatSettingsFormState;
  mutedUntil: string | null;
  myRole: GroupRole | null;
  saving: boolean;
  uploadingAvatar: boolean;
  onNameChange: (value: string) => void;
  onDescriptionChange: (value: string) => void;
  onVisibilityChange: (value: 'public' | 'private') => void;
  onUploadAvatar: (file: File) => Promise<void>;
  onSave: () => void;
}

function ChatSettingsContent({
  chatId,
  formState,
  mutedUntil,
  myRole,
  saving,
  uploadingAvatar,
  onNameChange,
  onDescriptionChange,
  onVisibilityChange,
  onUploadAvatar,
  onSave,
}: ChatSettingsContentProps) {
  const [shareModalOpen, setShareModalOpen] = useState(false);

  return (
    <>
      <GroupProfile
        chatId={chatId}
        name={formState.name}
        description={formState.description}
        avatarUrl={formState.avatarUrl}
      />

      <div className={styles.shareActions}>
        <ChatMuteSettingItem chatId={chatId} mutedUntil={mutedUntil} />

        <ChatRoleGate chatId={chatId} allow="admin" role={myRole}>
          <GroupSettingsActionButton icon={linkOutline} onClick={() => setShareModalOpen(true)}>
            <Trans>Invite Link</Trans>
          </GroupSettingsActionButton>
        </ChatRoleGate>
      </div>

      <FeatureGate>
        <ChatAdminSettings
          name={formState.name}
          description={formState.description}
          visibility={formState.visibility}
          avatarUrl={formState.avatarUrl}
          saving={saving}
          uploadingAvatar={uploadingAvatar}
          onNameChange={onNameChange}
          onDescriptionChange={onDescriptionChange}
          onVisibilityChange={onVisibilityChange}
          onUploadAvatar={onUploadAvatar}
          onSave={onSave}
        />
      </FeatureGate>

      {myRole === 'admin' ? (
        <ShareInviteModal isOpen={shareModalOpen} chatId={chatId} onDismiss={() => setShareModalOpen(false)} />
      ) : null}
    </>
  );
}

function hasLoadedChatSettingsMeta(cachedMeta?: {
  visibility?: string;
  my_role?: GroupRole | null;
}): boolean {
  return !!cachedMeta?.visibility && cachedMeta.my_role !== undefined;
}

function ChatSettingsSession({ chatId, backAction }: { chatId: string; backAction?: BackAction }) {
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));
  const mutedUntil = useSelector((state: RootState) => selectChatMutedUntil(state, chatId));
  const [formState, setFormState] = useState<ChatSettingsFormState>(() => getInitialFormState(cachedMeta));
  const [loading, setLoading] = useState(() => !hasLoadedChatSettingsMeta(cachedMeta));
  const [saving, setSaving] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);

  useEffect(() => {
    if (hasLoadedChatSettingsMeta(cachedMeta)) {
      return;
    }

    getGroupInfo(chatId)
      .then((res) => {
        const { id, ...meta } = res.data;
        void id;
        dispatch(setChatMeta({ chatId, meta }));
        setFormState(getInitialFormState(meta));
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to load chat details`, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [chatId, cachedMeta, dispatch, presentToast]);

  useEffect(() => {
    return () => {
      if (!formState.avatarUrl.startsWith('blob:')) return;
      URL.revokeObjectURL(formState.avatarUrl);
    };
  }, [formState.avatarUrl]);

  const handleAvatarUpload = async (file: File) => {
    if (!file.type.startsWith('image/')) {
      presentToast({ message: t`Please choose an image file`, duration: 3000 });
      return;
    }

    const previousAvatarUrl = formState.avatarUrl;
    const nextPreviewUrl = URL.createObjectURL(file);
    const previousPreviewUrl = previousAvatarUrl.startsWith('blob:') ? previousAvatarUrl : null;

    setUploadingAvatar(true);
    setFormState((current) => ({
      ...current,
      avatarUrl: nextPreviewUrl,
    }));

    try {
      const uploadRes = await requestGroupAvatarUploadUrl(chatId, {
        filename: file.name,
        content_type: file.type || 'application/octet-stream',
        size: file.size,
      });
      const { image_id, upload_url, upload_headers } = uploadRes.data;
      await uploadFileToS3(upload_url, file, upload_headers);
      const patchRes = await updateGroupInfo(chatId, {
        avatar_image_id: image_id,
      });
      const { id, ...meta } = patchRes.data;
      void id;

      dispatch(setChatMeta({ chatId, meta }));

      setFormState((current) => ({
        ...current,
        avatarImageId: image_id,
        avatarUrl: meta.avatar || current.avatarUrl,
      }));

      if (previousPreviewUrl) {
        URL.revokeObjectURL(previousPreviewUrl);
      }
      presentToast({ message: t`Avatar uploaded`, duration: 2000 });
    } catch (err) {
      URL.revokeObjectURL(nextPreviewUrl);
      setFormState((current) => ({
        ...current,
        avatarUrl: previousAvatarUrl,
      }));
      presentToast({ message: err instanceof Error ? err.message : t`Failed to upload avatar`, duration: 3000 });
    } finally {
      setUploadingAvatar(false);
    }
  };

  const handleSave = () => {
    if (uploadingAvatar) {
      return;
    }
    setSaving(true);

    const name = formState.name.trim();
    const description = formState.description.trim();

    updateGroupInfo(chatId, {
      name: name || undefined,
      description: description || undefined,
      avatar_image_id: formState.avatarImageId,
      visibility: formState.visibility,
    })
      .then((res) => {
        const { id, ...meta } = res.data;
        void id;
        dispatch(
          setChatMeta({
            chatId,
            meta,
          }),
        );
        setFormState(getInitialFormState(meta));
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
            myRole={formState.myRole}
            saving={saving}
            uploadingAvatar={uploadingAvatar}
            onNameChange={(value) => updateFormState('name', value)}
            onDescriptionChange={(value) => updateFormState('description', value)}
            onVisibilityChange={(value) => updateFormState('visibility', value)}
            onUploadAvatar={handleAvatarUpload}
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
