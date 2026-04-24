# Chat List V2 Cutover Blockers

This document tracks what still blocks deleting `lib/features/chats/list` now that
the visible chats tab is routed through `lib/features/chat_list_v2`.

## Current Routing

- `/chats` renders `ChatListV2Page`.
- The old `ChatPage` shell is not visibly routed.
- `/chats/new` still renders `NewChatPage` from the old list package.

## Accepted Feature Gaps

These are not deletion blockers unless product decides otherwise.

- Group rows in V2 do not expose the old swipe read/unread action.
- V2 group rows do not show composer draft previews.
- Thread rows in V2 do not launch with `LaunchRequest.unread`; they open latest.
- Thread read/unread swipe actions are visible but currently no-op.
- Group and all-tab error states have less complete retry UX than old list.

## Deletion Blockers

These are live dependencies on `features/chats/list` that must be moved or
replaced before removing the old package.

- `ChatApiService` is still used by V2 group loading, unread badge refresh, and
  shared read-state code.
- `ChatListSegment`, `ChatListRow`, and `SwipeToActionRow` are shared UI
  primitives but still live under the old list package.
- `NewChatPage` is still routed and creates chats through `chatListStateProvider`.
- `ws_event_router` still fans message events into `chatListStateProvider`.
- Group metadata updates, mute/unmute, and leave-group flows still mutate
  `chatListStateProvider`.
- V2 realtime miss recovery is stubbed; unknown group/thread events do not
  trigger a repository refresh.
- V2 thread read state is not reset locally when a thread is read from the
  conversation timeline.

## Removal Direction

1. Move shared API and UI primitives out of `features/chats/list`.
2. Make V2 stores own create, metadata, mute, leave-group, refresh, and realtime
   reconciliation paths.
3. Update app-level refresh and websocket fan-out to target V2 owners only.
4. Remove old presentation/view-model/repository files once no production import
   reaches `features/chats/list`.
