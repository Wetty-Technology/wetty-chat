import { useRef, useState, useEffect, useCallback } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonFooter,
  IonButtons,
  IonButton,
  IonIcon,
  IonBackButton,
  IonFab,
  IonFabButton,
  useIonToast,
  useIonActionSheet,
  useIonAlert,
} from '@ionic/react';
import { useParams, useHistory } from 'react-router-dom';
import { people, settings, chevronDown } from 'ionicons/icons';
import { useDispatch, useSelector } from 'react-redux';
import {
  getMessages,
  sendMessage,
  sendThreadMessage,
  updateMessage,
  deleteMessage,
  type MessageResponse,
} from '@/api/messages';
import { getChatDetails } from '@/api/chats';
import { getCurrentUserId } from '@/js/current-user';
import { selectChatName, setChatMeta } from '@/store/chatsSlice';
import {
  selectMessagesForChat,
  selectNextCursorForChat,
  selectPrevCursorForChat,
  resetChat,
  pushWindow,
  addMessage,
  appendMessages,
  prependMessages,
  confirmPendingMessage,
  updateMessageInStore,
  selectChatGeneration,
} from '@/store/messagesSlice';
import store from '@/store/index';
import type { RootState } from '@/store/index';
import { VirtualScroll } from '@/components/chat/VirtualScroll';
import { ChatBubble } from '@/components/chat/ChatBubble';
import { MessageComposeBar } from '@/components/chat/MessageComposeBar';
import './chat-thread.scss';
import { t } from '@lingui/core/macro';
import { FeatureGate } from '@/components/FeatureGate';

function generateClientId(): string {
  return `cg_${Date.now()}_${Math.random().toString(36).slice(2)}`;
}

function colorForUser(uid: number): string {
  const hue = ((uid * 137) % 360 + 360) % 360;
  return `hsl(${hue}, 55%, 50%)`;
}

