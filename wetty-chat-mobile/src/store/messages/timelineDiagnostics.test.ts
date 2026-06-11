import { describe, expect, it } from 'vitest';
import reducer, { applyRealtimeMessage, insertAround } from './slice';
import { collectTimelineSnapshot } from './timelineDiagnostics';
import { testMessage, testRootState } from './testUtils';

describe('timeline diagnostics', () => {
  it('summarizes active timeline state without message content', () => {
    let next = reducer(
      undefined,
      insertAround({
        chatId: '1',
        targetMessageId: '10',
        messages: [testMessage('10'), testMessage('11')],
        nextCursor: 'older-cursor',
        prevCursor: null,
      }),
    );
    next = reducer(next, applyRealtimeMessage({ chatId: '1', message: testMessage('12') }));

    expect(collectTimelineSnapshot(testRootState(next), '1')).toEqual({
      mode: { type: 'around', targetMessageId: '10' },
      segmentCount: 1,
      segments: [
        {
          firstId: '10',
          lastId: '12',
          count: 3,
          nextCursor: 'older-cursor',
          prevCursor: null,
        },
      ],
      activeMessageCount: 3,
      activeFirstId: '10',
      activeLastId: '12',
      hasReachedLatest: true,
      hasReachedOldest: false,
      canLoadNewer: false,
      pendingLiveCount: 0,
    });
  });
});
