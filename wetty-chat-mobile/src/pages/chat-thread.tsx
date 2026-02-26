import React, { useRef, useState, useEffect, useCallback } from 'react';
import {
  f7,
  Icon,
  Navbar,
  Link,
  Page,
  Messages,
  Message,
  Messagebar,
} from 'framework7-react';
import type { Messagebar as F7MessagebarInstance } from 'framework7/types';
import { useDispatch, useSelector } from 'react-redux';
import './chat-thread.scss';
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

interface Props {
  f7route?: {
    params: Record<string, string>;
    route?: { context?: { chatName?: string }; options?: { props?: { chatName?: string } } };
  };
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

/** Placeholder avatar URL (initials). Self = "Me", others = "U{sender_uid}". */
function messageAvatarUrl(message: MessageResponse): string {
  const name = isSent(message) ? 'Me' : `U${message.sender_uid}`;
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&size=64&background=random`;
}

export default function ChatThread({ f7route }: Props) {
  const { id } = f7route?.params || {};
  const chatId = id ? String(id) : '';
  const chatName =
    f7route?.route?.options?.props?.chatName ??
    f7route?.route?.context?.chatName ??
    (id ? `Chat ${id}` : 'Chat');

  const dispatch = useDispatch();
  const messages = useSelector((state: RootState) => selectMessagesForChat(state, chatId));
  const nextCursor = useSelector((state: RootState) => selectNextCursorForChat(state, chatId));

  type MessagebarRefValue = { el: HTMLElement | null; f7Messagebar: () => F7MessagebarInstance.Messagebar };
  const messagebarRef = useRef<MessagebarRefValue | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const wasAtBottomRef = useRef(true);
  const scrollContainerRef = useRef<HTMLElement | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [messageText, setMessageText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [editingMessageId, setEditingMessageId] = useState<string | null>(null);
  const [editingText, setEditingText] = useState('');
  const [replyingTo, setReplyingTo] = useState<MessageResponse | null>(null);

  const scrollToBottom = useCallback(() => {
    const endEl = messagesEndRef.current;
    if (!endEl) return;
    endEl.scrollIntoView({ behavior: 'auto', block: 'end' });
    // Account for fixed Messagebar: scroll a bit more so the last message is above the bar.
    requestAnimationFrame(() => {
      let el: HTMLElement | null = endEl.parentElement;
      let container: HTMLElement | null = null;
      while (el) {
        const style = getComputedStyle(el);
        const overflowY = style.overflowY;
        if (el.scrollHeight > el.clientHeight && (overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'overlay')) {
          container = el;
          break;
        }
        el = el.parentElement;
      }
      const messagebarEl = messagebarRef.current?.el;
      const messagebarHeight = messagebarEl ? messagebarEl.offsetHeight : 0;
      if (container && messagebarHeight > 0) {
        container.scrollBy(0, messagebarHeight);
      }
    });
  }, []);

  // Track scroll position to know if user is at bottom (for auto-scroll on new messages).
  useEffect(() => {
    const endEl = messagesEndRef.current;
    if (!endEl) return;
    let el: HTMLElement | null = endEl.parentElement;
    while (el) {
      const style = getComputedStyle(el);
      const overflowY = style.overflowY;
      if (el.scrollHeight > el.clientHeight && (overflowY === 'auto' || overflowY === 'scroll' || overflowY === 'overlay')) {
        scrollContainerRef.current = el;
        break;
      }
      el = el.parentElement;
    }
    const container = scrollContainerRef.current;
    if (!container) return;
    const updateAtBottom = () => {
      const threshold = 80;
      wasAtBottomRef.current = container.scrollTop + container.clientHeight >= container.scrollHeight - threshold;
    };
    updateAtBottom();
    container.addEventListener('scroll', updateAtBottom, { passive: true });
    return () => {
      container.removeEventListener('scroll', updateAtBottom);
      scrollContainerRef.current = null;
    };
  }, [messages.length, loading, error]);

  // When Redux messages for this chat change and user was at bottom, scroll to bottom.
  useEffect(() => {
    if (!chatId || !wasAtBottomRef.current) return;
    requestAnimationFrame(() => scrollToBottom());
  }, [chatId, messages, scrollToBottom]);

  // Initial load: fetch from API and write to store.
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
        requestAnimationFrame(() => scrollToBottom());
      })
      .catch((err: Error) => {
        setError(err.message || 'Failed to load messages');
        dispatch(setMessagesForChat({ chatId, messages: [] }));
        dispatch(setNextCursorForChat({ chatId, cursor: null }));
        f7.toast.create({ text: err.message || 'Failed to load messages', closeTimeout: 3000 }).open();
      })
      .finally(() => setLoading(false));
  }, [chatId, dispatch, scrollToBottom]);

  const loadMore = () => {
    if (!chatId || nextCursor == null || loadingMore) return;
    setLoadingMore(true);
    getMessages(chatId, { before: nextCursor, max: 50 })
      .then((res) => {
        const list = res.data.messages ?? [];
        const older = [...list].reverse();
        dispatch(prependMessages({ chatId, messages: older }));
        dispatch(setNextCursorForChat({ chatId, cursor: res.data.next_cursor ?? null }));
      })
      .catch((err: Error) => {
        f7.toast.create({ text: err.message || 'Failed to load more', closeTimeout: 3000 }).open();
      })
      .finally(() => setLoadingMore(false));
  };

  const handleSend = () => {
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
      reply_to_message: replyingTo ? {
        id: replyingTo.id,
        message: replyingTo.message,
        sender_uid: replyingTo.sender_uid,
        deleted_at: replyingTo.deleted_at,
      } : undefined,
    };
    dispatch(addMessage({ chatId, message: optimistic }));
    setReplyingTo(null);
    requestAnimationFrame(() => scrollToBottom());

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
            dispatch(confirmPendingMessage({
              chatId,
              clientGeneratedId,
              message: postResponse,
            }));
          }
        }, 15000);
      })
      .catch((err: Error) => {
        f7.toast.create({ text: err.message || 'Failed to send', closeTimeout: 3000 }).open();
        const state = store.getState();
        const currentMessages = selectMessagesForChat(state, chatId);
        const current = currentMessages.filter(
          (m) => m.client_generated_id !== clientGeneratedId
        );
        dispatch(setMessagesForChat({ chatId, messages: current }));
        setMessageText(text);
      });
    setTimeout(() => {
      const mb = messagebarRef.current?.f7Messagebar?.();
      if (typeof mb?.focus === 'function') mb.focus();
    }, 0);
  };

  const handleEdit = (message: MessageResponse) => {
    setEditingMessageId(message.id);
    setEditingText(message.message ?? '');
  };

  const handleSaveEdit = () => {
    if (!editingMessageId || !chatId) return;
    const text = editingText.trim();
    if (!text) {
      f7.toast.create({ text: 'Message cannot be empty', closeTimeout: 3000 }).open();
      return;
    }

    updateMessage(chatId, editingMessageId, { message: text })
      .then((res) => {
        const state = store.getState();
        const currentMessages = selectMessagesForChat(state, chatId);
        const updated = currentMessages.map(m => m.id === editingMessageId ? res.data : m);
        dispatch(setMessagesForChat({ chatId, messages: updated }));
        setEditingMessageId(null);
        setEditingText('');
        f7.toast.create({ text: 'Message updated', closeTimeout: 2000 }).open();
      })
      .catch((err: Error) => {
        f7.toast.create({ text: err.message || 'Failed to update message', closeTimeout: 3000 }).open();
      });
  };

  const handleCancelEdit = () => {
    setEditingMessageId(null);
    setEditingText('');
  };

  const handleDelete = (message: MessageResponse) => {
    if (!chatId) return;
    f7.dialog.confirm('Are you sure you want to delete this message?', () => {
      deleteMessage(chatId, message.id)
        .then(() => {
          const state = store.getState();
          const currentMessages = selectMessagesForChat(state, chatId);
          const updated = currentMessages.map(m =>
            m.id === message.id
              ? { ...m, deleted_at: new Date().toISOString(), message: null }
              : m
          );
          dispatch(setMessagesForChat({ chatId, messages: updated }));
          f7.toast.create({ text: 'Message deleted', closeTimeout: 2000 }).open();
        })
        .catch((err: Error) => {
          f7.toast.create({ text: err.message || 'Failed to delete message', closeTimeout: 3000 }).open();
        });
    });
  };

  const handleReply = (message: MessageResponse) => {
    setReplyingTo(message);
    const mb = messagebarRef.current?.f7Messagebar?.();
    if (typeof mb?.focus === 'function') mb.focus();
  };

  const handleMessageAction = (message: MessageResponse) => {
    if (message.deleted_at) return;

    const isOwn = isSent(message);
    const buttons = [];

    buttons.push({
      text: 'Reply',
      onClick: () => handleReply(message),
    });

    if (isOwn) {
      buttons.push({
        text: 'Edit',
        onClick: () => handleEdit(message),
      });
      buttons.push({
        text: 'Delete',
        color: 'red',
        onClick: () => handleDelete(message),
      });
    }

    buttons.push({
      text: 'Cancel',
      color: 'gray',
    });

    f7.actions.create({
      buttons: [buttons],
    }).open();
  };

  const moveFocusToThisPage = () => {
    const mb = messagebarRef.current?.f7Messagebar?.();
    if (typeof mb?.focus === 'function') {
      mb.focus();
    } else {
      const pageEl = document.querySelector('.chat-thread-page.page-current, .chat-thread-page.page-next');
      if (pageEl instanceof HTMLElement) {
        if (!pageEl.hasAttribute('tabindex')) pageEl.setAttribute('tabindex', '-1');
        pageEl.focus({ preventScroll: true });
      }
    }
  };
  const handleSendRef = useRef(handleSend);
  handleSendRef.current = handleSend;

  const handlePageBeforeIn = () => requestAnimationFrame(moveFocusToThisPage);
  const handlePageAfterIn = () => moveFocusToThisPage();

  // Configure messagebar textarea: Enter sends, enterkeyhint shows "Send" (simplifies mobile keyboard bar).
  useEffect(() => {
    let teardown: (() => void) | undefined;
    const id = setTimeout(() => {
      const textarea = messagebarRef.current?.el?.querySelector('textarea');
      if (!textarea) return;
      textarea.setAttribute('enterkeyhint', 'send');
      const onKeyDown = (e: KeyboardEvent) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          handleSendRef.current();
        }
      };
      textarea.addEventListener('keydown', onKeyDown);
      teardown = () => textarea.removeEventListener('keydown', onKeyDown);
    }, 0);
    return () => {
      clearTimeout(id);
      teardown?.();
    };
  }, []);

  const displayMessages = messages;
  const isMessageFirst = (index: number): boolean => {
    if (index <= 0) return true;
    return displayMessages[index].sender_uid !== displayMessages[index - 1].sender_uid;
  };
  const isMessageLast = (index: number): boolean => {
    if (index >= displayMessages.length - 1) return true;
    return displayMessages[index].sender_uid !== displayMessages[index + 1].sender_uid;
  };
  const isSameAvatarAsPrevious = (index: number): boolean => {
    if (index <= 0) return false;
    const prev = displayMessages[index - 1];
    const curr = displayMessages[index];
    return curr.sender_uid === prev.sender_uid;
  };

  return (
    <Page
      className="messages-page chat-thread-page"
      noToolbar
      messagesContent
      onPageBeforeIn={handlePageBeforeIn}
      onPageAfterIn={handlePageAfterIn}
    >
      <Navbar className="messages-navbar" title={chatName} backLink backLinkShowText={false}>
        <Link slot="right" iconF7="person_2" href={`/chats/${chatId}/members/`} />
        <Link slot="right" iconF7="gear" href={`/chats/${chatId}/settings/`} />
      </Navbar>
      {replyingTo && (
        <div className="reply-preview" style={{ padding: '8px 16px', backgroundColor: '#f0f0f0', borderBottom: '1px solid #ddd' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: '12px', color: '#666' }}>Replying to</div>
              <div style={{ fontSize: '14px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {replyingTo.message}
              </div>
            </div>
            <button
              type="button"
              onClick={() => setReplyingTo(null)}
              style={{ background: 'none', border: 'none', fontSize: '20px', cursor: 'pointer', padding: '0 8px' }}
            >
              ×
            </button>
          </div>
        </div>
      )}
      <Messagebar
        ref={messagebarRef as React.RefObject<MessagebarRefValue>}
        placeholder="Message"
        value={messageText}
        onInput={(e) => setMessageText((e.target as HTMLInputElement)?.value ?? '')}
        onSubmit={handleSend}
      >
        <button
          type="button"
          slot="send-link"
          className={`messagebar-send-link ${messageText.trim().length === 0 ? 'messagebar-send-link--disabled' : ''}`}
          onClick={(e) => {
            e.stopPropagation();
            handleSend();
          }}
          aria-label="Send message"
        >
          <Icon f7="paperplane_fill" />
        </button>
      </Messagebar>
      <Messages>
        {loading ? (
          <div className="chat-thread-loading">Loading…</div>
        ) : error ? (
          <div className="chat-thread-error">{error}</div>
        ) : (
          <>
            {nextCursor != null && (
              <div className="chat-thread-load-more">
                <Link
                  className={loadingMore ? 'link-disabled' : undefined}
                  onClick={() => !loadingMore && loadMore()}
                >
                  {loadingMore ? 'Loading…' : 'Load older messages'}
                </Link>
              </div>
            )}
            {displayMessages.map((message, index) => {
              const isEditing = editingMessageId === message.id;
              return isEditing ? (
                <div key={message.id || message.client_generated_id} style={{ padding: '8px 16px', backgroundColor: '#f9f9f9', borderRadius: '8px', margin: '8px' }}>
                  <textarea
                    value={editingText}
                    onChange={(e) => setEditingText(e.target.value)}
                    style={{ width: '100%', minHeight: '60px', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', fontSize: '14px' }}
                  />
                  <div style={{ marginTop: '8px', display: 'flex', gap: '8px' }}>
                    <button
                      onClick={handleSaveEdit}
                      style={{ flex: 1, padding: '8px', backgroundColor: '#007aff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
                    >
                      Save
                    </button>
                    <button
                      onClick={handleCancelEdit}
                      style={{ flex: 1, padding: '8px', backgroundColor: '#ccc', color: 'black', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              ) : (
                <Message
                  key={message.id || message.client_generated_id}
                  type={isSent(message) ? 'sent' : 'received'}
                  first={isMessageFirst(index)}
                  last={isMessageLast(index)}
                  tail={isMessageLast(index)}
                  sameAvatar={isSameAvatarAsPrevious(index)}
                  avatar={isSent(message) ? undefined : messageAvatarUrl(message)}
                  text={message.deleted_at ? '[Deleted]' : (message.message ?? '')}
                  className="message-appear-from-bottom"
                  onClick={() => !message.deleted_at && handleMessageAction(message)}
                >
                  {message.reply_to_message && (
                    <div
                      slot="text-header"
                      style={{
                        fontSize: '12px',
                        color: '#666',
                        backgroundColor: 'rgba(0,0,0,0.05)',
                        padding: '4px 8px',
                        borderRadius: '4px',
                        marginBottom: '4px',
                        borderLeft: '3px solid #007aff'
                      }}
                    >
                      <div style={{ fontWeight: 'bold', marginBottom: '2px' }}>
                        {message.reply_to_message.deleted_at
                          ? 'Replying to deleted message'
                          : `Replying to User ${message.reply_to_message.sender_uid}`}
                      </div>
                      {!message.reply_to_message.deleted_at && message.reply_to_message.message && (
                        <div style={{
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                          fontStyle: 'italic'
                        }}>
                          {message.reply_to_message.message}
                        </div>
                      )}
                    </div>
                  )}
                  <span slot="text-footer">
                    {messageTime(message.created_at)}
                    {message.updated_at && !message.deleted_at && ' (edited)'}
                  </span>
                </Message>
              );
            })}
            <div ref={messagesEndRef} aria-hidden="true" />
          </>
        )}
      </Messages>
    </Page>
  );
}