export default function ChatThread() {
  const { id, threadId } = useParams<{ id: string; threadId?: string }>();
  const apiChatId = id ? String(id) : '';
  const storeChatId = threadId ? `${apiChatId}_thread_${threadId}` : apiChatId;
  const history = useHistory();

  const dispatch = useDispatch();
  const storedName = useSelector((state: RootState) => selectChatName(state, apiChatId));
  const chatName = threadId ? t`Thread` : (storedName ?? t`Loading...`);

  useEffect(() => {
    if (!apiChatId || storedName != null) return;
    getChatDetails(apiChatId)
      .then((res) => {
        const { id: _, ...meta } = res.data;
        dispatch(setChatMeta({ chatId: apiChatId, meta }));
      })
      .catch(() => { });
  }, [apiChatId, storedName, dispatch]);
  const messages = useSelector((state: RootState) => selectMessagesForChat(state, storeChatId));

  const formatDateSeparator = useCallback((iso: string) => {
    if (!iso) return '';
    const date = new Date(iso);
    const now = new Date();

    const isSameDay = (d1: Date, d2: Date) =>
      d1.getFullYear() === d2.getFullYear() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getDate() === d2.getDate();

    if (isSameDay(date, now)) return t`Today`;

    const yesterday = new Date(now);
    yesterday.setDate(now.getDate() - 1);
    if (isSameDay(date, yesterday)) return t`Yesterday`;

    return date.toLocaleDateString(undefined, {
      year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined,
      month: 'short',
      day: 'numeric'
    });
  }, []);

  const scrollToBottomRef = useRef<(() => void) | null>(null);
  const scrollToIndexRef = useRef<((index: number, behavior?: ScrollBehavior) => void) | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);
  const loadingNewerRef = useRef(false);
  const [prependedCount, setPrependedCount] = useState(0);
  const [windowKey, setWindowKey] = useState(0);
  const [initialScrollIndex, setInitialScrollIndex] = useState<number | undefined>(undefined);

  const [atBottom, setAtBottom] = useState(true);
  const [replyingTo, setReplyingTo] = useState<MessageResponse | null>(null);
  const [editingMessage, setEditingMessage] = useState<MessageResponse | null>(null);


  const [presentToast] = useIonToast();
  const [presentActionSheet] = useIonActionSheet();
  const [presentAlert] = useIonAlert();

  const showToast = useCallback((text: string, duration = 3000) => {
    presentToast({ message: text, duration, position: 'bottom' });
  }, [presentToast]);

  // Initial load
  useEffect(() => {
    if (!apiChatId) return;
    setInitialScrollIndex(undefined);
    getMessages(apiChatId, threadId ? { thread_id: threadId } : undefined)
      .then((res) => {
        const list = res.data.messages ?? [];
        dispatch(resetChat({ chatId: storeChatId, messages: list, nextCursor: res.data.next_cursor ?? null, prevCursor: null }));
        setPrependedCount(0);
        setWindowKey(k => k + 1);
        setInitialScrollIndex(undefined);
      })
      .catch((err: Error) => {
        dispatch(resetChat({ chatId: storeChatId, messages: [], nextCursor: null, prevCursor: null }));
        showToast(err.message || t`Failed to load messages`);
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast]);

  const loadMore = useCallback(() => {
    const st = store.getState();
    const cursor = selectNextCursorForChat(st, storeChatId);
    if (!apiChatId || cursor == null || loadingMoreRef.current) return;
    const gen = selectChatGeneration(st, storeChatId);
    loadingMoreRef.current = true;
    setLoadingMore(true);
    getMessages(apiChatId, { before: cursor, max: 50, thread_id: threadId })
      .then((res) => {
        if (selectChatGeneration(store.getState(), storeChatId) !== gen) return;
        const list = res.data.messages ?? [];
        dispatch(prependMessages({ chatId: storeChatId, messages: list, nextCursor: res.data.next_cursor ?? null }));
        setPrependedCount(c => c + list.length);
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to load more`);
      })
      .finally(() => {
        loadingMoreRef.current = false;
        setLoadingMore(false);
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast]);

  const loadNewer = useCallback(() => {
    const st = store.getState();
    const prevCursor = selectPrevCursorForChat(st, storeChatId);
    if (!apiChatId || prevCursor == null || loadingNewerRef.current) return;
    const gen = selectChatGeneration(st, storeChatId);
    loadingNewerRef.current = true;
    getMessages(apiChatId, { after: prevCursor, max: 50, thread_id: threadId })
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
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast]);

  const jumpToMessage = useCallback((messageId: string) => {
    const state = store.getState();
    const currentMessages = selectMessagesForChat(state, storeChatId);
    const idx = currentMessages.findIndex((m) => m.id === messageId);
    if (idx !== -1) {
      scrollToIndexRef.current?.(idx, 'smooth');
      return;
    }
    // Message not in current window — fetch centered window
    getMessages(apiChatId, { around: messageId, max: 50, thread_id: threadId })
      .then((res) => {
        const list = res.data.messages ?? [];
        dispatch(pushWindow({ chatId: storeChatId, messages: list, nextCursor: res.data.next_cursor ?? null, prevCursor: res.data.prev_cursor ?? null }));
        const idx = list.findIndex((m) => m.id === messageId);
        setInitialScrollIndex(idx !== -1 ? idx : undefined);
        setWindowKey(k => k + 1);
        setPrependedCount(0);
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to jump to message`);
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast]);

  const prevCursor = useSelector((state: RootState) => selectPrevCursorForChat(state, storeChatId));

  const handleSend = useCallback((text: string, attachmentIds?: string[]) => {
    if (!apiChatId) return;

    if (!text.trim() && (!attachmentIds || attachmentIds.length === 0)) {
      return;
    }

    // Edit flow
    if (editingMessage) {
      if (!text.trim()) {
        showToast(t`Message cannot be empty`);
        return;
      }
      if (text.trim() === editingMessage.message?.trim()) {
        setEditingMessage(null);
        return;
      }

      const messageId = editingMessage.id;
      const optimisticMsg = { ...editingMessage, message: text, is_edited: true };

      // Optimistic update
      dispatch(updateMessageInStore({ chatId: storeChatId, messageId, message: optimisticMsg }));
      setEditingMessage(null);

      updateMessage(apiChatId, messageId, { message: text })
        .then((res) => {
          dispatch(updateMessageInStore({ chatId: storeChatId, messageId, message: res.data }));
        })
        .catch((err: Error) => {
          // Revert optimistic update
          dispatch(updateMessageInStore({ chatId: storeChatId, messageId, message: editingMessage }));
          showToast(err.message || t`Failed to edit message`);
        });
      return;
    }

    const clientGeneratedId = generateClientId();

    const optimistic: MessageResponse = {
      id: clientGeneratedId,
      message: text,
      message_type: 'text',
      reply_root_id: threadId ?? null,
      reply_to_message: replyingTo ? {
        id: replyingTo.id,
        message: replyingTo.message,
        sender: replyingTo.sender,
        is_deleted: replyingTo.is_deleted,
      } : undefined,
      client_generated_id: clientGeneratedId,
      sender: { uid: getCurrentUserId(), name: null },
      chat_id: apiChatId,
      created_at: new Date().toISOString(),
      is_edited: false,
      is_deleted: false,
      has_attachments: (attachmentIds && attachmentIds.length > 0) || false,
      thread_info: undefined,
    };
    dispatch(addMessage({ chatId: storeChatId, message: optimistic }));
    setReplyingTo(null);
    setTimeout(() => scrollToBottomRef.current?.(), 50);

    const messagePayload = {
      message: text,
      message_type: 'text',
      client_generated_id: clientGeneratedId,
      reply_to_id: replyingTo?.id,
      attachment_ids: attachmentIds,
    };

    const sendPromise = threadId
      ? sendThreadMessage(apiChatId, threadId, messagePayload)
      : sendMessage(apiChatId, messagePayload);

    sendPromise
      .then((res) => {
        const postResponse = res.data;
        const confirmed: MessageResponse = {
          ...postResponse,
          reply_to_message: postResponse.reply_to_message ?? optimistic.reply_to_message,
        };
        dispatch(confirmPendingMessage({ chatId: storeChatId, clientGeneratedId, message: confirmed }));
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to send`);
        dispatch(updateMessageInStore({
          chatId: storeChatId,
          messageId: clientGeneratedId,
          message: { ...optimistic, is_deleted: true }
        }));
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast, replyingTo, editingMessage]);

  const onClickChatItem = useCallback((messageIndex: number) => {
    const msg = messages[messageIndex];
    const isOwn = msg.sender.uid === getCurrentUserId();
    presentActionSheet({
      buttons: [
        {
          text: t`Reply`, handler: () => {
            setReplyingTo(msg);
          }
        },
        ...(!threadId && !msg.thread_info ? [{ text: t`Start Thread`, handler: () => { history.push(`/chats/chat/${apiChatId}/thread/${msg.id}`); } }] : []),
        ...(isOwn ? [
          {
            text: t`Edit`, handler: () => {
              setReplyingTo(null);
              setEditingMessage(msg);
            }
          },
          {
            text: t`Delete`, role: 'destructive' as const, handler: () => {
              presentAlert({
                header: t`Delete Message`,
                message: t`Are you sure you want to delete this message?`,
                buttons: [
                  { text: t`Cancel`, role: 'cancel' as const },
                  {
                    text: t`Delete`, role: 'destructive' as const, handler: () => {
                      const deletedOptimistic = { ...msg, is_deleted: true };
                      dispatch(updateMessageInStore({ chatId: storeChatId, messageId: msg.id, message: deletedOptimistic }));
                      deleteMessage(apiChatId, msg.id).catch((e: any) => {
                        dispatch(updateMessageInStore({ chatId: storeChatId, messageId: msg.id, message: msg }));
                        showToast(e.message || t`Failed to delete message`);
                      });
                    }
                  }
                ]
              });
            }
          }
        ] : []),
        { text: t`Cancel`, role: 'cancel' as const, handler: () => { } },
      ],
    });
  }, [messages, apiChatId, threadId, history, showToast, presentActionSheet, setReplyingTo, setEditingMessage, presentAlert]);



  return (
    <IonPage className="chat-thread-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref="/chats" text="" />
          </IonButtons>
          <IonTitle>{chatName}</IonTitle>
          <IonButtons slot="end">
            <IonButton onClick={() => history.push(`/chats/chat/${apiChatId}/members`)}>
              <IonIcon slot="icon-only" icon={people} />
            </IonButton>
            <FeatureGate>
              <IonButton onClick={() => history.push(`/chats/chat/${apiChatId}/settings`)}>
                <IonIcon slot="icon-only" icon={settings} />
              </IonButton>
            </FeatureGate>
          </IonButtons>
        </IonToolbar>
      </IonHeader>

      <IonContent className="chat-thread-content" scrollX={false} scrollY={false}>
        <VirtualScroll
          totalItems={messages.length}
          estimatedItemHeight={60}
          overscan={10}
          loadingOlder={loadingMore}
          onLoadOlder={loadMore}
          onLoadNewer={prevCursor != null ? loadNewer : undefined}
          loadMoreThreshold={200}
          prependedCount={prependedCount}
          scrollToBottomRef={scrollToBottomRef}
          scrollToIndexRef={scrollToIndexRef}
          bottomPadding={16}
          windowKey={windowKey}
          initialScrollIndex={initialScrollIndex}
          onAtBottomChange={setAtBottom}

          renderItem={(index: number) => {
            const msg = messages[index];
            const prevMsg = index > 0 ? messages[index - 1] : null;
            const nextMsg = index < messages.length - 1 ? messages[index + 1] : null;

            const prevSender = prevMsg ? prevMsg.sender.uid : null;
            const nextSender = nextMsg ? nextMsg.sender.uid : null;

            let showDateSeparator = false;
            if (index === 0) {
              showDateSeparator = true;
            } else if (prevMsg) {
              const d1 = new Date(msg.created_at);
              const d2 = new Date(prevMsg.created_at);
              if (d1.getFullYear() !== d2.getFullYear() || d1.getMonth() !== d2.getMonth() || d1.getDate() !== d2.getDate()) {
                showDateSeparator = true;
              }
            }

            let isLastInGroup = nextSender !== msg.sender.uid;
            if (!isLastInGroup && nextMsg) {
              const d1 = new Date(msg.created_at);
              const d2 = new Date(nextMsg.created_at);
              if (d1.getFullYear() !== d2.getFullYear() || d1.getMonth() !== d2.getMonth() || d1.getDate() !== d2.getDate()) {
                isLastInGroup = true;
              }
            }

            return (
              <>
                {showDateSeparator && (
                  <div className="chat-date-separator">
                    <span>{formatDateSeparator(msg.created_at)}</span>
                  </div>
                )}
                <ChatBubble
                  senderName={msg.sender.name ?? `User ${msg.sender.uid}`}
                  message={msg.is_deleted ? t`[Deleted]` : (msg.message ?? '')}
                  isSent={msg.sender.uid === getCurrentUserId()}
                  avatarColor={colorForUser(msg.sender.uid)}
                  onReply={() => setReplyingTo(msg)}
                  onReplyTap={msg.reply_to_message && !msg.reply_to_message?.is_deleted ? () => jumpToMessage(msg.reply_to_message!.id) : undefined}
                  onLongPress={() => onClickChatItem(index)}
                  showName={prevSender !== msg.sender.uid || showDateSeparator}
                  showAvatar={isLastInGroup}
                  timestamp={msg.created_at}
                  edited={msg.is_edited}
                  threadInfo={!threadId ? msg.thread_info : undefined}
                  onThreadClick={() => history.push(`/chats/chat/${apiChatId}/thread/${msg.id}`)}
                  attachments={msg.attachments}
                  isConfirmed={!msg.id.startsWith('cg_')}
                  replyTo={msg.reply_to_message ? {
                    senderName: msg.reply_to_message.sender.name ?? `User ${msg.reply_to_message.sender.uid}`,
                    message: msg.reply_to_message.is_deleted ? t`[Deleted]` : (msg.reply_to_message.message ?? ''),
                    avatarColor: colorForUser(msg.reply_to_message.sender.uid),
                  } : undefined}
                />
              </>
            );
          }}
        />
        <IonFab
          vertical="bottom"
          horizontal="end"
          className={`scroll-to-bottom-fab ${atBottom ? 'scroll-to-bottom-fab--hidden' : ''}`}
        >
          <IonFabButton size="small" onClick={() => scrollToBottomRef.current?.()}>
            <IonIcon icon={chevronDown} />
          </IonFabButton>
        </IonFab>
      </IonContent>

      <IonFooter>
        <MessageComposeBar
          onSend={handleSend}
          replyTo={replyingTo ? {
            messageId: replyingTo.id,
            username: replyingTo.sender.name ?? `User ${replyingTo.sender.uid}`,
            text: replyingTo.message ?? '',
          } : undefined}
          onCancelReply={() => setReplyingTo(null)}
          editing={editingMessage ? {
            messageId: editingMessage.id,
            text: editingMessage.message ?? '',
          } : undefined}
          onCancelEdit={() => setEditingMessage(null)}
        />
      </IonFooter>
    </IonPage>
  );
}
