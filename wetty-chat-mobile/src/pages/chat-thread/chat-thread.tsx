import { startTransition, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  IonButton,
  IonButtons,
  IonContent,
  IonFab,
  IonFabButton,
  IonFooter,
  IonHeader,
  IonIcon,
  IonPage,
  IonProgressBar,
  IonTitle,
  IonToolbar,
  useIonAlert,
  useIonToast,
} from '@ionic/react';
import { useHistory, useLocation, useParams } from 'react-router-dom';
import {
  arrowUndo,
  chatbubbles,
  chevronDown,
  copyOutline,
  createOutline,
  informationCircleOutline,
  notificationsOffOutline,
  linkOutline,
  notifications,
  people,
  trashOutline,
} from 'ionicons/icons';
import { useDispatch, useSelector } from 'react-redux';
import {
  type Attachment,
  deleteMessage,
  deleteReaction,
  getMessages,
  markMessagesAsRead,
  type MessageResponse,
  putReaction,
  type Sender,
  sendMessage,
  sendThreadMessage,
  updateMessage,
} from '@/api/messages';
import {
  selectChatLastReadMessageId,
  selectChatName,
  selectIsChatMuted,
  setChatLastReadMessageId,
  setChatMeta,
  setChatMutedUntil,
  setChatUnreadCount,
} from '@/store/chatsSlice';
import {
  appendMessages,
  prependMessages,
  pushWindow,
  refreshLatest,
  resetChat,
  selectChatGeneration,
  selectMessagesForChat,
  selectNextCursorForChat,
  selectPrevCursorForChat,
} from '@/store/messagesSlice';
import { messageAdded, messageConfirmed, messagePatched, reactionsUpdated } from '@/store/messageEvents';
import type { RootState } from '@/store/index';
import store from '@/store/index';
import { ChatVirtualScroll } from '@/components/chat/ChatVirtualScroll';
import type { ChatRow, VirtualScrollAnchor, VirtualScrollHandle } from '@/components/chat/virtualScroll/types';
import { useChatRows } from '@/components/chat/useChatRows';
import {
  type ComposeSendPayload,
  type MessageComposeBarHandle,
  type ComposeUploadedAttachment,
  type ComposeUploadInput,
  type EditingMessage,
  MessageComposeBar,
} from '@/components/chat/MessageComposeBar';
import './chat-thread.scss';
import { t } from '@lingui/core/macro';
import { UserProfileModal } from '@/components/chat/UserProfileModal';
import { MessageOverlay, type MessageOverlayAction } from '@/components/chat/MessageOverlay';
import { ReactionDetailsModal } from '@/components/chat/ReactionDetailsModal';
import { StickerPreviewModal } from '@/components/chat/StickerPreviewModal';
import { getGroupInfo } from '@/api/group';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';
import { requestUploadUrl, uploadFileToS3 } from '@/api/upload';
import { syncAppBadgeCount } from '@/utils/badges';
import { buildPermalinkUrl } from '@/utils/permalinkUrl';
import { useIsDesktop } from '@/hooks/platformHooks';
import { useChatRole } from '@/components/chat/permissions/useChatRole';
import { ChatMessageRow } from '@/components/chat/messages/ChatMessageRow';
import type { ChatThreadRouteState, ChatThreadResumeRequest } from '@/types/chatThreadNavigation';
import { READ_REQUEST_COOLDOWN_MS } from '@/constants/chatTiming';
import {
  markThreadAsRead as apiMarkThreadAsRead,
  getThreadSubscriptionStatus,
  subscribeToThread,
  unsubscribeFromThread,
} from '@/api/threads';
import { markThreadRead as markThreadReadAction, removeThread } from '@/store/threadsSlice';

const QUICK_REACTION_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🎉'];

function generateClientId(): string {
  return `cg_${Date.now()}_${Math.random().toString(36).slice(2)}`;
}

function parseComparableMessageId(messageId: string): bigint | null {
  if (!/^\d+$/.test(messageId)) return null;
  return BigInt(messageId);
}

