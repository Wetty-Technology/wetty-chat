import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
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
import { useHistory, useParams } from 'react-router-dom';
import {
  arrowUndo,
  chatbubbles,
  chevronDown,
  copyOutline,
  createOutline,
  informationCircleOutline,
  notificationsOffOutline,
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
  markChatAsRead,
  selectChatLastReadMessageId,
  selectChatName,
  selectIsChatMuted,
  setChatMeta,
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
import { getGroupInfo } from '@/api/group';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';
import { requestUploadUrl, uploadFileToS3 } from '@/api/upload';
import { syncAppBadgeCount } from '@/utils/badges';
import { useIsDesktop } from '@/hooks/platformHooks';
import { ChatMessageRow } from '@/components/chat/messages/ChatMessageRow';

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
      file_name: attachment.file.name,
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

  const dispatch = useDispatch();
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const currentUserName = useSelector((state: RootState) => state.user.username);
  const currentUserAvatarUrl = useSelector((state: RootState) => state.user.avatar_url);
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);
  const isDesktop = useIsDesktop();
  const storedName = useSelector((state: RootState) => selectChatName(state, chatId));
  const isMuted = useSelector((state: RootState) => selectIsChatMuted(state, chatId));
  const lastReadMessageId = useSelector((state: RootState) => selectChatLastReadMessageId(state, chatId));
  const chatName = threadId ? t`Thread` : (storedName ?? t`Loading...`);

  useEffect(() => {
    if (!chatId || storedName != null) return;
    getGroupInfo(chatId)
      .then((res) => {
        const { id, ...meta } = res.data;
        void id;
        dispatch(setChatMeta({ chatId: chatId, meta }));
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

  const chatRows = useChatRows(messages, formatDateSeparator);

  const [atBottom, setAtBottom] = useState(true);
  const [replyingTo, setReplyingTo] = useState<MessageResponse | null>(null);
  const [profileSender, setProfileSender] = useState<Sender | null>(null);
  const [reactionDetail, setReactionDetail] = useState<{ messageId: string; emoji?: string } | null>(null);
  const [editingSession, setEditingSession] = useState<EditSession | null>(null);
  const [composeFocused, setComposeFocused] = useState(false);
  const [baselineViewportHeight, setBaselineViewportHeight] = useState<number>(() => window.visualViewport?.height ?? window.innerHeight);
  const [viewportHeight, setViewportHeight] = useState<number>(() => window.visualViewport?.height ?? window.innerHeight);

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

  const getMessageKey = useCallback(
    (message: MessageResponse) => `msg:${message.client_generated_id || message.id}`,
    [],
  );

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
      .find((message) => message.sender.uid === currentUserId && !message.is_deleted);

    if (!lastOwnMessage) {
      return false;
    }

    startEditingMessage(lastOwnMessage);
    return true;
  }, [currentUserId, editingSession, messages, replyingTo, startEditingMessage]);

  const showToast = useCallback(
    (text: string, duration = 3000) => {
      presentToast({ message: text, duration, position: 'bottom' });
    },
    [presentToast],
  );

  const lastReportedReadId = useRef<string | null>(null);

  useEffect(() => {
    lastReportedReadId.current = null;
  }, [storeChatId]);

  useEffect(() => {
    if (!chatId || messages.length === 0 || !atBottom) return;

    const latestMessage = messages[messages.length - 1];

    // Ignore optimistic client-generated messages
    if (latestMessage.id.startsWith('cg_')) return;

    const latestComparableId = parseComparableMessageId(latestMessage.id);
    if (latestComparableId == null) return;

    const currentReadComparableId = lastReadMessageId ? parseComparableMessageId(lastReadMessageId) : null;
    if (currentReadComparableId != null && latestComparableId <= currentReadComparableId) return;

    if (latestMessage.id !== lastReportedReadId.current) {
      lastReportedReadId.current = latestMessage.id;

      markMessagesAsRead(chatId, latestMessage.id)
        .then(() => {
          dispatch(markChatAsRead({ chatId: chatId, lastReadMessageId: latestMessage.id }));
          void syncAppBadgeCount();
        })
        .catch((err) => {
          console.error('Failed to mark as read', err);
          lastReportedReadId.current = null;
        });
    }
  }, [messages, atBottom, chatId, dispatch, lastReadMessageId]);

  const fetchLatestWindow = useCallback((options?: { forceReopen?: boolean }) => {
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
    getMessages(chatId, threadId ? { thread_id: threadId } : undefined)
      .then((res) => {
        const list = res.data.messages ?? [];
        const nextCursor = res.data.next_cursor ?? null;
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
  }, [chatId, dispatch, showToast, storeChatId, threadId]);

  // Initial load
  useEffect(() => {
    fetchLatestWindow();
  }, [chatId, fetchLatestWindow]);

  const loadMore = useCallback(() => {
    const st = store.getState();
    const cursor = selectNextCursorForChat(st, storeChatId);
    if (!chatId || cursor == null || loadingMoreRef.current) return;
    const gen = selectChatGeneration(st, storeChatId);
    loadingMoreRef.current = true;
    setLoadingMore(true);
    getMessages(chatId, { before: cursor, max: 50, thread_id: threadId })
      .then((res) => {
        if (selectChatGeneration(store.getState(), storeChatId) !== gen) return;
        const list = res.data.messages ?? [];
        if (import.meta.env.DEV) {
          console.log('[ChatThread] loadMore resolved', {
            fetchedCount: list.length,
            oldestId: list[0]?.id ?? null,
            newestId: list[list.length - 1]?.id ?? null,
            nextCursor: res.data.next_cursor ?? null,
          });
        }
        dispatch(prependMessages({ chatId: storeChatId, messages: list, nextCursor: res.data.next_cursor ?? null }));
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
    getMessages(chatId, { after: prevCursor, max: 50, thread_id: threadId })
      .then((res) => {
        if (selectChatGeneration(store.getState(), storeChatId) !== gen) return;
        const list = res.data.messages ?? [];
        dispatch(appendMessages({ chatId: storeChatId, messages: list, prevCursor: res.data.prev_cursor ?? null }));
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
          .map((r) => (r.emoji === emoji ? { ...r, count: r.count - 1, reacted_by_me: false } : r))
          .filter((r) => r.count > 0);
        deleteReaction(chatId, msg.id, emoji).catch(() => {});
      } else {
        const found = existing.find((r) => r.emoji === emoji);
        if (found) {
          optimistic = existing.map((r) => (r.emoji === emoji ? { ...r, count: r.count + 1, reacted_by_me: true } : r));
        } else {
          optimistic = [...existing, { emoji, count: 1, reacted_by_me: true }];
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
      getMessages(chatId, { around: messageId, max: 50, thread_id: threadId })
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
              targetClientGeneratedId: targetMessage?.client_generated_id ?? null,
              anchorKey,
            });
          }

          dispatch(
            pushWindow({
              chatId: storeChatId,
              messages: list,
              nextCursor: res.data.next_cursor ?? null,
              prevCursor: res.data.prev_cursor ?? null,
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
      content_type: file.type || 'application/octet-stream',
      size: file.size,
      ...dimensions,
    });

    const { upload_url, attachment_id, upload_headers } = res.data;
    await uploadFileToS3(upload_url, file, upload_headers, { onProgress, signal });

    return { attachmentId: attachment_id };
  }, []);

  const handleSend = useCallback(
    (payload: ComposeSendPayload) => {
      if (!chatId) return;
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
        if (text.trim() === editingSession.text.trim() && areAttachmentIdsEqual(attachmentIds, originalAttachmentIds)) {
          revoke();
          return;
        }

        const messageId = editingSession.messageId;
        const currentMessage = messageLookup.get(messageId) ?? editingSession.originalMessage;
        const optimisticMsg = {
          ...currentMessage,
          message: text,
          attachments: [...existingAttachments, ...optimisticUploadedAttachments],
          has_attachments: attachmentIds.length > 0,
          is_edited: true,
        };

        // Optimistic update
        dispatch(messagePatched({ chatId, messageId, message: optimisticMsg }));
        setEditingSession(null);

        updateMessage(chatId, messageId, { message: text, attachment_ids: attachmentIds })
          .then((res) => {
            dispatch(messagePatched({ chatId, messageId, message: res.data }));
          })
          .catch((err: Error) => {
            // Revert optimistic update
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
        message_type: 'text',
        reply_root_id: threadId ?? null,
        reply_to_message: replyingTo
          ? {
              id: replyingTo.id,
              message: replyingTo.message,
              sender: replyingTo.sender,
              is_deleted: replyingTo.is_deleted,
              attachments: replyingTo.attachments,
            }
          : undefined,
        client_generated_id: clientGeneratedId,
        sender: {
          uid: currentUserId || 0,
          gender: 0,
          name: currentUserName,
          avatar_url: currentUserAvatarUrl || undefined,
        },
        chat_id: chatId,
        created_at: new Date().toISOString(),
        is_edited: false,
        is_deleted: false,
        has_attachments: attachmentIds.length > 0,
        attachments: optimisticUploadedAttachments,
        thread_info: undefined,
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
        message_type: 'text',
        client_generated_id: clientGeneratedId,
        reply_to_id: replyingTo?.id,
        attachment_ids: attachmentIds,
      };

      const sendPromise = threadId
        ? sendThreadMessage(chatId, threadId, messagePayload)
        : sendMessage(chatId, messagePayload);

      sendPromise
        .then((res) => {
          const postResponse = res.data;
          const confirmed: MessageResponse = {
            ...postResponse,
            reply_to_message: postResponse.reply_to_message
              ? {
                  ...optimistic.reply_to_message,
                  ...postResponse.reply_to_message,
                  attachments: postResponse.reply_to_message.attachments ?? optimistic.reply_to_message?.attachments,
                }
              : optimistic.reply_to_message,
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
        })
        .catch((err: Error) => {
          showToast(err.message || t`Failed to send`);
          dispatch(
            messagePatched({
              chatId,
              messageId: clientGeneratedId,
              message: { ...optimistic, is_deleted: true },
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

  const isKeyboardOpen =
    !isDesktop &&
    composeFocused &&
    baselineViewportHeight - viewportHeight > 120;

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
    const isOwn = msg.sender.uid === currentUserId;
    const actions: MessageOverlayAction[] = [
      {
        key: 'copy',
        label: t`Copy`,
        icon: copyOutline,
        disabled: !navigator.clipboard?.writeText,
        handler: () => {
          navigator.clipboard.writeText(msg.message ?? '');
        },
      },
      {
        key: 'reply',
        label: t`Reply`,
        icon: arrowUndo,
        handler: () => {
          setReplyingTo(msg);
        },
      },
    ];
    if (!threadId && !msg.thread_info) {
      actions.push({
        key: 'thread',
        label: t`Start Thread`,
        icon: chatbubbles,
        handler: () => {
          history.push(`/chats/chat/${chatId}/thread/${msg.id}`);
        },
      });
    }
    if (isOwn) {
      actions.push({
        key: 'edit',
        label: t`Edit`,
        icon: createOutline,
        handler: () => startEditingMessage(msg),
      });
      actions.push({
        key: 'delete',
        label: t`Delete`,
        icon: trashOutline,
        role: 'destructive',
        handler: () => {
          presentAlert({
            header: t`Delete Message`,
            message: t`Are you sure you want to delete this message?`,
            buttons: [
              { text: t`Cancel`, role: 'cancel' as const },
              {
                text: t`Delete`,
                role: 'destructive' as const,
                handler: () => {
                  const deletedOptimistic = { ...msg, is_deleted: true };
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
    return actions;
  }, [
    overlayMessage,
    currentUserId,
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
            <IonButton onClick={() => history.push(`/chats/chat/${chatId}/members`)}>
              <IonIcon slot="icon-only" icon={people} />
            </IonButton>
            <IonButton onClick={() => history.push(`/chats/chat/${chatId}/settings`)}>
              <IonIcon slot="icon-only" icon={informationCircleOutline} />
            </IonButton>
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
          onSend={handleSend}
          uploadAttachment={uploadAttachment}
          onFocusChange={handleComposeFocusChange}
          replyTo={
            replyingTo
              ? {
                  messageId: replyingTo.id,
                  username: replyingTo.sender.name ?? `User ${replyingTo.sender.uid}`,
                  text: replyingTo.message,
                  attachments: replyingTo.attachments,
                  isDeleted: replyingTo.is_deleted,
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
      {overlayMessage && (
        <MessageOverlay
          senderName={overlayMessage.message.sender.name ?? `User ${overlayMessage.message.sender.uid}`}
          message={overlayMessage.message.is_deleted ? t`[Deleted]` : (overlayMessage.message.message ?? '')}
          isSent={overlayMessage.message.sender.uid === currentUserId}
          showName={true}
          timestamp={overlayMessage.message.created_at}
          edited={overlayMessage.message.is_edited}
          isConfirmed={!overlayMessage.message.id.startsWith('cg_')}
          attachments={overlayMessage.message.attachments}
          replyTo={
            overlayMessage.message.reply_to_message
              ? {
                  senderName:
                    overlayMessage.message.reply_to_message.sender.name ??
                    `User ${overlayMessage.message.reply_to_message.sender.uid}`,
                  message: overlayMessage.message.reply_to_message.message,
                  firstAttachmentKind: overlayMessage.message.reply_to_message.first_attachment_kind ?? null,
                  isDeleted: overlayMessage.message.reply_to_message.is_deleted,
                }
              : undefined
          }
          sourceRect={overlayMessage.sourceRect}
          actions={overlayActions}
          reactions={{
            emojis: QUICK_REACTION_EMOJIS,
            onReact: (emoji) => {
              handleReactionToggle(
                overlayMessage.message,
                emoji,
                !!overlayMessage.message.reactions?.some((r) => r.emoji === emoji && r.reacted_by_me),
              );
            },
          }}
          onClose={() => setOverlayMessage(null)}
        />
      )}
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
