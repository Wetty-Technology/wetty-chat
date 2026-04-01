import { useCallback, useRef, useState } from 'react';
import { getMembers, type MemberResponse } from '@/api/group';

export interface MentionEntry {
  uid: number;
  username: string;
  /** Start index of "@username" in the textarea text */
  start: number;
  /** End index (exclusive) of "@username" in the textarea text */
  end: number;
}

export interface MentionState {
  isOpen: boolean;
  results: MemberResponse[];
  selectedIndex: number;
  loading: boolean;
  query: string;
}

interface UseMentionAutocompleteResult {
  mentionState: MentionState;
  mentionEntries: MentionEntry[];
  selectMention: (member: MemberResponse) => void;
  handleKeyDown: (event: KeyboardEvent) => boolean;
  /** Convert display text to wire format before sending */
  toWireFormat: (text: string) => string;
  /** Clear all mention entries (call after send) */
  clearMentions: () => void;
  /** Notify the hook of cursor/text changes */
  onTextChange: (newText: string) => void;
}

/**
 * Detects an `@` trigger: scans backwards from the cursor to find `@`
 * preceded by whitespace or at position 0. Returns the query string after `@`,
 * or null if no trigger is active.
 */
function detectMentionTrigger(text: string, cursorPos: number): { query: string; triggerStart: number } | null {
  if (cursorPos <= 0) return null;

  // Walk backwards from cursor to find `@`
  let i = cursorPos - 1;
  while (i >= 0) {
    const ch = text[i];
    // Stop on whitespace or newline — no `@` found in this "word"
    if (ch === ' ' || ch === '\n' || ch === '\r' || ch === '\t') return null;
    if (ch === '@') {
      // `@` must be at start of text or preceded by whitespace/newline
      if (i === 0 || /\s/.test(text[i - 1])) {
        return { query: text.slice(i + 1, cursorPos), triggerStart: i };
      }
      return null;
    }
    i--;
  }
  return null;
}