function areAttachmentIdsEqual(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function areMessageListsEquivalent(left: MessageResponse[], right: MessageResponse[]): boolean {
  return (
    left.length === right.length &&
    left.every((message, index) => {
      const candidate = right[index];
      return candidate != null && message.id === candidate.id;
    })
  );
}

function isAudioMessage(message: MessageResponse): boolean {
  return message.messageType === 'audio';
}

function buildOptimisticUploadedAttachments(uploadedAttachments: ComposeUploadedAttachment[]): {
  attachments: Attachment[];
  revoke: () => void;
} {
  const previewUrls: string[] = [];
  const attachments = uploadedAttachments.map((attachment) => {
    const previewUrl = URL.createObjectURL(attachment.file);
    previewUrls.push(previewUrl);

    return {
      id: attachment.attachmentId,
      url: previewUrl,
      kind: attachment.mimeType,
      size: attachment.size,
      fileName: attachment.file.name,
      width: attachment.width ?? null,
      height: attachment.height ?? null,
    };
  });

  return {
    attachments,
    revoke: () => {
      previewUrls.forEach((previewUrl) => URL.revokeObjectURL(previewUrl));
    },
  };
}

interface ChatThreadCoreProps {
  chatId: string;
  threadId?: string;
  backAction?: BackAction;
}

interface EditSession extends EditingMessage {
  originalMessage: MessageResponse;
}

function ChatThreadCore({ chatId, threadId, backAction }: ChatThreadCoreProps) {
  const storeChatId = threadId ? `${chatId}_thread_${threadId}` : chatId;
  const history = useHistory();
  const location = useLocation<ChatThreadRouteState | undefined>();
  const initialResumeRequest = location.state?.resumeRequest ?? null;

  const dispatch = useDispatch();
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const currentUserName = useSelector((state: RootState) => state.user.username);
  const currentUserAvatarUrl = useSelector((state: RootState) => state.user.avatarUrl);
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);
  const isDesktop = useIsDesktop();
  const { role: myRole } = useChatRole(chatId);
  const isAdmin = myRole === 'admin';
  const storedName = useSelector((state: RootState) => selectChatName(state, chatId));
  const isMuted = useSelector((state: RootState) => selectIsChatMuted(state, chatId));
  const lastReadMessageId = useSelector((state: RootState) => selectChatLastReadMessageId(state, chatId));
  const chatName = threadId ? t`Thread` : (storedName ?? t`Loading...`);

  useEffect(() => {
    if (!chatId || storedName != null) return;
    getGroupInfo(chatId)
      .then((res) => {
        const { id, mutedUntil, ...meta } = res.data;
        void id;
        dispatch(setChatMeta({ chatId: chatId, meta }));
        dispatch(setChatMutedUntil({ chatId, mutedUntil: mutedUntil ?? null }));
      })
      .catch(() => {});
  }, [chatId, storedName, dispatch]);
  const messages = useSelector((state: RootState) => selectMessagesForChat(state, storeChatId));
  const messageLookup = useMemo(() => new Map(messages.map((message) => [message.id, message])), [messages]);

  const formatDateSeparator = useCallback((iso: string) => {
    if (!iso) return '';
    const date = new Date(iso);
    const now = new Date();

    const isSameDay = (d1: Date, d2: Date) =>
      d1.getFullYear() === d2.getFullYear() && d1.getMonth() === d2.getMonth() && d1.getDate() === d2.getDate();

    if (isSameDay(date, now)) return t`Today`;

    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    if (isSameDay(date, yesterday)) return t`Yesterday`;

    return date.toLocaleDateString(undefined, {
      year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined,
      month: 'short',
      day: 'numeric',
    });
  }, []);

  const scrollApiRef = useRef<VirtualScrollHandle | null>(null);
  const composeBarRef = useRef<MessageComposeBarHandle | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [loadingNewer, setLoadingNewer] = useState(false);
  const loadingMoreRef = useRef(false);
  const loadingNewerRef = useRef(false);
  const pendingSendScrollKeyRef = useRef<string | null>(null);
  const [initialAnchor, setInitialAnchor] = useState<VirtualScrollAnchor>({ type: 'bottom', token: 0 });
  const [pendingResumeRequest, setPendingResumeRequest] = useState<ChatThreadResumeRequest | null>(
    initialResumeRequest,
  );
  const [lastFullyVisibleMessageId, setLastFullyVisibleMessageId] = useState<string | null>(null);

  const chatRows = useChatRows(messages, formatDateSeparator);

  // Thread subscription state
  const [threadSubscribed, setThreadSubscribed] = useState<boolean | null>(null);
  const [threadSubLoading, setThreadSubLoading] = useState(false);

  useEffect(() => {
    if (!threadId || !chatId) return;
    setThreadSubscribed(null);
    getThreadSubscriptionStatus(chatId, threadId)
      .then((res) => setThreadSubscribed(res.data.subscribed))
      .catch(() => setThreadSubscribed(null));
  }, [chatId, threadId]);

  const handleToggleThreadSubscription = useCallback(async () => {
    if (!threadId || !chatId || threadSubscribed == null) return;
    setThreadSubLoading(true);
    try {
      if (threadSubscribed) {
        await unsubscribeFromThread(chatId, threadId);
        setThreadSubscribed(false);
        dispatch(removeThread({ threadRootId: threadId }));
      } else {
        await subscribeToThread(chatId, threadId);
        setThreadSubscribed(true);
      }
    } catch (err) {
      console.error('Failed to toggle thread subscription', err);
    } finally {
      setThreadSubLoading(false);
    }
  }, [chatId, threadId, threadSubscribed, dispatch]);

  const [atBottom, setAtBottom] = useState(() => threadId || initialResumeRequest == null);
  const [replyingTo, setReplyingTo] = useState<MessageResponse | null>(null);
  const [profileSender, setProfileSender] = useState<Sender | null>(null);
  const [reactionDetail, setReactionDetail] = useState<{ messageId: string; emoji?: string } | null>(null);
  const [stickerPreviewId, setStickerPreviewId] = useState<string | null>(null);
  const [editingSession, setEditingSession] = useState<EditSession | null>(null);
  const [composeFocused, setComposeFocused] = useState(false);
  const [baselineViewportHeight, setBaselineViewportHeight] = useState<number>(
    () => window.visualViewport?.height ?? window.innerHeight,
  );
  const [viewportHeight, setViewportHeight] = useState<number>(
    () => window.visualViewport?.height ?? window.innerHeight,
  );

  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const [overlayMessage, setOverlayMessage] = useState<{ message: MessageResponse; sourceRect: DOMRect } | null>(null);

  useEffect(() => {
    if (!import.meta.env.DEV) return;
    console.log('[ChatThread] view-mounted', {
      chatId,
      storeChatId,
      threadId: threadId ?? null,
    });
    return () => {
      console.log('[ChatThread] view-unmounted', {
        chatId,
        storeChatId,
        threadId: threadId ?? null,
      });
    };
  }, [chatId, storeChatId, threadId]);

  useEffect(() => {
    if (isDesktop) return;

    const visualViewport = window.visualViewport;
    const getViewportHeight = () => visualViewport?.height ?? window.innerHeight;
    const updateViewportMetrics = () => {
      const nextViewportHeight = getViewportHeight();
      setViewportHeight(nextViewportHeight);
      if (!composeFocused) {
        setBaselineViewportHeight(nextViewportHeight);
      }
    };

    const target = visualViewport ?? window;
    target.addEventListener('resize', updateViewportMetrics);

    return () => {
      target.removeEventListener('resize', updateViewportMetrics);
    };
  }, [composeFocused, isDesktop]);

  const handleComposeFocusChange = useCallback((focused: boolean) => {
    setComposeFocused(focused);
    if (!focused) {
      setBaselineViewportHeight(window.visualViewport?.height ?? window.innerHeight);
    }
  }, []);

  useEffect(() => {
    if (!import.meta.env.DEV) return;
    console.log('[ChatThread] rows-changed', {
      chatId,
      storeChatId,
      messageCount: messages.length,
      firstMessageId: messages[0]?.id ?? null,
      lastMessageId: messages[messages.length - 1]?.id ?? null,
      rowCount: chatRows.length,
      initialAnchor,
    });
  }, [chatId, storeChatId, messages, chatRows.length, initialAnchor]);

  useEffect(() => {
    const pendingKey = pendingSendScrollKeyRef.current;
    if (!pendingKey) return;
    if (!chatRows.some((row) => row.key === pendingKey)) return;

    if (import.meta.env.DEV) {
      console.log('[ChatThread] execute-pending-send-scroll', {
        chatId,
        storeChatId,
        threadId: threadId ?? null,
        pendingKey,
      });
    }

    scrollApiRef.current?.scrollToBottom({
      behavior: 'smooth',
      ifAlreadyMountedKey: pendingKey,
      fallbackBehavior: 'auto',
      source: 'chat-thread-send',
    });
    pendingSendScrollKeyRef.current = null;
  }, [chatId, chatRows, storeChatId, threadId]);

  const getMessageKey = useCallback((message: MessageResponse) => `msg:${message.clientGeneratedId || message.id}`, []);

  const startEditingMessage = useCallback((message: MessageResponse) => {
    setReplyingTo(null);
    setEditingSession({
      messageId: message.id,
      text: message.message ?? '',
      attachments: message.attachments,
      originalMessage: { ...message },
    });
  }, []);

  const requestEditLastOwnMessage = useCallback(() => {
    if (editingSession || replyingTo) return false;

    const recentMessages = messages.slice(-30);
    const lastOwnMessage = [...recentMessages]
      .reverse()
      .find((message) => message.sender.uid === currentUserId && !message.isDeleted);

    if (!lastOwnMessage) {
      return false;
    }

    startEditingMessage(lastOwnMessage);
    return true;
  }, [currentUserId, editingSession, messages, replyingTo, startEditingMessage]);

  // Auto-focus compose input when entering reply or edit mode
  useEffect(() => {
    if (replyingTo || editingSession) {
      requestAnimationFrame(() => {
        composeBarRef.current?.focusInput();
      });
    }
  }, [replyingTo, editingSession]);

  const showToast = useCallback(
    (
      text: string,
      duration = 3000,
      options?: {
        positionAnchor?: string;
      },
    ) => {
      presentToast({
        message: text,
        duration,
        position: 'bottom',
        positionAnchor: options?.positionAnchor,
      });
    },
    [presentToast],
  );

  const lastReportedReadId = useRef<string | null>(null);
  const consumedResumeTokenRef = useRef<string | null>(null);
  const initialLoadCompletedRef = useRef(false);
  const readRequestTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pendingReadTargetIdRef = useRef<string | null>(null);
  const lastReadRequestAtRef = useRef(0);

  useEffect(() => {
    lastReportedReadId.current = null;
    consumedResumeTokenRef.current = null;
    initialLoadCompletedRef.current = false;
    pendingReadTargetIdRef.current = null;
    lastReadRequestAtRef.current = 0;
    if (readRequestTimerRef.current) {
      clearTimeout(readRequestTimerRef.current);
      readRequestTimerRef.current = null;
    }
  }, [storeChatId]);

  const flushPendingReadTarget = useCallback(() => {
    if (threadId || !chatId) return;

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

    markMessagesAsRead(chatId, targetMessageId)
      .then((res) => {
        dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: res.data.lastReadMessageId }));
        dispatch(setChatUnreadCount({ chatId, unreadCount: res.data.unreadCount }));
        void syncAppBadgeCount();
      })
      .catch((err) => {
        console.error('Failed to mark as read', err);
        lastReportedReadId.current = null;
      });
  }, [chatId, dispatch, lastReadMessageId, threadId]);

  useEffect(() => {
    if (threadId || !chatId) return;

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
  }, [chatId, flushPendingReadTarget, lastFullyVisibleMessageId, lastReadMessageId, threadId]);

  // Thread-specific mark-as-read: fires when viewing a thread and messages become visible.
  // Unlike chat read tracking (which is purely scroll-based), this also fires on mount
  // once the initial messages are rendered and the last visible message is known.
  const threadReadTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastThreadReadIdRef = useRef<string | null>(null);

  useEffect(() => {
    if (!threadId || !chatId) return;
    if (!lastFullyVisibleMessageId) return;
    if (lastFullyVisibleMessageId === lastThreadReadIdRef.current) return;

    // Debounce to avoid excessive API calls during rapid scrolling
    if (threadReadTimerRef.current) {
      clearTimeout(threadReadTimerRef.current);
    }

    threadReadTimerRef.current = setTimeout(() => {
      threadReadTimerRef.current = null;
      lastThreadReadIdRef.current = lastFullyVisibleMessageId;
      apiMarkThreadAsRead(threadId, lastFullyVisibleMessageId)
        .then(() => {
          dispatch(markThreadReadAction({ threadRootId: threadId }));
        })
        .catch((err) => {
          console.error('Failed to mark thread as read', err);
          lastThreadReadIdRef.current = null;
        });
    }, READ_REQUEST_COOLDOWN_MS);

    return () => {
      if (threadReadTimerRef.current) {
        clearTimeout(threadReadTimerRef.current);
        threadReadTimerRef.current = null;
      }
    };
  }, [chatId, threadId, lastFullyVisibleMessageId, dispatch]);

  // Reset thread read state when switching threads
  useEffect(() => {
    lastThreadReadIdRef.current = null;
    if (threadReadTimerRef.current) {
      clearTimeout(threadReadTimerRef.current);
      threadReadTimerRef.current = null;
    }
  }, [storeChatId]);

  useEffect(() => {
    const resumeRequest = location.state?.resumeRequest;
    if (!resumeRequest) return;
    if (resumeRequest.token === consumedResumeTokenRef.current) return;

    consumedResumeTokenRef.current = resumeRequest.token;
    startTransition(() => {
      setPendingResumeRequest(resumeRequest);
      setAtBottom(false);
    });

    const { resumeRequest: _resumeRequest, ...restState } = location.state ?? {};
    void _resumeRequest;
    const nextState = Object.keys(restState).length > 0 ? restState : undefined;
    history.replace({
      pathname: location.pathname,
      search: location.search,
      hash: location.hash,
      state: nextState,
    });
  }, [history, location]);

  const fetchLatestWindow = useCallback(
    (options?: { forceReopen?: boolean }) => {
      const forceReopen = options?.forceReopen ?? false;
      if (!chatId) return;
      if (import.meta.env.DEV) {
        console.log('[ChatThread] fetchLatestWindow:start', {
          chatId,
          storeChatId,
          threadId: threadId ?? null,
          forceReopen,
        });
      }
      getMessages(chatId, threadId ? { threadId } : undefined)
        .then((res) => {
          const list = res.data.messages ?? [];
          const nextCursor = res.data.nextCursor ?? null;
          const prevCursor = null;
          const currentState = store.getState();
          const currentMessages = selectMessagesForChat(currentState, storeChatId);
          const currentNextCursor = selectNextCursorForChat(currentState, storeChatId);
          const currentPrevCursor = selectPrevCursorForChat(currentState, storeChatId);
          const shouldResetAnchor =
            forceReopen ||
            !areMessageListsEquivalent(currentMessages, list) ||
            nextCursor !== currentNextCursor ||
            prevCursor !== currentPrevCursor;
          if (import.meta.env.DEV) {
            console.log('[ChatThread] fetchLatestWindow:resolved', {
              chatId,
              storeChatId,
              threadId: threadId ?? null,
              forceReopen,
              fetchedCount: list.length,
              firstMessageId: list[0]?.id ?? null,
              lastMessageId: list[list.length - 1]?.id ?? null,
              nextCursor,
              prevCursor,
              currentMessageCount: currentMessages.length,
              currentFirstMessageId: currentMessages[0]?.id ?? null,
              currentLastMessageId: currentMessages[currentMessages.length - 1]?.id ?? null,
              shouldResetAnchor,
            });
          }
          dispatch(
            refreshLatest({
              chatId: storeChatId,
              messages: list,
              nextCursor,
              prevCursor,
            }),
          );

          if (shouldResetAnchor) {
            setInitialAnchor((currentAnchor) => {
              const nextAnchor = { type: 'bottom' as const, token: currentAnchor.token + 1 };
              if (import.meta.env.DEV) {
                console.log('[ChatThread] initialAnchor-reset', {
                  reason: forceReopen ? 'fetchLatestWindow-forceReopen' : 'fetchLatestWindow-dataChanged',
                  previous: currentAnchor,
                  next: nextAnchor,
                  chatId,
                  storeChatId,
                });
              }
              return nextAnchor;
            });
          } else if (import.meta.env.DEV) {
            console.log('[ChatThread] initialAnchor-preserved', {
              reason: 'fetchLatestWindow-equivalentWindow',
              chatId,
              storeChatId,
            });
          }
        })
        .catch((err: Error) => {
          dispatch(resetChat({ chatId: storeChatId, messages: [], nextCursor: null, prevCursor: null }));
          setInitialAnchor((currentAnchor) => {
            const nextAnchor = { type: 'bottom' as const, token: currentAnchor.token + 1 };
            if (import.meta.env.DEV) {
              console.log('[ChatThread] initialAnchor-reset', {
                reason: 'fetchLatestWindow-error',
                previous: currentAnchor,
                next: nextAnchor,
                chatId,
                storeChatId,
              });
            }
            return nextAnchor;
          });
          showToast(err.message || t`Failed to load messages`);
        });
    },
    [chatId, dispatch, showToast, storeChatId, threadId],
  );

  // Initial load — open at an explicitly requested resume point when navigated from chat list
  useEffect(() => {
    if (!chatId) return;

    if (!threadId && pendingResumeRequest != null) {
      initialLoadCompletedRef.current = true;
      getMessages(chatId, { around: pendingResumeRequest.messageId, max: 50 })
        .then((res) => {
          const list = res.data.messages ?? [];
          dispatch(
            pushWindow({
              chatId: storeChatId,
              messages: list,
              nextCursor: res.data.nextCursor ?? null,
              prevCursor: res.data.prevCursor ?? null,
            }),
          );
          setInitialAnchor((currentAnchor) => ({
            type: 'message',
            messageId: pendingResumeRequest.messageId,
            token: currentAnchor.token + 1,
          }));
          setPendingResumeRequest(null);
        })
        .catch(() => {
          setPendingResumeRequest(null);
          fetchLatestWindow();
        });
    } else if (!initialLoadCompletedRef.current) {
      initialLoadCompletedRef.current = true;
      fetchLatestWindow();
    }
  }, [chatId, fetchLatestWindow, dispatch, pendingResumeRequest, storeChatId, threadId]);

  // Auto-focus compose input after initial messages load
  const didAutoFocusRef = useRef(false);
  useEffect(() => {
    if (messages.length > 0 && !didAutoFocusRef.current) {
      didAutoFocusRef.current = true;
      requestAnimationFrame(() => {
        composeBarRef.current?.focusInput();
      });
    }
  }, [messages.length]);

  const loadMore = useCallback(() => {
    const st = store.getState();
    const cursor = selectNextCursorForChat(st, storeChatId);
    if (!chatId || cursor == null || loadingMoreRef.current) return;
    const gen = selectChatGeneration(st, storeChatId);
    loadingMoreRef.current = true;
    setLoadingMore(true);
    getMessages(chatId, { before: cursor, max: 50, threadId })
      .then((res) => {
        if (selectChatGeneration(store.getState(), storeChatId) !== gen) return;
        const list = res.data.messages ?? [];
        if (import.meta.env.DEV) {
          console.log('[ChatThread] loadMore resolved', {
            fetchedCount: list.length,
            oldestId: list[0]?.id ?? null,
            newestId: list[list.length - 1]?.id ?? null,
            nextCursor: res.data.nextCursor ?? null,
          });
        }
        dispatch(prependMessages({ chatId: storeChatId, messages: list, nextCursor: res.data.nextCursor ?? null }));
        loadingMoreRef.current = false;
        setLoadingMore(false);
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to load more`);
        loadingMoreRef.current = false;
        setLoadingMore(false);
      });
  }, [chatId, storeChatId, threadId, dispatch, showToast]);

  const loadNewer = useCallback(() => {
    const st = store.getState();
    const prevCursor = selectPrevCursorForChat(st, storeChatId);
    if (!chatId || prevCursor == null || loadingNewerRef.current) return;
    const gen = selectChatGeneration(st, storeChatId);
    loadingNewerRef.current = true;
    setLoadingNewer(true);
    getMessages(chatId, { after: prevCursor, max: 50, threadId })
      .then((res) => {
        if (selectChatGeneration(store.getState(), storeChatId) !== gen) return;
        const list = res.data.messages ?? [];
        dispatch(appendMessages({ chatId: storeChatId, messages: list, prevCursor: res.data.prevCursor ?? null }));
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to load newer messages`);
      })
      .finally(() => {
        loadingNewerRef.current = false;
        setLoadingNewer(false);
      });
  }, [chatId, storeChatId, threadId, dispatch, showToast]);

  const handleReactionToggle = useCallback(
    (msg: MessageResponse, emoji: string, currentlyReacted: boolean) => {
      // Optimistically update reactions locally
      const existing = msg.reactions ?? [];
      let optimistic: typeof existing;
      if (currentlyReacted) {
        optimistic = existing
          .map((r) => (r.emoji === emoji ? { ...r, count: r.count - 1, reactedByMe: false } : r))
          .filter((r) => r.count > 0);
        deleteReaction(chatId, msg.id, emoji).catch(() => {});
      } else {
        const found = existing.find((r) => r.emoji === emoji);
        if (found) {
          optimistic = existing.map((r) => (r.emoji === emoji ? { ...r, count: r.count + 1, reactedByMe: true } : r));
        } else {
          optimistic = [...existing, { emoji, count: 1, reactedByMe: true }];
        }
        putReaction(chatId, msg.id, emoji).catch(() => {});
      }
      dispatch(reactionsUpdated({ chatId, messageId: msg.id, reactions: optimistic }));
    },
    [chatId, dispatch],
  );

  const jumpToMessage = useCallback(
    (messageId: string) => {
      const state = store.getState();
      const currentMessages = selectMessagesForChat(state, storeChatId);
      const idx = currentMessages.findIndex((m) => m.id === messageId);
      if (idx !== -1) {
        scrollApiRef.current?.scrollToMessageId(messageId, 'smooth');
        return;
      }
      // Message not in current window — fetch centered window
      getMessages(chatId, { around: messageId, max: 50, threadId })
        .then((res) => {
          const list = res.data.messages ?? [];
          const targetMessage = list.find((message) => message.id === messageId) ?? null;
          const anchorKey = targetMessage ? getMessageKey(targetMessage) : `msg:${messageId}`;

          if (import.meta.env.DEV) {
            console.log('[ChatThread] jumpToMessage fetched-window', {
              chatId,
              storeChatId,
              threadId: threadId ?? null,
              messageId,
              fetchedCount: list.length,
              targetFound: targetMessage != null,
              targetClientGeneratedId: targetMessage?.clientGeneratedId ?? null,
              anchorKey,
            });
          }

          dispatch(
            pushWindow({
              chatId: storeChatId,
              messages: list,
              nextCursor: res.data.nextCursor ?? null,
              prevCursor: res.data.prevCursor ?? null,
            }),
          );
          setInitialAnchor((currentAnchor) => ({
            type: 'message',
            messageId,
            token: currentAnchor.token + 1,
          }));
        })
        .catch((err: Error) => {
          showToast(err.message || t`Failed to jump to message`);
        });
    },
    [chatId, dispatch, getMessageKey, showToast, storeChatId, threadId],
  );

  const nextCursor = useSelector((state: RootState) => selectNextCursorForChat(state, storeChatId));
  const prevCursor = useSelector((state: RootState) => selectPrevCursorForChat(state, storeChatId));

  const uploadAttachment = useCallback(async ({ file, dimensions, onProgress, signal }: ComposeUploadInput) => {
    const res = await requestUploadUrl({
      filename: file.name,
      contentType: file.type || 'application/octet-stream',
      size: file.size,
      ...dimensions,
    });

    const { uploadUrl, attachmentId, uploadHeaders } = res.data;
    await uploadFileToS3(uploadUrl, file, uploadHeaders, { onProgress, signal });

    return { attachmentId };
  }, []);

  const handleSend = useCallback(
    (payload: ComposeSendPayload) => {
      if (!chatId) return;
      // Optimistically mark as subscribed — backend auto-subscribes on reply
      if (threadId && !threadSubscribed) {
        setThreadSubscribed(true);
      }
      if (payload.kind === 'text') {
        const { text, attachmentIds, existingAttachments, uploadedAttachments } = payload;
        const { attachments: optimisticUploadedAttachments, revoke } =
          buildOptimisticUploadedAttachments(uploadedAttachments);

        if (!text.trim() && attachmentIds.length === 0) {
          revoke();
          return;
        }

        // Edit flow
        if (editingSession) {
          const originalAttachmentIds = (editingSession.attachments ?? []).map((attachment) => attachment.id);
          if (!text.trim() && attachmentIds.length === 0) {
            revoke();
            showToast(t`Message cannot be empty`);
            return;
          }
          if (
            text.trim() === editingSession.text.trim() &&
            areAttachmentIdsEqual(attachmentIds, originalAttachmentIds)
          ) {
            revoke();
            return;
          }

          const messageId = editingSession.messageId;
          const currentMessage = messageLookup.get(messageId) ?? editingSession.originalMessage;
          const optimisticMsg = {
            ...currentMessage,
            message: text,
            attachments: [...existingAttachments, ...optimisticUploadedAttachments],
            hasAttachments: attachmentIds.length > 0,
            isEdited: true,
          };

          dispatch(messagePatched({ chatId, messageId, message: optimisticMsg }));
          setEditingSession(null);

          updateMessage(chatId, messageId, { message: text, attachmentIds })
            .then((res) => {
              dispatch(messagePatched({ chatId, messageId, message: res.data }));
            })
            .catch((err: Error) => {
              dispatch(messagePatched({ chatId, messageId, message: editingSession.originalMessage }));
              showToast(err.message || t`Failed to edit message`);
            })
            .finally(() => {
              revoke();
            });
          return;
        }

        const clientGeneratedId = generateClientId();

        const optimistic: MessageResponse = {
          id: clientGeneratedId,
          message: text,
          messageType: 'text',
          replyRootId: threadId ?? null,
          replyToMessage: replyingTo
            ? {
                id: replyingTo.id,
                message: replyingTo.message,
                messageType: replyingTo.messageType,
                sticker: replyingTo.sticker,
                sender: replyingTo.sender,
                isDeleted: replyingTo.isDeleted,
                attachments: replyingTo.attachments,
              }
            : undefined,
          clientGeneratedId,
          sender: {
            uid: currentUserId || 0,
            gender: 0,
            name: currentUserName,
            avatarUrl: currentUserAvatarUrl || undefined,
          },
          chatId,
          createdAt: new Date().toISOString(),
          isEdited: false,
          isDeleted: false,
          hasAttachments: attachmentIds.length > 0,
          attachments: optimisticUploadedAttachments,
          threadInfo: undefined,
        };
        dispatch(
          messageAdded({
            chatId,
            storeChatId,
            message: optimistic,
            origin: 'optimistic',
            scope: threadId ? 'thread' : 'main',
          }),
        );
        setReplyingTo(null);
        if (!atBottom) {
          pendingSendScrollKeyRef.current = `msg:${clientGeneratedId}`;
          if (import.meta.env.DEV) {
            console.log('[ChatThread] schedule-pending-send-scroll', {
              chatId,
              storeChatId,
              threadId: threadId ?? null,
              clientGeneratedId,
              pendingKey: pendingSendScrollKeyRef.current,
              atBottom,
            });
          }
        } else {
          pendingSendScrollKeyRef.current = null;
        }

        const messagePayload = {
          message: text,
          messageType: 'text' as const,
          clientGeneratedId,
          replyToId: replyingTo?.id,
          attachmentIds,
        };

        const sendPromise = threadId
          ? sendThreadMessage(chatId, threadId, messagePayload)
          : sendMessage(chatId, messagePayload);

        sendPromise
          .then((res) => {
            const postResponse = res.data;
            const confirmed: MessageResponse = {
              ...postResponse,
              replyToMessage: postResponse.replyToMessage
                ? {
                    ...optimistic.replyToMessage,
                    ...postResponse.replyToMessage,
                    attachments: postResponse.replyToMessage.attachments ?? optimistic.replyToMessage?.attachments,
                  }
                : optimistic.replyToMessage,
            };
            dispatch(
              messageConfirmed({
                chatId,
                storeChatId,
                clientGeneratedId,
                message: confirmed,
                origin: 'api_confirm',
                scope: threadId ? 'thread' : 'main',
              }),
            );

            // Mark as read up to the message we just sent
            if (threadId) {
              dispatch(markThreadReadAction({ threadRootId: threadId }));
              void apiMarkThreadAsRead(threadId, confirmed.id);
            } else {
              dispatch(setChatUnreadCount({ chatId, unreadCount: 0 }));
              dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: confirmed.id }));
              void markMessagesAsRead(chatId, confirmed.id).then((res) => {
                dispatch(setChatUnreadCount({ chatId, unreadCount: res.data.unreadCount }));
                dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: res.data.lastReadMessageId }));
              });
              void syncAppBadgeCount();
            }
          })
          .catch((err: Error) => {
            showToast(err.message || t`Failed to send`);
            dispatch(
              messagePatched({
                chatId,
                messageId: clientGeneratedId,
                message: { ...optimistic, isDeleted: true },
              }),
            );
          })
          .finally(() => {
            revoke();
          });
        return;
      }

      if (payload.kind === 'sticker') {
        const clientGeneratedId = generateClientId();
        const optimistic: MessageResponse = {
          id: clientGeneratedId,
          message: null,
          messageType: 'sticker',
          sticker: payload.sticker,
          replyRootId: threadId ?? null,
          replyToMessage: replyingTo
            ? {
                id: replyingTo.id,
                message: replyingTo.message,
                messageType: replyingTo.messageType,
                sticker: replyingTo.sticker,
                sender: replyingTo.sender,
                isDeleted: replyingTo.isDeleted,
                attachments: replyingTo.attachments,
              }
            : undefined,
          clientGeneratedId,
          sender: {
            uid: currentUserId || 0,
            gender: 0,
            name: currentUserName,
            avatarUrl: currentUserAvatarUrl || undefined,
          },
          chatId,
          createdAt: new Date().toISOString(),
          isEdited: false,
          isDeleted: false,
          hasAttachments: false,
          attachments: [],
          threadInfo: undefined,
        };
        dispatch(
          messageAdded({
            chatId,
            storeChatId,
            message: optimistic,
            origin: 'optimistic',
            scope: threadId ? 'thread' : 'main',
          }),
        );
        setReplyingTo(null);
        if (!atBottom) {
          pendingSendScrollKeyRef.current = `msg:${clientGeneratedId}`;
        } else {
          pendingSendScrollKeyRef.current = null;
        }

        const messagePayload = {
          messageType: 'sticker' as const,
          stickerId: payload.sticker.id,
          clientGeneratedId,
          replyToId: replyingTo?.id,
          attachmentIds: [],
        };

        const sendPromise = threadId
          ? sendThreadMessage(chatId, threadId, messagePayload)
          : sendMessage(chatId, messagePayload);

        sendPromise
          .then((res) => {
            const postResponse = res.data;
            const confirmed: MessageResponse = {
              ...postResponse,
              sticker: postResponse.sticker ?? payload.sticker,
              replyToMessage: postResponse.replyToMessage
                ? {
                    ...optimistic.replyToMessage,
                    ...postResponse.replyToMessage,
                    attachments: postResponse.replyToMessage.attachments ?? optimistic.replyToMessage?.attachments,
                  }
                : optimistic.replyToMessage,
            };
            dispatch(
              messageConfirmed({
                chatId,
                storeChatId,
                clientGeneratedId,
                message: confirmed,
                origin: 'api_confirm',
                scope: threadId ? 'thread' : 'main',
              }),
            );

            // Mark as read up to the message we just sent
            if (threadId) {
              dispatch(markThreadReadAction({ threadRootId: threadId }));
              void apiMarkThreadAsRead(threadId, confirmed.id);
            } else {
              dispatch(setChatUnreadCount({ chatId, unreadCount: 0 }));
              dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: confirmed.id }));
              void markMessagesAsRead(chatId, confirmed.id).then((res) => {
                dispatch(setChatUnreadCount({ chatId, unreadCount: res.data.unreadCount }));
                dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: res.data.lastReadMessageId }));
              });
              void syncAppBadgeCount();
            }
          })
          .catch((err: Error) => {
            showToast(err.message || t`Failed to send`);
            dispatch(
              messagePatched({
                chatId,
                messageId: clientGeneratedId,
                message: { ...optimistic, isDeleted: true },
              }),
            );
          });
        return;
      }

      const { attachmentId, uploadedAttachment } = payload;
      const { attachments: optimisticAudioAttachments, revoke } = buildOptimisticUploadedAttachments([
        uploadedAttachment,
      ]);
      const clientGeneratedId = generateClientId();
      const optimistic: MessageResponse = {
        id: clientGeneratedId,
        message: '',
        messageType: 'audio',
        replyRootId: threadId ?? null,
        replyToMessage: replyingTo
          ? {
              id: replyingTo.id,
              message: replyingTo.message,
              messageType: replyingTo.messageType,
              sticker: replyingTo.sticker,
              sender: replyingTo.sender,
              isDeleted: replyingTo.isDeleted,
              attachments: replyingTo.attachments,
            }
          : undefined,
        clientGeneratedId,
        sender: {
          uid: currentUserId || 0,
          gender: 0,
          name: currentUserName,
          avatarUrl: currentUserAvatarUrl || undefined,
        },
        chatId,
        createdAt: new Date().toISOString(),
        isEdited: false,
        isDeleted: false,
        hasAttachments: true,
        attachments: optimisticAudioAttachments,
        threadInfo: undefined,
      };
      dispatch(
        messageAdded({
          chatId,
          storeChatId,
          message: optimistic,
          origin: 'optimistic',
          scope: threadId ? 'thread' : 'main',
        }),
      );
      setReplyingTo(null);
      if (!atBottom) {
        pendingSendScrollKeyRef.current = `msg:${clientGeneratedId}`;
      } else {
        pendingSendScrollKeyRef.current = null;
      }

      const messagePayload = {
        message: '',
        messageType: 'audio' as const,
        clientGeneratedId,
        replyToId: replyingTo?.id,
        attachmentIds: [attachmentId],
      };

      const sendPromise = threadId
        ? sendThreadMessage(chatId, threadId, messagePayload)
        : sendMessage(chatId, messagePayload);

      sendPromise
        .then((res) => {
          const postResponse = res.data;
          const confirmed: MessageResponse = {
            ...postResponse,
            replyToMessage: postResponse.replyToMessage
              ? {
                  ...optimistic.replyToMessage,
                  ...postResponse.replyToMessage,
                  attachments: postResponse.replyToMessage.attachments ?? optimistic.replyToMessage?.attachments,
                }
              : optimistic.replyToMessage,
          };
          dispatch(
            messageConfirmed({
              chatId,
              storeChatId,
              clientGeneratedId,
              message: confirmed,
              origin: 'api_confirm',
              scope: threadId ? 'thread' : 'main',
            }),
          );

          // Mark as read up to the message we just sent
          if (threadId) {
            dispatch(markThreadReadAction({ threadRootId: threadId }));
            void apiMarkThreadAsRead(threadId, confirmed.id);
          } else {
            dispatch(setChatUnreadCount({ chatId, unreadCount: 0 }));
            dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: confirmed.id }));
            void markMessagesAsRead(chatId, confirmed.id).then((res) => {
              dispatch(setChatUnreadCount({ chatId, unreadCount: res.data.unreadCount }));
              dispatch(setChatLastReadMessageId({ chatId, lastReadMessageId: res.data.lastReadMessageId }));
            });
            void syncAppBadgeCount();
          }
        })
        .catch((err: Error) => {
          showToast(err.message || t`Failed to send`);
          dispatch(
            messagePatched({
              chatId,
              messageId: clientGeneratedId,
              message: { ...optimistic, isDeleted: true },
            }),
          );
        })
        .finally(() => {
          revoke();
        });
    },
    [
      chatId,
      storeChatId,
      threadId,
      threadSubscribed,
      dispatch,
      showToast,
      replyingTo,
      editingSession,
      currentUserId,
      currentUserName,
      currentUserAvatarUrl,
      messageLookup,
      atBottom,
    ],
  );

  const isKeyboardOpen = !isDesktop && composeFocused && baselineViewportHeight - viewportHeight > 120;

  const onClickChatItem = useCallback(
    (msg: MessageResponse, sourceRect: DOMRect) => {
      if (isKeyboardOpen) {
        composeBarRef.current?.blurInput();
        return;
      }

      setOverlayMessage({ message: msg, sourceRect });
    },
    [isKeyboardOpen],
  );

  const overlayActions = useMemo((): MessageOverlayAction[] => {
    if (!overlayMessage) return [];
    const msg = overlayMessage.message;
    const audioMessage = isAudioMessage(msg);
    const stickerMessage = msg.messageType === 'sticker';
    const isOwn = msg.sender.uid === currentUserId;
    const actions: MessageOverlayAction[] = [];

    if (!audioMessage && !stickerMessage) {
      actions.push({
        key: 'copy',
        label: t`Copy`,
        icon: copyOutline,
        disabled: !navigator.clipboard?.writeText,
        handler: () => {
          navigator.clipboard.writeText(msg.message ?? '');
        },
      });
    }

    actions.push({
      key: 'copy-link',
      label: t`Copy Link`,
      icon: linkOutline,
      handler: () => {
        navigator.clipboard.writeText(buildPermalinkUrl(chatId, msg.id));
      },
    });

    actions.push({
      key: 'reply',
      label: t`Reply`,
      icon: arrowUndo,
      handler: () => {
        setReplyingTo(msg);
      },
    });
    if (!threadId && !msg.threadInfo) {
      actions.push({
        key: 'thread',
        label: t`Start Thread`,
        icon: chatbubbles,
        handler: () => {
          history.push(`/chats/chat/${chatId}/thread/${msg.id}`);
        },
      });
    }
    if (isOwn && !audioMessage && !stickerMessage) {
      actions.push({
        key: 'edit',
        label: t`Edit`,
        icon: createOutline,
        handler: () => startEditingMessage(msg),
      });
    }
    if (isOwn || isAdmin) {
      actions.push({
        key: 'delete',
        label: t`Delete`,
        icon: trashOutline,
        role: 'destructive',
        handler: () => {
          presentAlert({
            header: t`Delete Message`,
            message: isOwn
              ? t`Are you sure you want to delete this message?`
              : t`Are you sure you want to delete this message from ${msg.sender.name ?? 'this user'}?`,
            buttons: [
              { text: t`Cancel`, role: 'cancel' as const },
              {
                text: t`Delete`,
                role: 'destructive' as const,
                handler: () => {
                  const deletedOptimistic = { ...msg, isDeleted: true };
                  dispatch(messagePatched({ chatId, messageId: msg.id, message: deletedOptimistic }));
                  deleteMessage(chatId, msg.id).catch((e: any) => {
                    dispatch(messagePatched({ chatId, messageId: msg.id, message: msg }));
                    showToast(e.message || t`Failed to delete message`);
                  });
                },
              },
            ],
          });
        },
      });
    }
    if (msg.reactions?.length) {
      actions.push({
        key: 'reaction-details',
        icon: informationCircleOutline,
        label: t`Reaction Details`,
        handler: () => {
          setReactionDetail({ messageId: msg.id });
        },
      });
    }
    if (stickerMessage) {
      return actions.filter((a) => a.key === 'reply' || a.key === 'delete' || a.key === 'copy-link');
    }
    return actions;
  }, [
    overlayMessage,
    currentUserId,
    isAdmin,
    threadId,
    chatId,
    history,
    dispatch,
    showToast,
    presentAlert,
    startEditingMessage,
  ]);

  const renderRow = useCallback(
    (row: ChatRow) => {
      return (
        <ChatMessageRow
          row={row}
          currentUserId={currentUserId}
          threadId={threadId}
          onReply={setReplyingTo}
          onJumpToReply={jumpToMessage}
          onLongPress={onClickChatItem}
          onAvatarClick={setProfileSender}
          onThreadClick={(message) => history.push(`/chats/chat/${chatId}/thread/${message.id}`)}
          onReactionToggle={handleReactionToggle}
          onStickerTap={setStickerPreviewId}
        />
      );
    },
    [currentUserId, threadId, chatId, history, jumpToMessage, onClickChatItem, handleReactionToggle],
  );

  return (
    <div className="ion-page chat-thread-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
          <IonTitle>
            <span className="chat-thread-title">
              <span>{chatName}</span>
              {isMuted && !threadId ? (
                <IonIcon aria-hidden="true" icon={notificationsOffOutline} className="chat-thread-title__icon" />
              ) : null}
            </span>
          </IonTitle>
          <IonButtons slot="end">
            {threadId ? (
              threadSubscribed != null && (
                <IonButton
                  onClick={handleToggleThreadSubscription}
                  disabled={threadSubLoading}
                  color={threadSubscribed ? undefined : 'medium'}
                >
                  <IonIcon slot="icon-only" icon={threadSubscribed ? notifications : notificationsOffOutline} />
                </IonButton>
              )
            ) : (
              <>
                <IonButton onClick={() => history.push(`/chats/chat/${chatId}/members`)}>
                  <IonIcon slot="icon-only" icon={people} />
                </IonButton>
                <IonButton onClick={() => history.push(`/chats/chat/${chatId}/settings`)}>
                  <IonIcon slot="icon-only" icon={informationCircleOutline} />
                </IonButton>
              </>
            )}
          </IonButtons>
          {!wsConnected && <IonProgressBar type="indeterminate" />}
        </IonToolbar>
      </IonHeader>

      <IonContent className="chat-thread-content" scrollX={false} scrollY={false}>
        <ChatVirtualScroll
          key={storeChatId}
          rows={chatRows}
          renderRow={renderRow}
          initialAnchor={initialAnchor}
          loadOlder={{ hasMore: nextCursor != null, loading: loadingMore, onLoad: loadMore }}
          loadNewer={prevCursor != null ? { hasMore: true, loading: loadingNewer, onLoad: loadNewer } : undefined}
          scrollApiRef={scrollApiRef}
          bottomPadding={16}
          onAtBottomChange={setAtBottom}
          onLastFullyVisibleMessageChange={setLastFullyVisibleMessageId}
        />
        <IonFab
          vertical="bottom"
          horizontal="end"
          className={`scroll-to-bottom-fab ${atBottom ? 'scroll-to-bottom-fab--hidden' : ''}`}
        >
          <IonFabButton
            size="small"
            onClick={() => {
              if (prevCursor != null) {
                fetchLatestWindow({ forceReopen: true });
              } else {
                scrollApiRef.current?.scrollToBottom();
              }
            }}
          >
            <IonIcon icon={chevronDown} />
          </IonFabButton>
        </IonFab>
      </IonContent>

      <IonFooter className="chat-thread-footer">
        <MessageComposeBar
          ref={composeBarRef}
          chatId={chatId}
          onSend={handleSend}
          uploadAttachment={uploadAttachment}
          onError={(message) => showToast(message, 2200, { positionAnchor: 'message-compose-bar' })}
          onFocusChange={handleComposeFocusChange}
          replyTo={
            replyingTo
              ? {
                  messageId: replyingTo.id,
                  username: replyingTo.sender.name ?? `User ${replyingTo.sender.uid}`,
                  messageType: replyingTo.messageType,
                  text: replyingTo.message,
                  attachments: replyingTo.attachments,
                  firstAttachmentKind: replyingTo.attachments?.[0]?.kind,
                  isDeleted: replyingTo.isDeleted,
                }
              : undefined
          }
          onCancelReply={() => setReplyingTo(null)}
          editing={editingSession ?? undefined}
          onCancelEdit={() => setEditingSession(null)}
          onRequestEditLastMessage={requestEditLastOwnMessage}
        />
      </IonFooter>
      <UserProfileModal key={profileSender?.uid} sender={profileSender} onDismiss={() => setProfileSender(null)} />
      <ReactionDetailsModal
        chatId={chatId}
        messageId={reactionDetail?.messageId ?? null}
        initialEmoji={reactionDetail?.emoji}
        onDismiss={() => setReactionDetail(null)}
      />
      <StickerPreviewModal stickerId={stickerPreviewId} onDismiss={() => setStickerPreviewId(null)} />
      {overlayMessage &&
        (() => {
          const msg = overlayMessage.message;
          const sharedOverlayProps = {
            senderName: msg.sender.name ?? `User ${msg.sender.uid}`,
            isSent: msg.sender.uid === currentUserId,
            showName: true,
            timestamp: msg.createdAt,
            edited: msg.isEdited,
            isConfirmed: !msg.id.startsWith('cg_'),
            replyTo: msg.replyToMessage
              ? {
                  senderName: msg.replyToMessage.sender.name ?? `User ${msg.replyToMessage.sender.uid}`,
                  preview: msg.replyToMessage,
                }
              : undefined,
            sourceRect: overlayMessage.sourceRect,
            actions: overlayActions,
            reactions: {
              emojis: QUICK_REACTION_EMOJIS,
              onReact: (emoji: string) => {
                handleReactionToggle(msg, emoji, !!msg.reactions?.some((r) => r.emoji === emoji && r.reactedByMe));
              },
            },
            onClose: () => setOverlayMessage(null),
          } as const;

          if (msg.messageType === 'sticker') {
            return (
              <MessageOverlay messageType="sticker" stickerUrl={msg.sticker?.media.url ?? ''} {...sharedOverlayProps} />
            );
          }

          return (
            <MessageOverlay
              messageType={msg.messageType as 'text' | 'audio'}
              message={msg.isDeleted ? t`[Deleted]` : (msg.message ?? '')}
              attachments={msg.attachments}
              {...sharedOverlayProps}
            />
          );
        })()}
    </div>
  );
}

export function ChatThreadPage() {
  const { id: chatId, threadId } = useParams<{ id: string; threadId?: string }>();
  const renderKey = threadId ?? chatId;
  const backAction: BackAction = threadId
    ? { type: 'back', defaultHref: `/chats/chat/${chatId}` }
    : { type: 'back', defaultHref: '/chats' };
  return (
    <IonPage>
      <ChatThreadCore key={renderKey} chatId={chatId} threadId={threadId} backAction={backAction} />
    </IonPage>
  );
}

export default ChatThreadCore;
