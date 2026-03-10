/**
 * WebSocket client: connects to /_api/ws?uid=, sends JSON ping every 10s, handles pong and message delivery.
 * Dispatches incoming messages to the Redux store (add or confirm pending). Same host as REST so Vite proxy works in dev.
 */

import apiClient from '@/api/client';
import store from '@/store/index';
import { addMessage, confirmPendingMessage, updateMessageInStore } from '@/store/messagesSlice';
import { setWsConnected } from '@/store/connectionSlice';
import type { MessageResponse, ReplyToMessage, ThreadInfo } from '@/api/messages';

const WS_PATH = import.meta.env.BASE_URL + '_api/ws';
const PING_INTERVAL_MS = 10_000;
const RECONNECT_DELAY_MS = 5_000;

const PING_JSON = JSON.stringify({ type: 'ping' });

let ws: WebSocket | null = null;
let reconnectTimeoutId: ReturnType<typeof setTimeout> | null = null;

export async function requestWsTicket(): Promise<string> {
  const res = await apiClient.get<{ ticket: string }>('/ws/ticket');
  return res.data.ticket;
}

let pingIntervalId: ReturnType<typeof setInterval> | null = null;

function clearPingInterval(): void {
  if (pingIntervalId != null) {
    clearInterval(pingIntervalId);
    pingIntervalId = null;
  }
}

function clearReconnectTimeout(): void {
  if (reconnectTimeoutId != null) {
    clearTimeout(reconnectTimeoutId);
    reconnectTimeoutId = null;
  }
}

function scheduleReconnect(): void {
  if (reconnectTimeoutId != null) return;
  reconnectTimeoutId = setTimeout(() => {
    reconnectTimeoutId = null;
    initWebSocket();
  }, RECONNECT_DELAY_MS);
}

function normalizePayload(p: unknown): MessageResponse | null {
  if (p == null || typeof p !== 'object') return null;
  const o = p as Record<string, unknown>;
  const id = o.id != null ? String(o.id) : undefined;
  // Server sends group/chat id as 'gid'; map to chat_id used in MessageResponse
  const chat_id = o.gid != null ? String(o.gid) : (o.chat_id != null ? String(o.chat_id) : undefined);
  const client_generated_id = typeof o.client_generated_id === 'string' ? o.client_generated_id : '';

  // Extract sender
  const senderObj = o.sender as Record<string, unknown> | undefined;
  const sender_uid = senderObj != null && typeof senderObj.uid === 'number' ? senderObj.uid : 0;
  const sender_name = senderObj != null && typeof senderObj.name === 'string' ? senderObj.name : null;
  const sender = { uid: sender_uid, name: sender_name };

  const message = o.message != null ? String(o.message) : null;
  const message_type = typeof o.message_type === 'string' ? o.message_type : 'text';
  const created_at = typeof o.created_at === 'string' ? o.created_at : new Date().toISOString();
  if (chat_id == null) return null;
  const reply_to_message_raw = o.reply_to_message;
  let reply_to_message: ReplyToMessage | undefined;
  if (reply_to_message_raw != null && typeof reply_to_message_raw === 'object') {
    const r = reply_to_message_raw as Record<string, unknown>;
    const repSenderObj = r.sender as Record<string, unknown> | undefined;
    reply_to_message = {
      id: r.id != null ? String(r.id) : '0',
      message: r.message != null ? String(r.message) : null,
      sender: {
        uid: repSenderObj != null && typeof repSenderObj.uid === 'number' ? repSenderObj.uid : 0,
        name: repSenderObj != null && typeof repSenderObj.name === 'string' ? repSenderObj.name : null,
      },
      is_deleted: Boolean(r.is_deleted),
    };
  }
  const attachmentsRaw = Array.isArray(o.attachments) ? o.attachments : [];
  const attachments = attachmentsRaw.map((a: any) => ({
    id: a.id != null ? String(a.id) : '0',
    url: typeof a.url === 'string' ? a.url : '',
    kind: typeof a.kind === 'string' ? a.kind : 'unknown',
    size: typeof a.size === 'number' ? a.size : 0,
    file_name: typeof a.file_name === 'string' ? a.file_name : 'attachment',
  }));

  let thread_info: ThreadInfo | undefined;
  if (o.thread_info != null && typeof o.thread_info === 'object') {
    const ti = o.thread_info as Record<string, unknown>;
    thread_info = {
      reply_count: typeof ti.reply_count === 'number' ? ti.reply_count : 0,
    };
  }

  return {
    id: id ?? '0',
    message,
    message_type,
    reply_root_id: o.reply_root_id != null ? String(o.reply_root_id) : null,
    reply_to_message,
    client_generated_id,
    sender,
    chat_id,
    created_at,
    is_edited: Boolean(o.is_edited),
    is_deleted: Boolean(o.is_deleted),
    has_attachments: Boolean(o.has_attachments),
    thread_info,
    attachments,
  };
}

