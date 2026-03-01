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
  useIonToast,
} from '@ionic/react';
import { useParams, useHistory, useLocation } from 'react-router-dom';
import { paperPlane, people, settings } from 'ionicons/icons';
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
  setMessagesForChat,
  setNextCursorForChat,
  addMessage,
  prependMessages,
  confirmPendingMessage,
} from '@/store/messagesSlice';
import store from '@/store/index';
import type { RootState } from '@/store/index';
import { VirtualScroll } from '@/components/chat/VirtualScroll';
import { ChatBubble } from '@/components/chat/ChatBubble';
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

  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const scrollToBottomRef = useRef<(() => void) | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);
  const [messageText, setMessageText] = useState('');

  const [presentToast] = useIonToast();

  const showToast = useCallback((text: string, duration = 3000) => {
    presentToast({ message: text, duration, position: 'bottom' });
  }, [presentToast]);

  // Initial load
  useEffect(() => {
    if (!chatId) return;
    getMessages(chatId)
      .then((res) => {
        const list = res.data.messages ?? [];
        const ordered = [...list].reverse();
        dispatch(setMessagesForChat({ chatId, messages: ordered }));
        dispatch(setNextCursorForChat({ chatId, cursor: res.data.next_cursor ?? null }));
      })
      .catch((err: Error) => {
        dispatch(setMessagesForChat({ chatId, messages: [] }));
        dispatch(setNextCursorForChat({ chatId, cursor: null }));
        showToast(err.message || 'Failed to load messages');
      });
  }, [chatId, dispatch, showToast]);

  const loadMore = useCallback(() => {
    const cursor = selectNextCursorForChat(store.getState(), chatId);
    if (!chatId || cursor == null || loadingMoreRef.current) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    getMessages(chatId, { before: cursor, max: 50 })
      .then((res) => {
        const list = res.data.messages ?? [];
        const older = [...list].reverse();
        dispatch(prependMessages({ chatId, messages: older }));
        dispatch(setNextCursorForChat({ chatId, cursor: res.data.next_cursor ?? null }));
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to load more');
      })
      .finally(() => {
        loadingMoreRef.current = false;
        setLoadingMore(false);
      });
  }, [chatId, dispatch, showToast]);

  const handleSend = useCallback(() => {
    const text = messageText.trim();
    if (!text || !chatId) return;

    const clientGeneratedId = generateClientId();
    setMessageText('');

    const optimistic: MessageResponse = {
      id: '0',
      message: text,
      message_type: 'text',
      reply_to_id: null,
      reply_root_id: null,
      client_generated_id: clientGeneratedId,
      sender_uid: getCurrentUserId(),
      chat_id: chatId,
      created_at: new Date().toISOString(),
      updated_at: null,
      deleted_at: null,
      has_attachments: false,
    };
    dispatch(addMessage({ chatId, message: optimistic }));
    setTimeout(() => scrollToBottomRef.current?.(), 50);

    sendMessage(chatId, {
      message: text,
      message_type: 'text',
      client_generated_id: clientGeneratedId,
    })
      .then((res) => {
        const postResponse = res.data;
        setTimeout(() => {
          const state = store.getState();
          const current = selectMessagesForChat(state, chatId);
          const stillPending = current.find(
            (m) => m.client_generated_id === clientGeneratedId && m.id === '0'
          );
          if (stillPending) {
            dispatch(
              confirmPendingMessage({
                chatId,
                clientGeneratedId,
                message: postResponse,
              })
            );
          }
        }, 15000);
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to send');
        const state = store.getState();
        const currentMessages = selectMessagesForChat(state, chatId);
        const without = currentMessages.filter(
          (m) => m.client_generated_id !== clientGeneratedId
        );
        dispatch(setMessagesForChat({ chatId, messages: without }));
        setMessageText(text);
      });
  }, [chatId, dispatch, messageText, showToast]);

  const handleSendRef = useRef(handleSend);
  useEffect(() => {
    handleSendRef.current = handleSend;
  }, [handleSend]);

  // Configure textarea: Enter sends
  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;
    textarea.setAttribute('enterkeyhint', 'send');
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        handleSendRef.current();
      }
    };
    textarea.addEventListener('keydown', onKeyDown);
    return () => textarea.removeEventListener('keydown', onKeyDown);
  }, []);

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
          loading={loadingMore}
          onLoadMore={loadMore}
          loadMoreThreshold={200}
          scrollToBottomRef={scrollToBottomRef}
          renderItem={(index) => {
            const msg = messages[index];
            const prevSender = index > 0 ? messages[index - 1].sender_uid : null;
            const nextSender = index < messages.length - 1 ? messages[index + 1].sender_uid : null;
            return (
              <ChatBubble
                senderName={`User ${msg.sender_uid}`}
                message={msg.deleted_at ? '[Deleted]' : (msg.message ?? '')}
                isSent={msg.sender_uid === getCurrentUserId()}
                avatarColor={colorForUser(msg.sender_uid)}
                showName={prevSender !== msg.sender_uid}
                showAvatar={nextSender !== msg.sender_uid}
              />
            );
          }}
        />
      </IonContent>

      <IonFooter>
        <IonToolbar className="messagebar-toolbar">
          <div className="messagebar">
            <textarea
              ref={textareaRef}
              className="messagebar-textarea"
              placeholder="Message"
              value={messageText}
              rows={1}
              onChange={(e) => {
                setMessageText(e.target.value);
                e.target.style.height = 'auto';
                e.target.style.height = `${Math.min(e.target.scrollHeight, 120)}px`;
              }}
            />
            <button
              type="button"
              className={`messagebar-send-btn${messageText.trim().length === 0 ? ' messagebar-send-btn--disabled' : ''}`}
              onClick={handleSend}
              aria-label="Send message"
            >
              <IonIcon icon={paperPlane} />
            </button>
          </div>
        </IonToolbar>
      </IonFooter>
    </IonPage>
  );
}
