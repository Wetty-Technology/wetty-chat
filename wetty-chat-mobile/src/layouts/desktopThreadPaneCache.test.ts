import { describe, expect, it } from 'vitest';
import { areCachedThreadPanesEqual, createCachedThreadPane, updateCachedThreadPanes } from './desktopThreadPaneCache';

describe('desktop thread pane cache', () => {
  it('adds the active thread pane', () => {
    const pane = createCachedThreadPane('chat-1', 'thread-1');

    expect(updateCachedThreadPanes([], pane, 5)).toEqual([pane]);
  });

  it('appends a new active pane without moving existing panes', () => {
    const paneA = createCachedThreadPane('chat-1', 'thread-1');
    const paneB = createCachedThreadPane('chat-1', 'thread-2');

    expect(updateCachedThreadPanes([paneA], paneB, 5)).toEqual([paneA, paneB]);
  });

  it('keeps a reopened pane in place', () => {
    const paneA = createCachedThreadPane('chat-1', 'thread-1');
    const paneB = createCachedThreadPane('chat-1', 'thread-2');

    expect(updateCachedThreadPanes([paneB, paneA], paneA, 5)).toEqual([paneB, paneA]);
  });

  it('trims oldest inactive panes', () => {
    const paneA = createCachedThreadPane('chat-1', 'thread-1');
    const paneB = createCachedThreadPane('chat-1', 'thread-2');
    const paneC = createCachedThreadPane('chat-1', 'thread-3');

    expect(updateCachedThreadPanes([paneA, paneB], paneC, 2)).toEqual([paneB, paneC]);
  });

  it('keeps cached panes when no thread is active', () => {
    const paneA = createCachedThreadPane('chat-1', 'thread-1');

    expect(updateCachedThreadPanes([paneA], null, 5)).toEqual([paneA]);
  });

  it('compares cached panes by values', () => {
    const paneA = createCachedThreadPane('chat-1', 'thread-1');
    const samePaneA = createCachedThreadPane('chat-1', 'thread-1');

    expect(areCachedThreadPanesEqual([paneA], [samePaneA])).toBe(true);
  });
});
