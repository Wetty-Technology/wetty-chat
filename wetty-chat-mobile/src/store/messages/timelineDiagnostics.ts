import type { MessageResponse } from '@/api/messages';
import {
  selectActiveTimelineMessages,
  selectCanLoadNewer,
  selectPendingLiveCount,
  selectTimelineMode,
} from './selectors';
import type { MessagesState } from './types';

const TIMELINE_DIAGNOSTICS_STORAGE_KEY = 'wetty:timeline-diagnostics';
const MAX_TIMELINE_DIAGNOSTIC_ENTRIES = 200;

interface TimelineDiagnosticEntry {
  event: string;
  timestamp: string;
  details: Record<string, unknown>;
}

interface MessageStateRoot {
  messages: MessagesState;
}

function summarizeMessageRange(messages: MessageResponse[]) {
  return {
    firstId: messages[0]?.id ?? null,
    lastId: messages[messages.length - 1]?.id ?? null,
    count: messages.length,
  };
}

export function collectTimelineSnapshot(state: MessageStateRoot, storeChatId: string) {
  const chat = state.messages.chats[storeChatId];
  const activeMessages = selectActiveTimelineMessages(state, storeChatId);

  return {
    mode: selectTimelineMode(state, storeChatId),
    segmentCount: chat?.segments.length ?? 0,
    segments:
      chat?.segments.map((segment) => ({
        ...summarizeMessageRange(segment.messages),
        nextCursor: segment.nextCursor,
        prevCursor: segment.prevCursor,
      })) ?? [],
    activeMessageCount: activeMessages.length,
    activeFirstId: activeMessages[0]?.id ?? null,
    activeLastId: activeMessages[activeMessages.length - 1]?.id ?? null,
    hasReachedLatest: chat?.hasReachedLatest ?? false,
    hasReachedOldest: chat?.hasReachedOldest ?? false,
    canLoadNewer: selectCanLoadNewer(state, storeChatId),
    pendingLiveCount: selectPendingLiveCount(state, storeChatId),
  };
}

function appendTimelineDiagnostic(entry: TimelineDiagnosticEntry) {
  if (typeof localStorage === 'undefined') return;

  try {
    const raw = localStorage.getItem(TIMELINE_DIAGNOSTICS_STORAGE_KEY);
    const current = raw ? JSON.parse(raw) : [];
    const entries = Array.isArray(current) ? current : [];
    entries.push(entry);
    localStorage.setItem(
      TIMELINE_DIAGNOSTICS_STORAGE_KEY,
      JSON.stringify(entries.slice(-MAX_TIMELINE_DIAGNOSTIC_ENTRIES)),
    );
  } catch {
    // Diagnostics must never affect chat rendering or realtime handling.
  }
}

export function logTimelineDiagnostic(event: string, details: Record<string, unknown>) {
  const entry = {
    event,
    timestamp: new Date().toISOString(),
    details,
  };

  console.debug('[timeline-diagnostics]', entry);
  appendTimelineDiagnostic(entry);
}
