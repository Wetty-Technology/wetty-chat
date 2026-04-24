# Chat List V2 Cutover Blockers

This document tracks accepted V2 feature gaps after deleting
`lib/features/chats/list`.

## Current Routing

- `/chats` renders `ChatListV2Page`.
- The old `ChatPage` shell and `lib/features/chats/list` package were removed.

## Accepted Feature Gaps

These are not deletion blockers unless product decides otherwise.

- Group rows in V2 do not expose the old swipe read/unread action.
- V2 group rows do not show composer draft previews.
- Thread rows in V2 do not launch with `LaunchRequest.unread`; they open latest.
- Thread read/unread swipe actions are visible but currently no-op.
- Group and all-tab error states have less complete retry UX than old list.

## Follow-Up Correctness Work

- V2 thread read state is not reset locally when a thread is read from the
  conversation timeline.
