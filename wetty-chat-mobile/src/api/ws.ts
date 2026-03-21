import apiClient from '@/api/client';
import { syncApp } from '@/api/sync';
import type { MessageResponse, ReactionSummary } from '@/api/messages';
import { setWsConnected, setActiveConnections } from '@/store/connectionSlice';
import store from '@/store/index';
import {
  messageAdded,
  messageConfirmed,
  messagePatched,
  reactionsUpdated,
} from '@/store/messageEvents';
import { setAppBadgeCount } from '@/utils/badges';

const WS_PATH = import.meta.env.BASE_URL + '_api/ws';
const PING_INTERVAL_MS = 10_000;
const MAX_RECONNECT_DELAY_MS = 30_000;
const RETRY_BASE_DELAY_MS = 1_000;
const RETRY_JITTER_RATIO = 0.2;

export type WebSocketAppState = 'active' | 'inactive';

interface ServerEnvelope {
  type?: string;
  payload?: unknown;
}

interface AuthMessage {
  type: 'auth';
  ticket: string;
}

interface PingMessage {
  type: 'ping';
  state: WebSocketAppState;
}

interface AppStateMessage {
  type: 'app_state';
  state: WebSocketAppState;
}

let ws: WebSocket | null = null;
let pingIntervalId: ReturnType<typeof setInterval> | null = null;
let reconnectTimeoutId: ReturnType<typeof setTimeout> | null = null;
let retryAttempt = 0;
let isInitialized = false;
let isConnecting = false;
let connectGeneration = 0;
let currentAppState: WebSocketAppState = 'active';
let networkOnline = typeof navigator === 'undefined' ? true : navigator.onLine !== false;
const intentionalClosures = new WeakSet<WebSocket>();

export async function requestWsTicket(): Promise<string> {
  const res = await apiClient.get<{ ticket: string }>('/ws/ticket');
  return res.data.ticket;
}

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

function getReconnectDelayMs(): number {
  if (retryAttempt === 0) return 0;

  const exponential = Math.min(
    RETRY_BASE_DELAY_MS * 2 ** (retryAttempt - 1),
    MAX_RECONNECT_DELAY_MS,
  );
  const jitter = Math.round(exponential * RETRY_JITTER_RATIO * Math.random());
  return Math.min(exponential + jitter, MAX_RECONNECT_DELAY_MS);
}

function normalizePayload(payload: unknown): MessageResponse | null {
  if (payload == null || typeof payload !== 'object') return null;
  const msg = payload as MessageResponse;
  if (!msg.chat_id || !msg.id) return null;
  return msg;
}

function allMessagesForChat(chatId: string): MessageResponse[] {
  const chat = store.getState().messages.chats[chatId];
  if (!chat) return [];
  return chat.windows.flatMap(window => window.messages);
}

const MESSAGE_PREVIEW_MAX = 100;

