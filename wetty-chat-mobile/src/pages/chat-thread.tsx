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
} from '@ionic/react';
import { useParams, useHistory } from 'react-router-dom';
import { people, settings, chevronDown } from 'ionicons/icons';
import { useDispatch, useSelector } from 'react-redux';
import {
  getMessages,
  sendMessage,
  updateMessage,
  deleteMessage,
  getMessage,
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
  setMessagesForChat,
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
  const chatName = threadId ? `Thread` : (storedName ?? (id ? `Chat ${id}` : 'Chat'));

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
  const [rootMessage, setRootMessage] = useState<MessageResponse | null>(null);

  useEffect(() => {
    if (threadId) {
      getMessage(apiChatId, threadId)
        .then((res) => setRootMessage(res.data))
        .catch(() => setRootMessage(null));
    } else {
      setRootMessage(null);
    }
  }, [apiChatId, threadId]);

  const [presentToast] = useIonToast();
  const [presentActionSheet] = useIonActionSheet();

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
        showToast(err.message || 'Failed to load messages');
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
        showToast(err.message || 'Failed to load more');
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
        showToast(err.message || 'Failed to load newer messages');
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
        showToast(err.message || 'Failed to jump to message');
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast]);

  const prevCursor = useSelector((state: RootState) => selectPrevCursorForChat(state, storeChatId));

  const handleSend = useCallback((text: string) => {
    if (!apiChatId) return;

    // Edit flow
    if (editingMessage) {
      const messageId = editingMessage.id;
      // Optimistic update
      dispatch(updateMessageInStore({ chatId: storeChatId, messageId, message: { ...editingMessage, message: text, is_edited: true } }));
      setEditingMessage(null);

      updateMessage(apiChatId, messageId, { message: text })
        .then((res) => {
          dispatch(updateMessageInStore({ chatId: storeChatId, messageId, message: { ...res.data, reply_to_message: res.data.reply_to_message ?? editingMessage.reply_to_message } }));
        })
        .catch((err: Error) => {
          // Revert optimistic update
          dispatch(updateMessageInStore({ chatId: storeChatId, messageId, message: editingMessage }));
          showToast(err.message || 'Failed to edit message');
        });
      return;
    }

    const clientGeneratedId = generateClientId();

    const optimistic: MessageResponse = {
      id: '0',
      message: text,
      message_type: 'text',
      reply_to_id: replyingTo?.id ?? null,
      reply_root_id: threadId ?? replyingTo?.reply_root_id ?? replyingTo?.id ?? null,
      reply_to_message: replyingTo ? {
        id: replyingTo.id,
        message: replyingTo.message,
        sender_uid: replyingTo.sender_uid,
        is_deleted: replyingTo.is_deleted,
      } : undefined,
      client_generated_id: clientGeneratedId,
      sender_uid: getCurrentUserId(),
      chat_id: apiChatId,
      created_at: new Date().toISOString(),
      is_edited: false,
      is_deleted: false,
      has_attachments: false,
      has_thread: false,
    };
    dispatch(addMessage({ chatId: storeChatId, message: optimistic }));
    setReplyingTo(null);
    setTimeout(() => scrollToBottomRef.current?.(), 50);

    sendMessage(apiChatId, {
      message: text,
      message_type: 'text',
      client_generated_id: clientGeneratedId,
      reply_to_id: replyingTo?.id,
      reply_root_id: threadId ?? replyingTo?.reply_root_id ?? replyingTo?.id,
    })
      .then((res) => {
        const postResponse = res.data;
        const confirmed: MessageResponse = {
          ...postResponse,
          reply_to_message: postResponse.reply_to_message ?? optimistic.reply_to_message,
        };
        dispatch(confirmPendingMessage({ chatId: storeChatId, clientGeneratedId, message: confirmed }));
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to send');
        const state = store.getState();
        const currentMessages = selectMessagesForChat(state, storeChatId);
        const without = currentMessages.filter(
          (m) => m.client_generated_id !== clientGeneratedId
        );
        dispatch(setMessagesForChat({ chatId: storeChatId, messages: without }));
      });
  }, [apiChatId, storeChatId, threadId, dispatch, showToast, replyingTo, editingMessage]);

  const onClickChatItem = useCallback((messageIndex: number) => {
    const msg = messages[messageIndex];
    const isOwn = msg.sender_uid === getCurrentUserId();
    presentActionSheet({
      buttons: [
        {
          text: 'Reply', handler: () => {
            setReplyingTo(msg);
          }
        },
        ...(!threadId ? [{ text: 'Start Thread', handler: () => { history.push(`/chats/chat/${apiChatId}/thread/${msg.id}`); } }] : []),
        ...(isOwn ? [
          {
            text: 'Edit', handler: () => {
              setReplyingTo(null);
              setEditingMessage(msg);
            }
          },
          {
            text: 'Delete', role: 'destructive' as const, handler: () => {
              deleteMessage(apiChatId, msg.id).catch((e: any) => {
                showToast(e.message || 'Failed to delete message');
              });
            }
          }
        ] : []),
        { text: 'Cancel', role: 'cancel' as const, handler: () => { } },
      ],
    });
  }, [messages, apiChatId, threadId, history, showToast, presentActionSheet, setReplyingTo, setEditingMessage]);

  const onClickRootMessage = useCallback(() => {
    if (!rootMessage) return;
    const isOwn = rootMessage.sender_uid === getCurrentUserId();
    presentActionSheet({
      buttons: [
        {
          text: 'Reply', handler: () => {
            setReplyingTo(rootMessage);
          }
        },
        ...(isOwn ? [
          {
            text: 'Edit', handler: () => {
              setReplyingTo(null);
              setEditingMessage(rootMessage);
            }
          },
          {
            text: 'Delete', role: 'destructive' as const, handler: () => {
              deleteMessage(apiChatId, rootMessage.id).catch((e: any) => {
                showToast(e.message || 'Failed to delete message');
              });
            }
          }
        ] : []),
        { text: 'Cancel', role: 'cancel' as const, handler: () => { } },
      ],
    });
  }, [rootMessage, apiChatId, showToast, presentActionSheet, setReplyingTo, setEditingMessage]);

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
            <IonButton onClick={() => history.push(`/chats/chat/${apiChatId}/settings`)}>
              <IonIcon slot="icon-only" icon={settings} />
            </IonButton>
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
          header={rootMessage ? (
            <ChatBubble
              senderName={`User ${rootMessage.sender_uid}`}
              message={rootMessage.is_deleted ? '[Deleted]' : (rootMessage.message ?? '')}
              isSent={rootMessage.sender_uid === getCurrentUserId()}
              avatarColor={colorForUser(rootMessage.sender_uid)}
              onReply={() => setReplyingTo(rootMessage)}
              onReplyTap={rootMessage.reply_to_id && !rootMessage.reply_to_message?.is_deleted ? () => jumpToMessage(rootMessage.reply_to_id!) : undefined}
              onLongPress={onClickRootMessage}
              showName={true}
              showAvatar={true}
              timestamp={rootMessage.created_at}
              edited={rootMessage.is_edited}
              replyTo={rootMessage.reply_to_message ? {
                senderName: `User ${rootMessage.reply_to_message.sender_uid}`,
                message: rootMessage.reply_to_message.is_deleted ? '[Deleted]' : (rootMessage.reply_to_message.message ?? ''),
                avatarColor: colorForUser(rootMessage.reply_to_message.sender_uid),
              } : undefined}
            />
          ) : undefined}
          renderItem={(index: number) => {
            const msg = messages[index];
            const prevSender = index > 0 ? messages[index - 1].sender_uid : null;
            const nextSender = index < messages.length - 1 ? messages[index + 1].sender_uid : null;
            return (
              <ChatBubble
                senderName={`User ${msg.sender_uid}`}
                message={msg.is_deleted ? '[Deleted]' : (msg.message ?? '')}
                isSent={msg.sender_uid === getCurrentUserId()}
                avatarColor={colorForUser(msg.sender_uid)}
                onReply={() => setReplyingTo(msg)}
                onReplyTap={msg.reply_to_id && !msg.reply_to_message?.is_deleted ? () => jumpToMessage(msg.reply_to_id!) : undefined}
                onLongPress={() => onClickChatItem(index)}
                showName={prevSender !== msg.sender_uid}
                showAvatar={nextSender !== msg.sender_uid}
                timestamp={msg.created_at}
                edited={msg.is_edited}
                hasThread={msg.has_thread && !threadId}
                onThreadClick={() => history.push(`/chats/chat/${apiChatId}/thread/${msg.id}`)}
                replyTo={msg.reply_to_message ? {
                  senderName: `User ${msg.reply_to_message.sender_uid}`,
                  message: msg.reply_to_message.is_deleted ? '[Deleted]' : (msg.reply_to_message.message ?? ''),
                  avatarColor: colorForUser(msg.reply_to_message.sender_uid),
                } : undefined}
              />
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
            username: `User ${replyingTo.sender_uid}`,
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
