import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react';
import {
  useIonAlert,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
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
import {
  selectIsChatArchived,
  selectChatMeta,
  selectChatMutedUntil,
  setChatInList,
  setChatMeta,
  setChatMutedUntil,
} from '@/store/chatsSlice';
import type { RootState } from '@/store/index';
import { getGroupInfo, leaveGroup, requestGroupAvatarUploadUrl, updateGroupInfo, type GroupRole } from '@/api/group';
import { uploadFileToS3 } from '@/api/upload';
import { BackButton } from '@/components/BackButton';
import { GroupProfile } from '@/components/chat/profiles/GroupProfile';
import { ChatRoleGate } from '@/components/chat/permissions/ChatRoleGate';
import { ChatMuteSettingItem } from '@/components/chat/settings/ChatMuteSettingItem';
import type { BackAction } from '@/types/back-action';
import styles from './GroupInfo.module.scss';
import { ChatAdminSettings } from '../ChatAdminSettings';
import { ShareInviteModal } from '@/components/chat/settings/ShareInviteModal';
import { GroupSettingsActionButton } from '@/components/chat/settings/GroupSettingsActionButton';
import { ChatAttachmentSection } from '@/components/chat/attachments/ChatAttachmentSection';

interface GroupInfoCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

interface GroupInfoFormState {
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
}): GroupInfoFormState {
  return {
    name: cachedMeta?.name || '',
    description: cachedMeta?.description || '',
    avatarUrl: cachedMeta?.avatar || '',
    avatarImageId: cachedMeta?.avatarImageId || null,
    visibility: (cachedMeta?.visibility as 'public' | 'private') || 'public',
    myRole: cachedMeta?.myRole ?? null,
  };
}

interface GroupInfoContentProps {
  chatId: string;
  formState: GroupInfoFormState;
  mutedUntil: string | null;
  archived: boolean;
  myRole: GroupRole | null;
  saving: boolean;
  leavingGroup: boolean;
  uploadingAvatar: boolean;
  saveDisabled: boolean;
  onNameChange: (value: string) => void;
  onDescriptionChange: (value: string) => void;
  onVisibilityChange: (value: 'public' | 'private') => void;
  onUploadAvatar: (file: File) => Promise<void>;
  onLeaveGroup: () => void;
  onSave: () => void;
}

function GroupInfoContent({
  chatId,
  formState,
  mutedUntil,
  archived,
  myRole,
  saving,
  leavingGroup,
  uploadingAvatar,
  saveDisabled,
  onNameChange,
  onDescriptionChange,
  onVisibilityChange,
  onUploadAvatar,
  onLeaveGroup,
  onSave,
}: GroupInfoContentProps) {
  const [shareModalOpen, setShareModalOpen] = useState(false);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const canEditAvatar = myRole === 'admin';

  const handlePickAvatar = () => {
    if (!canEditAvatar || uploadingAvatar || saving) {
      return;
    }

    fileInputRef.current?.click();
  };

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) {
      return;
    }

    await onUploadAvatar(file);
  };

  return (
    <>
      <GroupProfile
        chatId={chatId}
        name={formState.name}
        description={formState.description}
        avatarUrl={formState.avatarUrl}
        avatarEditable={canEditAvatar}
        avatarUploading={uploadingAvatar}
        onAvatarClick={handlePickAvatar}
      />
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        className={styles.hiddenFileInput}
        onChange={handleFileChange}
      />

      <div className={styles.shareActions}>
        <ChatMuteSettingItem chatId={chatId} mutedUntil={mutedUntil} archived={archived} />

        <ChatRoleGate chatId={chatId} allow="admin" role={myRole}>
          <GroupSettingsActionButton icon={linkOutline} onClick={() => setShareModalOpen(true)}>
            <Trans>Invite</Trans>
          </GroupSettingsActionButton>
        </ChatRoleGate>
      </div>

      <ChatAttachmentSection chatId={chatId} />

      <ChatRoleGate chatId={chatId} allow="admin" role={myRole}>
        <ChatAdminSettings
          name={formState.name}
          description={formState.description}
          visibility={formState.visibility}
          saving={saving}
          saveDisabled={saveDisabled}
          onNameChange={onNameChange}
          onDescriptionChange={onDescriptionChange}
          onVisibilityChange={onVisibilityChange}
          onSave={onSave}
        />
      </ChatRoleGate>

      <IonList inset>
        <IonItem button detail={false} disabled={leavingGroup} onClick={onLeaveGroup}>
          <IonIcon aria-hidden="true" icon={exitOutline} slot="start" color="danger" />
          <IonLabel color="danger">{leavingGroup ? <Trans>Leaving...</Trans> : <Trans>Leave Group</Trans>}</IonLabel>
        </IonItem>
      </IonList>

      {myRole === 'admin' ? (
        <ShareInviteModal isOpen={shareModalOpen} chatId={chatId} onDismiss={() => setShareModalOpen(false)} />
      ) : null}
    </>
  );
}

