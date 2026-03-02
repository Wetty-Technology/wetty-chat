/**
 * WebSocket client: connects to /_api/ws?uid=, sends JSON ping every 10s, handles pong and message delivery.
 * Dispatches incoming messages to the Redux store (add or confirm pending). Same host as REST so Vite proxy works in dev.
 */

import { getCurrentUserId } from '@/js/current-user';
import store from '@/store/index';
import { addMessage, confirmPendingMessage } from '@/store/messagesSlice';
import { setWsConnected } from '@/store/connectionSlice';
import type { MessageResponse, ReplyToMessage } from '@/api/messages';

const WS_PATH = '/_api/ws';
const PING_INTERVAL_MS = 10_000;
const RECONNECT_DELAY_MS = 5_000;

const PING_JSON = JSON.stringify({ type: 'ping' });

let ws: WebSocket | null = null;
let reconnectTimeoutId: ReturnType<typeof setTimeout> | null = null;

function getWsUrl(uid: number): string {
  const protocol = typeof location !== 'undefined' && location.protocol === 'https:' ? 'wss:' : 'ws:';
  const host = typeof location !== 'undefined' ? location.host : 'localhost';
  return `${protocol}//${host}${WS_PATH}?uid=${uid}`;
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
  const sender_uid = typeof o.sender_uid === 'number' ? o.sender_uid : 0;
  const message = o.message != null ? String(o.message) : null;
  const message_type = typeof o.message_type === 'string' ? o.message_type : 'text';
  const created_at = typeof o.created_at === 'string' ? o.created_at : new Date().toISOString();
  if (chat_id == null) return null;
  const reply_to_message_raw = o.reply_to_message;
  let reply_to_message: ReplyToMessage | undefined;
  if (reply_to_message_raw != null && typeof reply_to_message_raw === 'object') {
    const r = reply_to_message_raw as Record<string, unknown>;
    reply_to_message = {
      id: r.id != null ? String(r.id) : '0',
      message: r.message != null ? String(r.message) : null,
      sender_uid: typeof r.sender_uid === 'number' ? r.sender_uid : 0,
      deleted_at: r.deleted_at != null ? String(r.deleted_at) : null,
    };
  }
  return {
    id: id ?? '0',
    message,
    message_type,
    reply_to_id: o.reply_to_id != null ? String(o.reply_to_id) : null,
    reply_root_id: o.reply_root_id != null ? String(o.reply_root_id) : null,
    reply_to_message,
    client_generated_id,
    sender_uid,
    chat_id,
    created_at,
    updated_at: o.updated_at != null ? String(o.updated_at) : null,
    deleted_at: o.deleted_at != null ? String(o.deleted_at) : null,
    has_attachments: Boolean(o.has_attachments),
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
  const chatId = message.chat_id;
  const all = allMessagesForChat(chatId);
  const pending = all.find((m: MessageResponse) => m.client_generated_id === message.client_generated_id && m.id === '0');
  if (pending) {
    store.dispatch(confirmPendingMessage({
      chatId,
      clientGeneratedId: message.client_generated_id,
      message,
    }));
  } else {
    const exists = all.some((m: MessageResponse) => m.id === message.id || m.client_generated_id === message.client_generated_id);
    if (!exists) {
      store.dispatch(addMessage({ chatId, message }));
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

  const uid = getCurrentUserId();
  const url = getWsUrl(uid);
  const socket = new WebSocket(url);
  ws = socket;

  socket.onopen = () => {
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
}