function showLocalNotification(message: MessageResponse): void {
  if (currentAppState !== 'inactive') return;

  // Skip notification if user is active on another connection
  const { activeConnections } = store.getState().connection;
  if (activeConnections > 1) return;

  const currentUid = store.getState().user.uid;
  if (currentUid != null && message.sender.uid === currentUid) return;
  if (message.is_deleted) return;

  if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;

  const chatEntry = store.getState().chats.byId[message.chat_id];

  // Skip notification for muted chats
  const mutedUntil = chatEntry?.liveProjection?.muted_until ?? chatEntry?.listSnapshot?.muted_until;
  if (mutedUntil && new Date(mutedUntil) > new Date()) return;

  const chatName = chatEntry?.details?.name ?? 'New Message';

  let body: string;
  if (message.message) {
    const preview = message.message.length > MESSAGE_PREVIEW_MAX
      ? message.message.slice(0, MESSAGE_PREVIEW_MAX) + '…'
      : message.message;
    body = `${message.sender.name ?? 'Someone'}: ${preview}`;
  } else {
    body = `${message.sender.name ?? 'Someone'} sent a message`;
  }

  const tag = `msg_${message.id}`;

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.ready.then(registration => {
      registration.showNotification(chatName, {
        body,
        icon: '/appicon/icon-192.png',
        badge: '/appicon/icon-192.png',
        tag,
        data: {
          type: 'new_message',
          chat_id: message.chat_id,
          message_id: message.id,
        },
      });

      // Inform the SW of the notified message so it can skip stale push notifications
      registration.active?.postMessage({
        type: 'NOTIFIED',
        chatId: message.chat_id,
        messageId: message.id,
      });
    }).catch(() => { /* SW not available */ });
  }

  if ('setAppBadge' in navigator) {
    const totalUnread = Object.values(store.getState().chats.byId)
      .reduce((sum, entry) => {
        const unread = entry.liveProjection?.unread_count
          ?? entry.listSnapshot?.unread_count
          ?? 0;
        return sum + unread;
      }, 0);
    setAppBadgeCount(navigator, totalUnread)?.catch(() => {});
  }
}

function handleWsMessage(payload: unknown): void {
  const message = normalizePayload(payload);
  if (!message) return;

  const storeChatId = message.reply_root_id
    ? `${message.chat_id}_thread_${message.reply_root_id}`
    : message.chat_id;
  const all = allMessagesForChat(storeChatId);
  const pending = all.find(
    current =>
      current.client_generated_id === message.client_generated_id &&
      current.id.startsWith('cg_'),
  );

  if (pending) {
    store.dispatch(
      messageConfirmed({
        chatId: message.chat_id,
        storeChatId,
        clientGeneratedId: message.client_generated_id,
        message,
        origin: 'ws',
        scope: message.reply_root_id ? 'thread' : 'main',
      })
    );
  } else {
    const exists = all.some(
      current =>
        current.id === message.id ||
        current.client_generated_id === message.client_generated_id,
    );
    if (!exists) {
      store.dispatch(messageAdded({
        chatId: message.chat_id,
        storeChatId,
        message,
        origin: 'ws',
        scope: message.reply_root_id ? 'thread' : 'main',
      }));
      showLocalNotification(message);
    }
  }
}

function sendJson(message: AuthMessage | PingMessage | AppStateMessage): void {
  if (ws?.readyState !== WebSocket.OPEN) return;
  ws.send(JSON.stringify(message));
}

function publishAppState(): void {
  sendJson({ type: 'app_state', state: currentAppState });
}

function closeSocket(socket: WebSocket | null): void {
  if (socket == null) return;
  intentionalClosures.add(socket);
  try {
    socket.close();
  } catch {
    // ignore
  }
}

function markDisconnected(socket: WebSocket, shouldReconnect: boolean): void {
  if (intentionalClosures.has(socket)) {
    intentionalClosures.delete(socket);
  }

  if (ws === socket) {
    ws = null;
  }

  clearPingInterval();
  isConnecting = false;
  store.dispatch(setWsConnected(false));

  if (shouldReconnect) {
    scheduleReconnect();
  }
}

function scheduleReconnect(): void {
  if (!isInitialized) return;
  if (ws != null || isConnecting) return;
  if (!networkOnline) {
    clearReconnectTimeout();
    return;
  }
  if (reconnectTimeoutId != null) return;

  const delay = getReconnectDelayMs();
  retryAttempt += 1;
  reconnectTimeoutId = setTimeout(() => {
    reconnectTimeoutId = null;
    void connectWebSocket();
  }, delay);
}

