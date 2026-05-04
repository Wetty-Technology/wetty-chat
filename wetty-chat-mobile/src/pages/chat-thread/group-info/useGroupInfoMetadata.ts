import { useEffect, useMemo, useState, type Dispatch, type SetStateAction } from 'react';
import { useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { useDispatch, useSelector } from 'react-redux';
import { getGroupInfo, type GroupRole } from '@/api/group';
import {
  selectIsChatArchived,
  selectChatMeta,
  selectChatMutedUntil,
  setChatMeta,
  setChatMutedUntil,
} from '@/store/chatsSlice';
import type { RootState } from '@/store/index';

export interface GroupInfoFormState {
  name: string;
  description: string;
  avatarUrl: string;
  avatarImageId: string | null;
  visibility: 'public' | 'private';
  myRole: GroupRole | null;
}

export function getInitialGroupInfoFormState(cachedMeta?: {
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

function hasLoadedGroupInfoMeta(cachedMeta?: { visibility?: string; myRole?: GroupRole | null }): boolean {
  return !!cachedMeta?.visibility && cachedMeta.myRole !== undefined;
}

export function useGroupInfoMetadata(chatId: string) {
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const cachedMeta = useSelector((state: RootState) => selectChatMeta(state, chatId));
  const mutedUntil = useSelector((state: RootState) => selectChatMutedUntil(state, chatId));
  const archived = useSelector((state: RootState) => selectIsChatArchived(state, chatId));
  const cachedLoaded = hasLoadedGroupInfoMeta(cachedMeta);
  const cachedFormState = useMemo(() => getInitialGroupInfoFormState(cachedMeta), [cachedMeta]);
  const [localFormState, setLocalFormState] = useState<GroupInfoFormState | null>(null);
  const [fetching, setFetching] = useState(() => !cachedLoaded);
  const formState = localFormState ?? cachedFormState;
  const loading = !cachedLoaded && fetching;

  useEffect(() => {
    if (cachedLoaded) {
      return;
    }

    getGroupInfo(chatId)
      .then((res) => {
        const { id, mutedUntil, ...meta } = res.data;
        void id;
        dispatch(setChatMeta({ chatId, meta }));
        dispatch(setChatMutedUntil({ chatId, mutedUntil: mutedUntil ?? null }));
      })
      .catch((err: Error) => {
        presentToast({ message: err.message || t`Failed to load chat details`, duration: 3000 });
      })
      .finally(() => setFetching(false));
  }, [chatId, cachedLoaded, dispatch, presentToast]);

  const setFormState: Dispatch<SetStateAction<GroupInfoFormState>> = (value) => {
    setLocalFormState((current) => {
      const baseState = current ?? cachedFormState;
      return typeof value === 'function' ? value(baseState) : value;
    });
  };

  return {
    archived,
    formState,
    loading,
    mutedUntil,
    setFormState,
  };
}