function allMessagesForChat(chatId: string): MessageResponse[] {
  const chat = store.getState().messages.chats[chatId];
  if (!chat) return [];
  return chat.windows.flatMap(w => w.messages);
}

function handleWsMessage(payload: unknown): void {
  const message = normalizePayload(payload);
  if (!message) return;
  const targetChatId = message.reply_root_id
    ? `${message.chat_id}_thread_${message.reply_root_id}`
    : message.chat_id;
  const all = allMessagesForChat(targetChatId);
  const pending = all.find((m: MessageResponse) => m.client_generated_id === message.client_generated_id && m.id === '0');
  if (pending) {
    store.dispatch(confirmPendingMessage({
      chatId: targetChatId,
      clientGeneratedId: message.client_generated_id,
      message,
    }));
  } else {
    const exists = all.some((m: MessageResponse) => m.id === message.id || m.client_generated_id === message.client_generated_id);
    if (!exists) {
      store.dispatch(addMessage({ chatId: targetChatId, message }));
    }
  }
}

export function initWebSocket(): void {
  if (typeof WebSocket === 'undefined') return;

  clearReconnectTimeout();
  if (ws != null) {
    try {
      ws.close();
    } catch {
      // ignore
    }
    ws = null;
  }

  requestWsTicket().then(ticket => {
    // If we've already scheduled a reconnect while waiting for the ticket, abort
    if (reconnectTimeoutId != null) return;

    const protocol = typeof location !== 'undefined' && location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = typeof location !== 'undefined' ? location.host : 'localhost';
    const url = `${protocol}//${host}${WS_PATH}`;

    const socket = new WebSocket(url);
    ws = socket;

    socket.onopen = () => {
      // Send the auth ticket immediately upon connection
      socket.send(JSON.stringify({ type: 'auth', ticket }));

      clearReconnectTimeout();
      store.dispatch(setWsConnected(true));
      console.log('ws opened');
      pingIntervalId = setInterval(() => {
        if (socket.readyState === WebSocket.OPEN) {
          socket.send(PING_JSON);
        }
      }, PING_INTERVAL_MS);
    };

    socket.onmessage = (event) => {
      if (typeof event.data !== 'string') return;
      try {
        const msg = JSON.parse(event.data) as { type?: string; payload?: unknown };
        if (msg.type === 'pong') {
          // Keepalive acknowledged
        } else if (msg.type === 'message' && msg.payload != null) {
          handleWsMessage(msg.payload);
        } else if ((msg.type === 'message_deleted' || msg.type === 'message_updated') && msg.payload != null) {
          const message = normalizePayload(msg.payload);
          if (message) {
            // Update in all chat states that start with this chat's ID (main chat and threads)
            const state = store.getState();
            const chatPrefix = `${message.chat_id}`;
            for (const key of Object.keys(state.messages.chats)) {
              if (key === chatPrefix || key.startsWith(`${chatPrefix}_thread_`)) {
                store.dispatch(updateMessageInStore({
                  chatId: key,
                  messageId: message.id,
                  message,
                }));
              }
            }
          }
        }
      } catch {
        // ignore non-JSON or invalid messages
      }
    };

    function markDisconnected(): void {
      if (ws !== socket) return;
      clearPingInterval();
      store.dispatch(setWsConnected(false));
      ws = null;
      scheduleReconnect();
    }

    socket.onerror = () => {
      markDisconnected();
    };

    socket.onclose = () => {
      markDisconnected();
    };
  }).catch(err => {
    console.error('Failed to get ws ticket:', err);
    scheduleReconnect();
  });
}
