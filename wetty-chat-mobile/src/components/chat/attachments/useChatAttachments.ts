import { useCallback, useEffect, useRef, useState } from 'react';
import { listChatAttachments, type ChatAttachmentKindFilter, type ChatAttachmentListItem } from '@/api/attachments';

const ATTACHMENT_PAGE_LIMIT = 60;

interface ChatAttachmentsState {
  cacheKey: string;
  attachments: ChatAttachmentListItem[];
  olderCursor: string | null;
  newerCursor: string | null;
  loading: boolean;
  loadingMore: boolean;
  error: string | null;
}

function dedupeAttachments(items: ChatAttachmentListItem[]) {
  const seen = new Set<string>();
  return items.filter((item) => {
    if (seen.has(item.id)) {
      return false;
    }
    seen.add(item.id);
    return true;
  });
}

export function useChatAttachments(chatId: string, kind: ChatAttachmentKindFilter) {
  const [state, setState] = useState<ChatAttachmentsState>({
    cacheKey: '',
    attachments: [],
    olderCursor: null,
    newerCursor: null,
    loading: true,
    loadingMore: false,
    error: null,
  });
  const requestIdRef = useRef(0);
  const cacheKey = `${chatId}:${kind}`;
  const isCurrentCache = state.cacheKey === cacheKey;
  const currentAttachments = isCurrentCache ? state.attachments : [];
  const currentOlderCursor = isCurrentCache ? state.olderCursor : null;
  const currentNewerCursor = isCurrentCache ? state.newerCursor : null;
  const currentLoading = !isCurrentCache || state.loading;
  const currentLoadingMore = isCurrentCache && state.loadingMore;
  const currentError = isCurrentCache ? state.error : null;

  useEffect(() => {
    const requestId = ++requestIdRef.current;
    const controller = new AbortController();

    listChatAttachments(chatId, { kind, limit: ATTACHMENT_PAGE_LIMIT }, controller.signal)
      .then((res) => {
        if (requestId !== requestIdRef.current) {
          return;
        }
        setState({
          cacheKey,
          attachments: dedupeAttachments(res.data.attachments),
          olderCursor: res.data.olderCursor,
          newerCursor: res.data.newerCursor,
          loading: false,
          loadingMore: false,
          error: null,
        });
      })
      .catch((err: Error) => {
        if (controller.signal.aborted || requestId !== requestIdRef.current) {
          return;
        }
        setState({
          cacheKey,
          attachments: [],
          olderCursor: null,
          newerCursor: null,
          loading: false,
          loadingMore: false,
          error: err.message,
        });
      });

    return () => controller.abort();
  }, [cacheKey, chatId, kind]);

  const loadOlder = useCallback(() => {
    if (currentLoading || currentLoadingMore || !currentOlderCursor) {
      return;
    }

    const requestId = ++requestIdRef.current;
    setState((current) => ({ ...current, loadingMore: true, error: null }));

    listChatAttachments(chatId, {
      kind,
      limit: ATTACHMENT_PAGE_LIMIT,
      before: currentOlderCursor,
    })
      .then((res) => {
        if (requestId !== requestIdRef.current) {
          return;
        }
        setState((current) => ({
          cacheKey,
          attachments: dedupeAttachments([...current.attachments, ...res.data.attachments]),
          olderCursor: res.data.olderCursor,
          newerCursor: res.data.newerCursor ?? current.newerCursor,
          loading: false,
          loadingMore: false,
          error: null,
        }));
      })
      .catch((err: Error) => {
        if (requestId !== requestIdRef.current) {
          return;
        }
        setState((current) => ({
          ...current,
          loadingMore: false,
          error: err.message,
        }));
      });
  }, [cacheKey, chatId, currentLoading, currentLoadingMore, currentOlderCursor, kind]);

  return {
    attachments: currentAttachments,
    olderCursor: currentOlderCursor,
    newerCursor: currentNewerCursor,
    loading: currentLoading,
    loadingMore: currentLoadingMore,
    error: currentError,
    hasOlder: currentOlderCursor != null,
    loadOlder,
  };
}
