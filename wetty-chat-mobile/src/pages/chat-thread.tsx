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
  IonSpinner,
  useIonToast,
  useIonAlert,
  useIonActionSheet,
} from '@ionic/react';
import { useParams, useHistory, useLocation } from 'react-router-dom';
import { paperPlane, people, settings } from 'ionicons/icons';
import { useDispatch, useSelector } from 'react-redux';
import { Virtuoso, type VirtuosoHandle } from 'react-virtuoso';
import {
  getMessages,
  sendMessage,
  updateMessage,
  deleteMessage,
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
import './chat-thread.scss';

interface LocationState {
  chatName?: string;
}

function generateClientId(): string {
  return `cg_${Date.now()}_${Math.random().toString(36).slice(2)}`;
}

function messageTime(createdAt: string): string {
  return Intl.DateTimeFormat('en', {
    hour: 'numeric',
    minute: 'numeric',
  }).format(new Date(createdAt));
}

function isSent(message: MessageResponse): boolean {
  return message.sender_uid === getCurrentUserId();
}

function messageAvatarUrl(message: MessageResponse): string {
  const name = isSent(message) ? 'Me' : `U${message.sender_uid}`;
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&size=64&background=random`;
}

export default function ChatThread() {
  const { id } = useParams<{ id: string }>();
  const chatId = id ? String(id) : '';
  const history = useHistory();
  const location = useLocation<LocationState>();
  const chatName = location.state?.chatName ?? (id ? `Chat ${id}` : 'Chat');

  const dispatch = useDispatch();
  const messages = useSelector((state: RootState) => selectMessagesForChat(state, chatId));
  const nextCursor = useSelector((state: RootState) => selectNextCursorForChat(state, chatId));

  const virtuosoRef = useRef<VirtuosoHandle>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const loadingMoreRef = useRef(false);
  const START_INDEX = 1_000_000;
  const [firstItemIndex, setFirstItemIndex] = useState(START_INDEX);
  const [messageText, setMessageText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [editingMessageId, setEditingMessageId] = useState<string | null>(null);
  const [editingText, setEditingText] = useState('');
  const [replyingTo, setReplyingTo] = useState<MessageResponse | null>(null);

  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const [presentActionSheet] = useIonActionSheet();

  const showToast = useCallback((text: string, duration = 3000) => {
    presentToast({ message: text, duration, position: 'bottom' });
  }, [presentToast]);

  const scrollToBottom = useCallback(() => {
    virtuosoRef.current?.scrollToIndex({ index: 'LAST', behavior: 'auto' });
  }, []);

  // Initial load
  useEffect(() => {
    if (!chatId) return;
    setLoading(true);
    setError(null);
    getMessages(chatId)
      .then((res) => {
        const list = res.data.messages ?? [];
        const ordered = [...list].reverse();
        dispatch(setMessagesForChat({ chatId, messages: ordered }));
        dispatch(setNextCursorForChat({ chatId, cursor: res.data.next_cursor ?? null }));
        setTimeout(() => scrollToBottom(), 100);
      })
      .catch((err: Error) => {
        setError(err.message || 'Failed to load messages');
        dispatch(setMessagesForChat({ chatId, messages: [] }));
        dispatch(setNextCursorForChat({ chatId, cursor: null }));
        showToast(err.message || 'Failed to load messages');
      })
      .finally(() => setLoading(false));
  }, [chatId, dispatch, scrollToBottom, showToast]);

  const loadMore = useCallback(() => {
    const cursor = selectNextCursorForChat(store.getState(), chatId);
    if (!chatId || cursor == null || loadingMoreRef.current) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    getMessages(chatId, { before: cursor, max: 50 })
      .then((res) => {
        const list = res.data.messages ?? [];
        const older = [...list].reverse();
        setFirstItemIndex((prev) => prev - older.length);
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
      reply_to_id: replyingTo?.id ?? null,
      reply_root_id: replyingTo?.reply_root_id ?? replyingTo?.id ?? null,
      client_generated_id: clientGeneratedId,
      sender_uid: getCurrentUserId(),
      chat_id: chatId,
      created_at: new Date().toISOString(),
      updated_at: null,
      deleted_at: null,
      has_attachments: false,
      reply_to_message: replyingTo
        ? {
            id: replyingTo.id,
            message: replyingTo.message,
            sender_uid: replyingTo.sender_uid,
            deleted_at: replyingTo.deleted_at,
          }
        : undefined,
    };
    dispatch(addMessage({ chatId, message: optimistic }));
    setReplyingTo(null);
    setTimeout(() => scrollToBottom(), 50);

    sendMessage(chatId, {
      message: text,
      message_type: 'text',
      client_generated_id: clientGeneratedId,
      reply_to_id: replyingTo?.id,
      reply_root_id: replyingTo?.reply_root_id ?? replyingTo?.id,
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
  }, [chatId, dispatch, messageText, replyingTo, scrollToBottom, showToast]);

  const handleSendRef = useRef(handleSend);
  handleSendRef.current = handleSend;

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

  const handleEdit = (message: MessageResponse) => {
    setEditingMessageId(message.id);
    setEditingText(message.message ?? '');
  };

  const handleSaveEdit = () => {
    if (!editingMessageId || !chatId) return;
    const text = editingText.trim();
    if (!text) {
      showToast('Message cannot be empty');
      return;
    }
    updateMessage(chatId, editingMessageId, { message: text })
      .then((res) => {
        const state = store.getState();
        const currentMessages = selectMessagesForChat(state, chatId);
        const updated = currentMessages.map((m) =>
          m.id === editingMessageId ? res.data : m
        );
        dispatch(setMessagesForChat({ chatId, messages: updated }));
        setEditingMessageId(null);
        setEditingText('');
        showToast('Message updated', 2000);
      })
      .catch((err: Error) => {
        showToast(err.message || 'Failed to update message');
      });
  };

  const handleCancelEdit = () => {
    setEditingMessageId(null);
    setEditingText('');
  };

  const handleDelete = (message: MessageResponse) => {
    if (!chatId) return;
    presentAlert({
      header: 'Delete Message',
      message: 'Are you sure you want to delete this message?',
      buttons: [
        { text: 'Cancel', role: 'cancel' },
        {
          text: 'Delete',
          role: 'destructive',
          handler: () => {
            deleteMessage(chatId, message.id)
              .then(() => {
                const state = store.getState();
                const currentMessages = selectMessagesForChat(state, chatId);
                const updated = currentMessages.map((m) =>
                  m.id === message.id
                    ? { ...m, deleted_at: new Date().toISOString(), message: null }
                    : m
                );
                dispatch(setMessagesForChat({ chatId, messages: updated }));
                showToast('Message deleted', 2000);
              })
              .catch((err: Error) => {
                showToast(err.message || 'Failed to delete message');
              });
          },
        },
      ],
    });
  };

  const handleReply = (message: MessageResponse) => {
    setReplyingTo(message);
    textareaRef.current?.focus();
  };

  const handleMessageAction = (message: MessageResponse) => {
    if (message.deleted_at) return;

    const isOwn = isSent(message);
    const buttons: Parameters<typeof presentActionSheet>[0]['buttons'] = [
      { text: 'Reply', handler: () => handleReply(message) },
    ];

    if (isOwn) {
      buttons.push({ text: 'Edit', handler: () => handleEdit(message) });
      buttons.push({
        text: 'Delete',
        role: 'destructive',
        handler: () => handleDelete(message),
      });
    }

    buttons.push({ text: 'Cancel', role: 'cancel' });

    presentActionSheet({ buttons });
  };

  const displayMessages = messages;
  const isMessageFirst = (index: number): boolean => {
    if (index <= 0) return true;
    return displayMessages[index].sender_uid !== displayMessages[index - 1].sender_uid;
  };
  const isMessageLast = (index: number): boolean => {
    if (index >= displayMessages.length - 1) return true;
    return displayMessages[index].sender_uid !== displayMessages[index + 1].sender_uid;
  };

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

      <IonContent className="chat-thread-content" scrollY={false}>
        {loading ? (
          <div className="chat-thread-loading">Loading…</div>
        ) : error ? (
          <div className="chat-thread-error">{error}</div>
        ) : (
          <Virtuoso
            ref={virtuosoRef}
            className="messages-virtuoso"
            data={displayMessages}
            firstItemIndex={firstItemIndex}
            initialTopMostItemIndex={displayMessages.length - 1}
            followOutput="smooth"
            alignToBottom
            components={{
              Header: () =>
                nextCursor != null ? (
                  <div className="chat-thread-load-more">
                    {loadingMore ? (
                      <IonSpinner name="dots" />
                    ) : (
                      <button className="load-more-btn" onClick={loadMore}>
                        Load older messages
                      </button>
                    )}
                  </div>
                ) : null,
            }}
            itemContent={(index, message) => {
              const arrayIndex = index - firstItemIndex;
              const isEditing = editingMessageId === message.id;
              const sent = isSent(message);
              const first = isMessageFirst(arrayIndex);
              const last = isMessageLast(arrayIndex);

              if (isEditing) {
                return (
                  <div className="message-edit-container">
                    <textarea
                      value={editingText}
                      onChange={(e) => setEditingText(e.target.value)}
                      className="message-edit-textarea"
                    />
                    <div className="message-edit-actions">
                      <button className="btn-save" onClick={handleSaveEdit}>
                        Save
                      </button>
                      <button className="btn-cancel" onClick={handleCancelEdit}>
                        Cancel
                      </button>
                    </div>
                  </div>
                );
              }

              return (
                <div
                  className={`message-row ${sent ? 'message-row--sent' : 'message-row--received'} ${first ? 'message-row--first' : ''} ${last ? 'message-row--last' : ''}`}
                  onClick={() => !message.deleted_at && handleMessageAction(message)}
                >
                  {!sent && (
                    <div className="message-avatar">
                      {last ? (
                        <img
                          src={messageAvatarUrl(message)}
                          alt={`User ${message.sender_uid}`}
                          className="message-avatar-img"
                        />
                      ) : (
                        <div className="message-avatar-spacer" />
                      )}
                    </div>
                  )}
                  <div className="message-bubble-wrap">
                    {message.reply_to_message && (
                      <div className="reply-quote">
                        <div className="reply-quote-author">
                          {message.reply_to_message.deleted_at
                            ? 'Replying to deleted message'
                            : `Replying to User ${message.reply_to_message.sender_uid}`}
                        </div>
                        {!message.reply_to_message.deleted_at &&
                          message.reply_to_message.message && (
                            <div className="reply-quote-text">
                              {message.reply_to_message.message}
                            </div>
                          )}
                      </div>
                    )}
                    <div
                      className={`message-bubble ${sent ? 'message-bubble--sent' : 'message-bubble--received'} ${message.deleted_at ? 'message-bubble--deleted' : ''}`}
                    >
                      {message.deleted_at ? '[Deleted]' : (message.message ?? '')}
                    </div>
                    <div className={`message-meta ${sent ? 'message-meta--sent' : ''}`}>
                      {messageTime(message.created_at)}
                      {message.updated_at && !message.deleted_at && ' (edited)'}
                    </div>
                  </div>
                </div>
              );
            }}
          />
        )}
      </IonContent>

      {replyingTo && (
        <div className="reply-preview-bar">
          <div className="reply-preview-content">
            <div className="reply-preview-label">Replying to</div>
            <div className="reply-preview-text">{replyingTo.message}</div>
          </div>
          <button
            type="button"
            className="reply-preview-close"
            onClick={() => setReplyingTo(null)}
          >
            ×
          </button>
        </div>
      )}

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
                // Auto-grow textarea
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
