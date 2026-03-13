/**
 * WebSocket client: connects to /_api/ws?uid=, sends JSON ping every 10s, handles pong and message delivery.
 * Dispatches incoming messages to the Redux store (add or confirm pending). Same host as REST so Vite proxy works in dev.
 */

import apiClient from '@/api/client';
import store from '@/store/index';
import { addMessage, confirmPendingMessage, updateMessageInStore } from '@/store/messagesSlice';
import { updateChatFromMessage } from '@/store/chatsSlice';
import { setWsConnected } from '@/store/connectionSlice';
import { syncApp } from '@/api/sync';
import type { MessageResponse } from '@/api/messages';

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
  const msg = p as MessageResponse;
  
  if (!msg.chat_id || !msg.id) return null;
  
  return msg;
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

  if (message.chat_id) {
    store.dispatch(updateChatFromMessage({
      chatId: message.chat_id,
      message,
      currentUserId: store.getState().user.uid || 0
    }));
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

      syncApp();

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