async function connectWebSocket(): Promise<void> {
  if (!isInitialized) return;
  if (typeof WebSocket === 'undefined') return;
  if (!networkOnline) {
    store.dispatch(setWsConnected(false));
    return;
  }
  if (ws != null || isConnecting) return;

  isConnecting = true;
  clearReconnectTimeout();
  const generation = ++connectGeneration;

  try {
    const ticket = await requestWsTicket();
    if (generation !== connectGeneration || !isInitialized || !networkOnline) {
      isConnecting = false;
      return;
    }

    const protocol =
      typeof location !== 'undefined' && location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = typeof location !== 'undefined' ? location.host : 'localhost';
    const socket = new WebSocket(`${protocol}//${host}${WS_PATH}`);
    ws = socket;

    socket.onopen = () => {
      if (generation !== connectGeneration) {
        closeSocket(socket);
        return;
      }

      isConnecting = false;
      retryAttempt = 0;
      store.dispatch(setWsConnected(true));

      sendJson({ type: 'auth', ticket });
      publishAppState();
      syncApp();

      clearPingInterval();
      pingIntervalId = setInterval(() => {
        sendJson({ type: 'ping', state: currentAppState });
      }, PING_INTERVAL_MS);
    };

    socket.onmessage = event => {
      if (typeof event.data !== 'string') return;

      try {
        const message = JSON.parse(event.data) as ServerEnvelope;
        if (message.type === 'pong') {
          return;
        }

        if (message.type === 'message' && message.payload != null) {
          handleWsMessage(message.payload);
          return;
        }

        if (
          (message.type === 'message_deleted' || message.type === 'message_updated') &&
          message.payload != null
        ) {
          const payload = normalizePayload(message.payload);
          if (!payload) return;
          store.dispatch(messagePatched({
            chatId: payload.chat_id,
            messageId: payload.id,
            message: payload,
          }));
          return;
        }

        if (message.type === 'reaction_updated' && message.payload != null) {
          const payload = message.payload as {
            message_id: string;
            chat_id: string;
            reactions: ReactionSummary[];
          };
          if (payload.message_id && payload.chat_id) {
            store.dispatch(reactionsUpdated({
              chatId: payload.chat_id,
              messageId: payload.message_id,
              reactions: payload.reactions ?? [],
            }));
          }
          return;
        }

        if (message.type === 'presence_update' && message.payload != null) {
          const payload = message.payload as { active_connections: number };
          store.dispatch(setActiveConnections(payload.active_connections));
        }
      } catch {
        // ignore malformed websocket messages
      }
    };

    socket.onerror = () => {
      markDisconnected(socket, !intentionalClosures.has(socket));
    };

    socket.onclose = () => {
      markDisconnected(socket, !intentionalClosures.has(socket));
    };
  } catch (error) {
    isConnecting = false;
    store.dispatch(setWsConnected(false));
    console.error('Failed to establish websocket:', error);
    scheduleReconnect();
  }
}

function reconnectNow(resetBackoff: boolean): void {
  if (!isInitialized) return;
  if (!networkOnline) {
    store.dispatch(setWsConnected(false));
    clearReconnectTimeout();
    return;
  }

  clearReconnectTimeout();
  if (resetBackoff) {
    retryAttempt = 0;
  }
  connectGeneration += 1;

  const currentSocket = ws;
  ws = null;
  closeSocket(currentSocket);
  clearPingInterval();
  isConnecting = false;

  void connectWebSocket();
}

export function initWebSocket(): void {
  if (isInitialized) return;
  isInitialized = true;
  void connectWebSocket();
}

export function setWebSocketAppState(state: WebSocketAppState): void {
  currentAppState = state;
  publishAppState();
}

export function handleWebSocketOnline(): void {
  networkOnline = true;
  reconnectNow(true);
}

export function handleWebSocketOffline(): void {
  networkOnline = false;
  clearReconnectTimeout();
  clearPingInterval();
  closeSocket(ws);
  ws = null;
  isConnecting = false;
  store.dispatch(setWsConnected(false));
}

export function ensureWebSocketConnected(resetBackoff = false): void {
  if (ws != null || isConnecting) return;
  reconnectNow(resetBackoff);
}
