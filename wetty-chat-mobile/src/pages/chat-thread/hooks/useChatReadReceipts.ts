import { useCallback, useEffect, useRef } from 'react';
import { markMessagesAsRead } from '@/api/messages';
import { markThreadAsRead as apiMarkThreadAsRead } from '@/api/threads';
import { READ_REQUEST_COOLDOWN_MS } from '@/constants/chatTiming';
import { usePageVisible } from '@/hooks/usePageVisible';
import { setChatLastReadMessageId, setChatUnreadCount } from '@/store/chatsSlice';
import { setThreadReadState } from '@/store/threadsSlice';
import { syncAppBadgeCount } from '@/utils/badges';
import { isPageHidden } from '@/utils/dom';
import { parseComparableMessageId } from '../chatThreadUtils';

interface ReadReceiptApi {
  markChatMessagesAsRead: typeof markMessagesAsRead;
  markThreadAsRead: typeof apiMarkThreadAsRead;
  syncBadgeCount: typeof syncAppBadgeCount;
}

const defaultApi: ReadReceiptApi = {
  markChatMessagesAsRead: markMessagesAsRead,
  markThreadAsRead: apiMarkThreadAsRead,
  syncBadgeCount: syncAppBadgeCount,
};

type DispatchLike = (action: any) => unknown;

export function useChatReadReceipts({
  chatId,
  threadId,
  storeChatId,
  initialResumeMessageId,
  lastReadMessageId,
  lastFullyVisibleMessageId,
  atBottom,
  dispatch,
  api = defaultApi,
}: {
  chatId: string;
  threadId?: string;
  storeChatId: string;
  initialResumeMessageId: string | null;
  lastReadMessageId: string | null;
  lastFullyVisibleMessageId: string | null;
  atBottom: boolean;
  dispatch: DispatchLike;
  api?: ReadReceiptApi;
}) {
  const lastReportedReadId = useRef<string | null>(null);
  const initialLoadCompletedRef = useRef(false);
  const readRequestTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingReadTargetIdRef = useRef<string | null>(null);
  const lastReadRequestAtRef = useRef(0);
  const threadReadTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastThreadReadIdRef = useRef<string | null>(null);
  const pendingThreadReadIdRef = useRef<string | null>(null);

  useEffect(() => {
    lastReportedReadId.current = null;
    initialLoadCompletedRef.current = false;
    pendingReadTargetIdRef.current = null;
    lastReadRequestAtRef.current = 0;
    if (readRequestTimerRef.current) {
      clearTimeout(readRequestTimerRef.current);
      readRequestTimerRef.current = null;
    }

    lastThreadReadIdRef.current = null;
    pendingThreadReadIdRef.current = null;
    if (threadReadTimerRef.current) {
      clearTimeout(threadReadTimerRef.current);
      threadReadTimerRef.current = null;
    }
  }, [storeChatId]);

  const flushPendingReadTarget = useCallback(() => {
    if (threadId || !chatId) return;
    if (isPageHidden()) return;

    const targetMessageId = pendingReadTargetIdRef.current;
    if (!targetMessageId) return;

    const targetComparableId = parseComparableMessageId(targetMessageId);
    if (targetComparableId == null) {
      pendingReadTargetIdRef.current = null;
      return;
    }

    const currentReadComparableId = lastReadMessageId ? parseComparableMessageId(lastReadMessageId) : null;
    if (currentReadComparableId != null && targetComparableId <= currentReadComparableId) {
      pendingReadTargetIdRef.current = null;
      return;
    }

    if (targetMessageId === lastReportedReadId.current) return;

    pendingReadTargetIdRef.current = null;
    readRequestTimerRef.current = null;
    lastReportedReadId.current = targetMessageId;
    lastReadRequestAtRef.current = Date.now();

    api
      .markChatMessagesAsRead(chatId, targetMessageId)
      .then((res) => {
        dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: res.data.lastReadMessageId }));
        dispatch(setChatUnreadCount({ chatId, unreadCount: res.data.unreadCount }));
        void api.syncBadgeCount();
      })
      .catch((err) => {
        console.error('Failed to mark as read', err);
        lastReportedReadId.current = null;
      });
  }, [api, chatId, dispatch, lastReadMessageId, threadId]);

  const flushPendingThreadRead = useCallback(() => {
    if (!threadId || !chatId) return;
    const targetId = pendingThreadReadIdRef.current;
    if (!targetId || isPageHidden()) return;
    pendingThreadReadIdRef.current = null;
    threadReadTimerRef.current = null;
    lastThreadReadIdRef.current = targetId;
    api
      .markThreadAsRead(threadId, targetId)
      .then((res) => {
        dispatch(
          setThreadReadState({
            threadRootId: threadId,
            lastReadMessageId: res.data.lastReadMessageId,
            unreadCount: res.data.unreadCount,
          }),
        );
      })
      .catch((err) => {
        console.error('Failed to mark thread as read', err);
        lastThreadReadIdRef.current = null;
      });
  }, [api, chatId, dispatch, threadId]);

  useEffect(() => {
    if (threadId || !chatId) return;
    if (initialResumeMessageId == null && lastReadMessageId == null && atBottom) return;

    if (readRequestTimerRef.current) {
      clearTimeout(readRequestTimerRef.current);
      readRequestTimerRef.current = null;
    }

    pendingReadTargetIdRef.current = lastFullyVisibleMessageId;
    if (!lastFullyVisibleMessageId) return;

    const targetComparableId = parseComparableMessageId(lastFullyVisibleMessageId);
    if (targetComparableId == null) {
      pendingReadTargetIdRef.current = null;
      return;
    }

    const currentReadComparableId = lastReadMessageId ? parseComparableMessageId(lastReadMessageId) : null;
    if (currentReadComparableId != null && targetComparableId <= currentReadComparableId) {
      pendingReadTargetIdRef.current = null;
      return;
    }

    const elapsed = Date.now() - lastReadRequestAtRef.current;
    if (elapsed >= READ_REQUEST_COOLDOWN_MS) {
      flushPendingReadTarget();
      return;
    }

    readRequestTimerRef.current = setTimeout(flushPendingReadTarget, READ_REQUEST_COOLDOWN_MS - elapsed);

    return () => {
      if (readRequestTimerRef.current) {
        clearTimeout(readRequestTimerRef.current);
        readRequestTimerRef.current = null;
      }
    };
  }, [
    atBottom,
    chatId,
    flushPendingReadTarget,
    initialResumeMessageId,
    lastFullyVisibleMessageId,
    lastReadMessageId,
    threadId,
  ]);

  usePageVisible(() => {
    if (!chatId) return;
    if (threadId) {
      flushPendingThreadRead();
    } else {
      flushPendingReadTarget();
    }
  });

  useEffect(() => {
    if (!threadId || !chatId) return;
    if (!lastFullyVisibleMessageId) return;
    if (lastFullyVisibleMessageId === lastThreadReadIdRef.current) return;

    const targetComparableId = parseComparableMessageId(lastFullyVisibleMessageId);
    if (targetComparableId == null) return;

    if (threadReadTimerRef.current) {
      clearTimeout(threadReadTimerRef.current);
    }

    pendingThreadReadIdRef.current = lastFullyVisibleMessageId;
    threadReadTimerRef.current = setTimeout(flushPendingThreadRead, READ_REQUEST_COOLDOWN_MS);

    return () => {
      if (threadReadTimerRef.current) {
        clearTimeout(threadReadTimerRef.current);
        threadReadTimerRef.current = null;
      }
    };
  }, [chatId, threadId, lastFullyVisibleMessageId, flushPendingThreadRead]);
}
