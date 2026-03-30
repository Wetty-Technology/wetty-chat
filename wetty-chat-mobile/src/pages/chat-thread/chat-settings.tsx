import { useEffect, useState } from 'react';
import {
  useIonAlert,
  IonButtons,
  IonContent,
  IonHeader,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToolbar,
  useIonToast,
} from '@ionic/react';
import { exitOutline, linkOutline } from 'ionicons/icons';
import { useHistory, useParams } from 'react-router-dom';
import { useDispatch, useSelector } from 'react-redux';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { selectChatMeta, selectChatMutedUntil, setChatInList, setChatMeta } from '@/store/chatsSlice';
import type { RootState } from '@/store/index';
import { getGroupInfo, leaveGroup, requestGroupAvatarUploadUrl, updateGroupInfo, type GroupRole } from '@/api/group';
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
  avatarImageId?: string | null;
  avatar?: string | null;
  visibility?: string;
  myRole?: GroupRole | null;
}): ChatSettingsFormState {
  return {
    name: cachedMeta?.name || '',
    description: cachedMeta?.description || '',
    avatarUrl: cachedMeta?.avatar || '',
    avatarImageId: cachedMeta?.avatarImageId || null,
    visibility: (cachedMeta?.visibility as 'public' | 'private') || 'public',
    myRole: cachedMeta?.myRole ?? null,
  };
}

interface ChatSettingsContentProps {
  chatId: string;
  formState: ChatSettingsFormState;
  mutedUntil: string | null;
  myRole: GroupRole | null;
  saving: boolean;
  leavingGroup: boolean;
  uploadingAvatar: boolean;
  onNameChange: (value: string) => void;
  onDescriptionChange: (value: string) => void;
  onVisibilityChange: (value: 'public' | 'private') => void;
  onUploadAvatar: (file: File) => Promise<void>;
  onLeaveGroup: () => void;
  onSave: () => void;
}

function ChatSettingsContent({
  chatId,
  formState,
  mutedUntil,
  myRole,
  saving,
  leavingGroup,
  uploadingAvatar,
  onNameChange,
  onDescriptionChange,
  onVisibilityChange,
  onUploadAvatar,
  onLeaveGroup,
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
            <Trans>Invite</Trans>
          </GroupSettingsActionButton>
        </ChatRoleGate>

        <GroupSettingsActionButton icon={exitOutline} tone="danger" disabled={leavingGroup} onClick={onLeaveGroup}>
          <Trans>Leave</Trans>
        </GroupSettingsActionButton>
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

function hasLoadedChatSettingsMeta(cachedMeta?: { visibility?: string; myRole?: GroupRole | null }): boolean {
  return !!cachedMeta?.visibility && cachedMeta.myRole !== undefined;
}

function ChatSettingsSession({ chatId, backAction }: { chatId: string; backAction?: BackAction }) {
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));
  const mutedUntil = useSelector((state: RootState) => selectChatMutedUntil(state, chatId));
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const [formState, setFormState] = useState<ChatSettingsFormState>(() => getInitialFormState(cachedMeta));
  const [loading, setLoading] = useState(() => !hasLoadedChatSettingsMeta(cachedMeta));
  const [saving, setSaving] = useState(false);
  const [leavingGroup, setLeavingGroup] = useState(false);
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
        contentType: file.type || 'application/octet-stream',
        size: file.size,
      });
      const { imageId, uploadUrl, uploadHeaders } = uploadRes.data;
      await uploadFileToS3(uploadUrl, file, uploadHeaders);
      const patchRes = await updateGroupInfo(chatId, {
        avatarImageId: imageId,
      });
      const { id, ...meta } = patchRes.data;
      void id;

      dispatch(setChatMeta({ chatId, meta }));

      setFormState((current) => ({
        ...current,
        avatarImageId: imageId,
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
      avatarImageId: formState.avatarImageId,
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

  const handleLeaveGroup = () => {
    if (!currentUserId || leavingGroup) {
      return;
    }

    presentAlert({
      header: t`Leave Group`,
      message: t`Are you sure you want to leave this group?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Leave`,
          role: 'destructive',
          handler: () => {
            setLeavingGroup(true);
            leaveGroup(chatId, currentUserId)
              .then(() => {
                dispatch(setChatInList({ chatId, inList: false }));
                presentToast({ message: t`Left group`, duration: 2000 });
                history.replace('/chats');
              })
              .catch((err: Error) => {
                presentToast({ message: err.message || t`Failed to leave group`, duration: 3000 });
              })
              .finally(() => setLeavingGroup(false));
          },
        },
      ],
    });
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
            leavingGroup={leavingGroup}
            uploadingAvatar={uploadingAvatar}
            onNameChange={(value) => updateFormState('name', value)}
            onDescriptionChange={(value) => updateFormState('description', value)}
            onVisibilityChange={(value) => updateFormState('visibility', value)}
            onUploadAvatar={handleAvatarUpload}
            onLeaveGroup={handleLeaveGroup}
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
