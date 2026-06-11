import { useCallback, useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { listPins } from '@/api/pins';
import type { RootState } from '@/store';
import { selectPinsForChat, selectPinsLoaded, setPins } from '@/store/pinsSlice';

interface UseChatPinsArgs {
  chatId: string;
  threadId?: string;
}

export function useChatPins({ chatId, threadId }: UseChatPinsArgs) {
  const dispatch = useDispatch();
  const pins = useSelector((state: RootState) => selectPinsForChat(state, chatId));
  const pinsLoaded = useSelector((state: RootState) => selectPinsLoaded(state, chatId));
  const [pinListOpen, setPinListOpen] = useState(false);

  useEffect(() => {
    if (threadId || pinsLoaded) return;

    listPins(chatId)
      .then((res) => dispatch(setPins({ chatId, pins: res.data.pins })))
      .catch(() => {});
  }, [chatId, threadId, pinsLoaded, dispatch]);

  const openPinList = useCallback(() => {
    setPinListOpen(true);
  }, []);

  const closePinList = useCallback(() => {
    setPinListOpen(false);
  }, []);

  return {
    pins,
    pinListOpen,
    openPinList,
    closePinList,
  };
}