function hasLoadedGroupInfoMeta(cachedMeta?: { visibility?: string; myRole?: GroupRole | null }): boolean {
  return !!cachedMeta?.visibility && cachedMeta.myRole !== undefined;
}

function getMetadataSnapshot(state: Pick<GroupInfoFormState, 'name' | 'description' | 'visibility'>) {
  return {
    name: state.name.trim(),
    description: state.description.trim(),
    visibility: state.visibility,
  };
}

function GroupInfoSession({ chatId, backAction }: { chatId: string; backAction?: BackAction }) {
  const history = useHistory();
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const [presentAlert, dismissAlert] = useIonAlert();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));
  const mutedUntil = useSelector((state: RootState) => selectChatMutedUntil(state, chatId));
  const archived = useSelector((state: RootState) => selectIsChatArchived(state, chatId));
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const [formState, setFormState] = useState<GroupInfoFormState>(() => getInitialFormState(cachedMeta));
  const [loading, setLoading] = useState(() => !hasLoadedGroupInfoMeta(cachedMeta));
  const [saving, setSaving] = useState(false);
  const [leavingGroup, setLeavingGroup] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [savedMetadataState, setSavedMetadataState] = useState(() =>
    getMetadataSnapshot(getInitialFormState(cachedMeta)),
  );
  const alertHistoryStateRef = useRef(false);
  const alertClosedByHistoryRef = useRef(false);
  const unblockRef = useRef<null | (() => void)>(null);
  const shouldBypassPromptRef = useRef(false);

  const metadataSnapshot = useMemo(() => getMetadataSnapshot(formState), [formState]);
  const hasUnsavedMetadataChanges =
    metadataSnapshot.name !== savedMetadataState.name ||
    metadataSnapshot.description !== savedMetadataState.description ||
    metadataSnapshot.visibility !== savedMetadataState.visibility;
  const saveDisabled = saving || uploadingAvatar || !hasUnsavedMetadataChanges;

  useEffect(() => {
    if (hasLoadedGroupInfoMeta(cachedMeta)) {
      return;
    }

    getGroupInfo(chatId)
      .then((res) => {
        const { id, mutedUntil, ...meta } = res.data;
        void id;
        dispatch(setChatMeta({ chatId, meta }));
        dispatch(setChatMutedUntil({ chatId, mutedUntil: mutedUntil ?? null }));
        const nextFormState = getInitialFormState(meta);
        setFormState(nextFormState);
        setSavedMetadataState(getMetadataSnapshot(nextFormState));
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

  const runBackAction = () => {
    if (!backAction) {
      return;
    }

    if (backAction.type === 'back') {
      if (history.length > 1) {
        history.goBack();
      } else {
        history.replace(backAction.defaultHref);
      }
      return;
    }

    if (backAction.type === 'callback') {
      backAction.onBack();
      return;
    }

    backAction.onClose();
  };

  const confirmDiscardChanges = useCallback(
    (onDiscard: () => void) => {
      presentAlert({
        header: t`Discard changes?`,
        message: t`You have unsaved group detail changes. Leave without saving?`,
        buttons: [
          { text: t`Stay`, role: 'cancel' },
          {
            text: t`Discard`,
            role: 'destructive',
            handler: () => {
              shouldBypassPromptRef.current = true;
              onDiscard();
            },
          },
        ],
      });
    },
    [presentAlert],
  );

  useEffect(() => {
    if (!hasUnsavedMetadataChanges) {
      shouldBypassPromptRef.current = false;
      unblockRef.current?.();
      unblockRef.current = null;
      return;
    }

    const unblock = history.block((nextLocation, action) => {
      if (shouldBypassPromptRef.current) {
        return;
      }

      confirmDiscardChanges(() => {
        unblock();
        unblockRef.current = null;
        if (action === 'REPLACE') {
          history.replace(nextLocation);
          return;
        }
        if (action === 'PUSH') {
          history.push(nextLocation);
          return;
        }
        history.goBack();
      });

      return false;
    });

    unblockRef.current = unblock;

    return () => {
      unblock();
      if (unblockRef.current === unblock) {
        unblockRef.current = null;
      }
    };
  }, [confirmDiscardChanges, hasUnsavedMetadataChanges, history]);

  useEffect(() => {
    if (!hasUnsavedMetadataChanges) {
      return;
    }

    const handleBeforeUnload = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = '';
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [hasUnsavedMetadataChanges]);

  const handleBack = () => {
    if (!hasUnsavedMetadataChanges) {
      runBackAction();
      return;
    }

    confirmDiscardChanges(() => {
      unblockRef.current?.();
      unblockRef.current = null;
      runBackAction();
    });
  };

  const handleSave = () => {
    if (saveDisabled) {
      return;
    }
    setSaving(true);

    updateGroupInfo(chatId, {
      name: metadataSnapshot.name || undefined,
      description: metadataSnapshot.description || undefined,
      avatarImageId: formState.avatarImageId,
      visibility: metadataSnapshot.visibility,
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
        const nextFormState = getInitialFormState(meta);
        setFormState(nextFormState);
        setSavedMetadataState(getMetadataSnapshot(nextFormState));
        presentToast({ message: t`Group details saved`, duration: 2000 });
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to save group info`, duration: 3000 });
      })
      .finally(() => setSaving(false));
  };

  const handleLeaveGroup = () => {
    if (!currentUserId || leavingGroup) {
      return;
    }

    if (!alertHistoryStateRef.current) {
      window.history.pushState({ alertOpen: true }, '', window.location.href);
      alertHistoryStateRef.current = true;
    }

    const handlePopState = () => {
      if (!alertHistoryStateRef.current) {
        return;
      }

      alertClosedByHistoryRef.current = true;
      alertHistoryStateRef.current = false;
      void dismissAlert();
    };

    window.addEventListener('popstate', handlePopState);

    presentAlert({
      header: t`Leave Group`,
      message: t`Are you sure you want to leave this group?`,
      backdropDismiss: true,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Leave`,
          role: 'destructive',
          handler: () => {
            alertHistoryStateRef.current = false;
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
      onDidDismiss: () => {
        window.removeEventListener('popstate', handlePopState);

        if (alertClosedByHistoryRef.current) {
          alertClosedByHistoryRef.current = false;
          return;
        }

        if (alertHistoryStateRef.current) {
          alertHistoryStateRef.current = false;
          window.history.back();
        }
      },
    });
  };

  const updateFormState = <K extends keyof GroupInfoFormState>(key: K, value: GroupInfoFormState[K]) => {
    setFormState((current) => ({ ...current, [key]: value }));
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction && <BackButton action={{ type: 'callback', onBack: handleBack }} />}
          </IonButtons>
          <IonTitle>
            <Trans>Group Info</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light" className="ion-no-padding">
        {loading ? (
          <div className={styles.loadingState}>
            <IonSpinner />
          </div>
        ) : (
          <GroupInfoContent
            chatId={chatId}
            formState={formState}
            mutedUntil={mutedUntil}
            archived={archived}
            myRole={formState.myRole}
            saving={saving}
            leavingGroup={leavingGroup}
            uploadingAvatar={uploadingAvatar}
            saveDisabled={saveDisabled}
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

export default function GroupInfoCore({ chatId: propChatId, backAction }: GroupInfoCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');

  if (!chatId) {
    return null;
  }

  return <GroupInfoSession key={chatId} chatId={chatId} backAction={backAction} />;
}

export function GroupInfoPage() {
  const { id } = useParams<{ id: string }>();
  return <GroupInfoCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}` }} />;
}
