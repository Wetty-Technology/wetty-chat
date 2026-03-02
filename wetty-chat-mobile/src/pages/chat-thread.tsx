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
import { useParams, useHistory, useLocation } from 'react-router-dom';
import { people, settings, chevronDown } from 'ionicons/icons';
import { useDispatch, useSelector } from 'react-redux';
import {
  getMessages,
  sendMessage,
  type MessageResponse,
} from '@/api/messages';
import { getCurrentUserId } from '@/js/current-user';
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
  selectChatGeneration,
} from '@/store/messagesSlice';
import store from '@/store/index';
import type { RootState } from '@/store/index';
import { VirtualScroll } from '@/components/chat/VirtualScroll';
import { ChatBubble } from '@/components/chat/ChatBubble';
import { MessageComposeBar } from '@/components/chat/MessageComposeBar';
import './chat-thread.scss';

interface LocationState {
  chatName?: string;
}

function generateClientId(): string {
  return `cg_${Date.now()}_${Math.random().toString(36).slice(2)}`;
}

function colorForUser(uid: number): string {
  const hue = ((uid * 137) % 360 + 360) % 360;
  return `hsl(${hue}, 55%, 50%)`;
}

export default function ChatThread() {
  const { id } = useParams<{ id: string }>();
  const chatId = id ? String(id) : '';
  const history = useHistory();
  const location = useLocation<LocationState>();
  const chatName = location.state?.chatName ?? (id ? `Chat ${id}` : 'Chat');

  const dispatch = useDispatch();
  const messages = useSelector((state: RootState) => selectMessagesForChat(state, chatId));

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

  const [presentToast] = useIonToast();
  const [presentActionSheet] = useIonActionSheet();

  const showToast = useCallback((text: string, duration = 3000) => {
    presentToast({ message: text, duration, position: 'bottom' });
  }, [presentToast]);

  // Initial load
  useEffect(() => {
    if (!chatId) return;
    setInitialScrollIndex(undefined);
    getMessages(chatId)
      .then((res) => {
        const list = res.data.messages ?? [];
        dispatch(resetChat({ chatId, messages: list, nextCursor: res.data.next_cursor ?? null, prevCursor: null }));
        setPrependedCount(0);
        setWindowKey(k => k + 1);
        setInitialScrollIndex(undefined);
      })
      .catch((err: Error) => {
        dispatch(resetChat({ chatId, messages: [], nextCursor: null, prevCursor: null }));
        showToast(err.message || 'Failed to load messages');
      });
  }, [chatId, dispatch, showToast]);

  const loadMore = useCallback(() => {
    const st = store.getState();
    const cursor = selectNextCursorForChat(st, chatId);
    if (!chatId || cursor == null || loadingMoreRef.current) return;
    const gen = selectChatGeneration(st, chatId);
    loadingMoreRef.current = true;
    setLoadingMore(true);
    getMessages(chatId, { before: cursor, max: 50 })
      .then((res) => {
        if (selectChatGeneration(store.getState(), chatId) !== gen) return;
        const list = res.data.messages ?? [];
        dispatch(prependMessages({ chatId, messages: list, nextCursor: res.data.next_cursor ?? null }));
        setPrependedCount(c => c + list.length);
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to load more');
      })
      .finally(() => {
        loadingMoreRef.current = false;
        setLoadingMore(false);
      });
  }, [chatId, dispatch, showToast]);

  const loadNewer = useCallback(() => {
    const st = store.getState();
    const prevCursor = selectPrevCursorForChat(st, chatId);
    if (!chatId || prevCursor == null || loadingNewerRef.current) return;
    const gen = selectChatGeneration(st, chatId);
    loadingNewerRef.current = true;
    getMessages(chatId, { after: prevCursor, max: 50 })
      .then((res) => {
        if (selectChatGeneration(store.getState(), chatId) !== gen) return;
        const list = res.data.messages ?? [];
        dispatch(appendMessages({ chatId, messages: list, prevCursor: res.data.prev_cursor ?? null }));
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to load newer messages');
      })
      .finally(() => {
        loadingNewerRef.current = false;
      });
  }, [chatId, dispatch, showToast]);

  const jumpToMessage = useCallback((messageId: string) => {
    const state = store.getState();
    const currentMessages = selectMessagesForChat(state, chatId);
    const idx = currentMessages.findIndex((m) => m.id === messageId);
    if (idx !== -1) {
      scrollToIndexRef.current?.(idx, 'smooth');
      return;
    }
    // Message not in current window — fetch centered window
    getMessages(chatId, { around: messageId, max: 50 })
      .then((res) => {
        const list = res.data.messages ?? [];
        dispatch(pushWindow({ chatId, messages: list, nextCursor: res.data.next_cursor ?? null, prevCursor: res.data.prev_cursor ?? null }));
        const idx = list.findIndex((m) => m.id === messageId);
        setInitialScrollIndex(idx !== -1 ? idx : undefined);
        setWindowKey(k => k + 1);
        setPrependedCount(0);
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to jump to message');
      });
  }, [chatId, dispatch, showToast]);

  const prevCursor = useSelector((state: RootState) => selectPrevCursorForChat(state, chatId));

  const handleSend = useCallback((text: string) => {
    if (!chatId) return;

    const clientGeneratedId = generateClientId();

    const optimistic: MessageResponse = {
      id: '0',
      message: text,
      message_type: 'text',
      reply_to_id: replyingTo?.id ?? null,
      reply_root_id: replyingTo?.reply_root_id ?? replyingTo?.id ?? null,
      reply_to_message: replyingTo ? {
        id: replyingTo.id,
        message: replyingTo.message,
        sender_uid: replyingTo.sender_uid,
        deleted_at: replyingTo.deleted_at,
      } : undefined,
      client_generated_id: clientGeneratedId,
      sender_uid: getCurrentUserId(),
      chat_id: chatId,
      created_at: new Date().toISOString(),
      updated_at: null,
      deleted_at: null,
      has_attachments: false,
    };
    dispatch(addMessage({ chatId, message: optimistic }));
    setReplyingTo(null);
    setTimeout(() => scrollToBottomRef.current?.(), 50);

    sendMessage(chatId, {
      message: text,
      message_type: 'text',
      client_generated_id: clientGeneratedId,
      reply_to_id: replyingTo?.id,
      reply_root_id: replyingTo?.reply_root_id ?? replyingTo?.id,
    })
      .then((res) => {
        const postResponse = res.data;
        const confirmed: MessageResponse = {
          ...postResponse,
          reply_to_message: postResponse.reply_to_message ?? optimistic.reply_to_message,
        };
        dispatch(confirmPendingMessage({ chatId, clientGeneratedId, message: confirmed }));
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to send');
        const state = store.getState();
        const currentMessages = selectMessagesForChat(state, chatId);
        const without = currentMessages.filter(
          (m) => m.client_generated_id !== clientGeneratedId
        );
        dispatch(setMessagesForChat({ chatId, messages: without }));
      });
  }, [chatId, dispatch, showToast, replyingTo]);

  const onClickChatItem = useCallback((messageIndex: number) => {
    const msg = messages[messageIndex];
    presentActionSheet({
      buttons: [
        {
          text: 'Reply', handler: () => {
            setReplyingTo(msg);
          }
        },
        { text: 'Start Thread', handler: () => { } },
        { text: 'Edit', handler: () => { } },
        { text: 'Delete', role: 'destructive', handler: () => { } },
        { text: 'Cancel', role: 'cancel', handler: () => { } },
      ],
    });
  }, [messages]);

  return (
    <IonPage className="chat-thread-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref="/chats" text="" />
          </IonButtons>
          <IonTitle>{chatName}</IonTitle>
          <IonButtons slot="end">
            <IonButton onClick={() => history.push(`/chats/members/${chatId}`, { chatName })}>
              <IonIcon slot="icon-only" icon={people} />
            </IonButton>
            <IonButton onClick={() => history.push(`/chats/settings/${chatId}`, { chatName })}>
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
          renderItem={(index: number) => {
            const msg = messages[index];
            const prevSender = index > 0 ? messages[index - 1].sender_uid : null;
            const nextSender = index < messages.length - 1 ? messages[index + 1].sender_uid : null;
            return (
              <ChatBubble
                senderName={`User ${msg.sender_uid}`}
                message={msg.deleted_at ? '[Deleted]' : (msg.message ?? '')}
                isSent={msg.sender_uid === getCurrentUserId()}
                avatarColor={colorForUser(msg.sender_uid)}
                onReply={() => setReplyingTo(msg)}
                onReplyTap={msg.reply_to_id ? () => jumpToMessage(msg.reply_to_id!) : undefined}
                onLongPress={() => onClickChatItem(index)}
                showName={prevSender !== msg.sender_uid}
                showAvatar={nextSender !== msg.sender_uid}
                timestamp={msg.created_at}
                replyTo={msg.reply_to_message ? {
                  senderName: `User ${msg.reply_to_message.sender_uid}`,
                  message: msg.reply_to_message.deleted_at ? '[Deleted]' : (msg.reply_to_message.message ?? ''),
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
        />
      </IonFooter>
    </IonPage>
  );
}
