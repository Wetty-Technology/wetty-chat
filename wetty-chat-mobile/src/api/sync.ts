import { type ChatListEntry, getChats } from '@/api/chats';
import { getMessages } from '@/api/messages';
import { setChatsList } from '@/store/chatsSlice';
import { appendMessages } from '@/store/messagesSlice';
import store from '@/store/index';
import { syncAppBadgeCount } from '@/utils/badges';

let isSyncing = false;
let syncTimeout: ReturnType<typeof setTimeout> | null = null;

/**
 * Robustly synchronizes the app state when coming to the foreground or reconnecting.
 * - Fetches the latest chats list (updating previews and unread counts).
 * - Updates the system app badge.
 * - Checks currently loaded chat windows and fetches any missing messages
 *   (appending them seamlessly so as not to disrupt a user scrolling history).
 */
export async function syncApp() {
  // Debounce multiple concurrent triggers (e.g. visibilitychange + ws.onopen)
  if (syncTimeout) clearTimeout(syncTimeout);

  syncTimeout = setTimeout(async () => {
    // Abort if already syncing, if app is in background, or user is not logged in.
    if (isSyncing) return;
    if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return;
    if (!store.getState().user.uid) return;

    isSyncing = true;
    try {
      // 1. Sync Chats List & App Badge
      const chatsRes = await getChats();
      const chats = chatsRes.data.chats || [];
      store.dispatch(setChatsList(chats));

      await syncAppBadgeCount();

      // 2. Sync Active Message Windows
      const state = store.getState();
      const activeChats = state.messages.chats;

      for (const [storeChatId, chatState] of Object.entries(activeChats)) {
        const win = chatState.windows[chatState.activeWindowIndex];
        if (!win || win.messages.length === 0) continue;

        // Get last real (non-optimistic) message in the current window
        const lastMsg = win.messages[win.messages.length - 1];
        if (!lastMsg || lastMsg.id.startsWith('cg_')) continue;

        let apiChatId = storeChatId;
        let threadId: string | undefined = undefined;

        if (storeChatId.includes('_thread_')) {
          const parts = storeChatId.split('_thread_');
          apiChatId = parts[0];
          threadId = parts[1];
        } else {
          // For main chats, optimize: only fetch if chatsList indicates a newer message
          const chatListItem = chats.find((c: ChatListEntry) => c.id === apiChatId);
          if (chatListItem && chatListItem.last_message) {
            const serverId = BigInt(chatListItem.last_message.id);
            const localId = BigInt(lastMsg.id);
            if (serverId <= localId) {
              continue; // Local state is up to date for this chat
            }
          }
        }

        // Fetch missing newer messages for this chat/thread
        try {
          const messagesRes = await getMessages(apiChatId, {
            after: lastMsg.id,
            max: 50,
            thread_id: threadId,
          });

          if (messagesRes.data.messages && messagesRes.data.messages.length > 0) {
            store.dispatch(
              appendMessages({
                chatId: storeChatId,
                messages: messagesRes.data.messages,
                prevCursor: messagesRes.data.prev_cursor ?? null,
              }),
            );
          } else if (messagesRes.data.prev_cursor !== undefined) {
            // No new messages, but update the prev cursor just in case
            store.dispatch(
              appendMessages({
                chatId: storeChatId,
                messages: [],
                prevCursor: messagesRes.data.prev_cursor ?? null,
              }),
            );
          }
        } catch (err) {
          console.error(`Failed to sync messages for ${storeChatId}`, err);
        }
      }
    } catch (err) {
      console.error('Failed to sync app state', err);
    } finally {
      isSyncing = false;
    }
  }, 500);
}