export function useMentionAutocomplete(
  textareaRef: React.RefObject<HTMLTextAreaElement | null>,
  text: string,
  chatId: string | number | undefined,
): UseMentionAutocompleteResult {
  const [mentionState, setMentionState] = useState<MentionState>({
    isOpen: false,
    results: [],
    selectedIndex: 0,
    loading: false,
    query: '',
  });
  const [mentionEntries, setMentionEntries] = useState<MentionEntry[]>([]);
  const triggerStartRef = useRef<number | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const abortRef = useRef<AbortController | null>(null);
  const latestQueryRef = useRef('');

  const closeMention = useCallback(() => {
    setMentionState((prev) => (prev.isOpen ? { ...prev, isOpen: false, results: [], selectedIndex: 0 } : prev));
    triggerStartRef.current = null;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (abortRef.current) abortRef.current.abort();
  }, []);

  const fetchMembers = useCallback(
    (query: string) => {
      if (!chatId) return;
      latestQueryRef.current = query;
      if (abortRef.current) abortRef.current.abort();
      const controller = new AbortController();
      abortRef.current = controller;

      setMentionState((prev) => ({ ...prev, loading: true }));

      getMembers(chatId, { q: query || undefined, mode: 'autocomplete', limit: 8 })
        .then((res) => {
          if (controller.signal.aborted) return;
          setMentionState((prev) => ({
            ...prev,
            results: res.data.members,
            loading: false,
            selectedIndex: 0,
          }));
        })
        .catch(() => {
          if (controller.signal.aborted) return;
          setMentionState((prev) => ({ ...prev, loading: false }));
        });
    },
    [chatId],
  );

  const onTextChange = useCallback(
    (newText: string) => {
      // Invalidate mention entries if user edited inside a mention
      setMentionEntries((prev) => {
        if (prev.length === 0) return prev;
        const filtered = prev.filter((entry) => {
          const slice = newText.slice(entry.start, entry.end);
          return slice === `@${entry.username}`;
        });
        return filtered.length === prev.length ? prev : filtered;
      });

      const ta = textareaRef.current;
      if (!ta) {
        closeMention();
        return;
      }

      // Use a microtask to read selectionStart after React has flushed the value
      queueMicrotask(() => {
        const cursorPos = ta.selectionStart;
        const trigger = detectMentionTrigger(newText, cursorPos);
        if (!trigger) {
          closeMention();
          return;
        }

        triggerStartRef.current = trigger.triggerStart;
        setMentionState((prev) => ({
          ...prev,
          isOpen: true,
          query: trigger.query,
        }));

        if (debounceRef.current) clearTimeout(debounceRef.current);
        debounceRef.current = setTimeout(() => fetchMembers(trigger.query), 250);
      });
    },
    [closeMention, fetchMembers, textareaRef],
  );

  const selectMention = useCallback(
    (member: MemberResponse) => {
      const ta = textareaRef.current;
      if (!ta || triggerStartRef.current == null) return;

      const displayText = `@${member.username ?? `User ${member.uid}`}`;
      const triggerStart = triggerStartRef.current;
      const cursorPos = ta.selectionStart;

      // Replace @query with @username (+ trailing space)
      const before = text.slice(0, triggerStart);
      const after = text.slice(cursorPos);
      const inserted = displayText + ' ';
      const newText = before + inserted + after;

      // Synthetic input event to update React state
      const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
        window.HTMLTextAreaElement.prototype,
        'value',
      )?.set;
      if (nativeInputValueSetter) {
        nativeInputValueSetter.call(ta, newText);
        ta.dispatchEvent(new Event('input', { bubbles: true }));
      }

      const newCursorPos = triggerStart + inserted.length;
      requestAnimationFrame(() => {
        ta.setSelectionRange(newCursorPos, newCursorPos);
        ta.focus();
      });

      if (member.username) {
        setMentionEntries((prev) => [
          ...prev,
          {
            uid: member.uid,
            username: member.username!,
            start: triggerStart,
            end: triggerStart + displayText.length,
          },
        ]);
      }

      closeMention();
    },
    [closeMention, text, textareaRef],
  );

  const handleKeyDown = useCallback(
    (event: KeyboardEvent) => {
      if (!mentionState.isOpen) return false;

      const totalItems = mentionState.results.length;
      if (totalItems === 0) {
        if (event.key === 'Escape') {
          event.preventDefault();
          closeMention();
          return true;
        }
        return false;
      }

      if (event.key === 'ArrowDown') {
        event.preventDefault();
        setMentionState((prev) => ({
          ...prev,
          selectedIndex: Math.min(prev.selectedIndex + 1, totalItems - 1),
        }));
        return true;
      }

      if (event.key === 'ArrowUp') {
        event.preventDefault();
        setMentionState((prev) => ({
          ...prev,
          selectedIndex: Math.max(prev.selectedIndex - 1, 0),
        }));
        return true;
      }

      if (event.key === 'Enter') {
        event.preventDefault();
        const member = mentionState.results[mentionState.selectedIndex];
        if (member) selectMention(member);
        return true;
      }

      if (event.key === 'Escape') {
        event.preventDefault();
        closeMention();
        return true;
      }

      return false;
    },
    [closeMention, mentionState.isOpen, mentionState.results, mentionState.selectedIndex, selectMention],
  );

  const toWireFormat = useCallback(
    (displayText: string): string => {
      if (mentionEntries.length === 0) return displayText;

      let result = displayText;

      // Sort entries by start position descending so replacements don't shift offsets
      const sorted = [...mentionEntries].sort((a, b) => b.start - a.start);
      for (const entry of sorted) {
        const displayMention = `@${entry.username}`;
        const slice = result.slice(entry.start, entry.end);
        if (slice === displayMention) {
          result = result.slice(0, entry.start) + `@[uid:${entry.uid}]` + result.slice(entry.end);
        }
      }
      return result;
    },
    [mentionEntries],
  );

  const clearMentions = useCallback(() => {
    setMentionEntries([]);
    closeMention();
  }, [closeMention]);

  return {
    mentionState,
    mentionEntries,
    selectMention,
    handleKeyDown,
    toWireFormat,
    clearMentions,
    onTextChange,
  };
}
