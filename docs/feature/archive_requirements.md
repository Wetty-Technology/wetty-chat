# Archive Feature Requirements

## Summary

Add a first-class archive feature for chats and threads.

Archive is an inbox-management state, not a delete/leave state and not just a notification setting. Archiving moves a conversation out of the default inbox into an `Archived` bucket, mutes it indefinitely while archived, excludes its unread count from the main inbox unread counts, and keeps it archived even when new activity arrives.

This feature must behave consistently across chats and threads so the user experiences archive as one concept in `Chats`, `Threads`, and `All`.

## Product Goals

- Let users reduce inbox noise without leaving chats or unsubscribing from threads.
- Keep archived items accessible in a dedicated `Archived` view.
- Make archive behavior predictable:
  - archive does not auto-reverse on new activity
  - archive suppresses notifications
  - archive is reversible by explicit user action

## Non-Goals

- Search across archived items
- Bulk archive/unarchive
- Archive controls inside chat settings or thread detail as a primary entrypoint in v1
- Preserving the user’s pre-archive mute state
- Auto-unarchiving based on mentions or new messages

## Core Semantics

- `archive` is a first-class state separate from `mute`.
- Archiving a chat or thread sets it to muted indefinitely.
- Archived items remain archived when new messages, replies, or mentions arrive.
- Opening an archived item does not unarchive it.
- Unarchiving returns the item to the active inbox and makes it unmuted.
- If the user attempts to unmute an archived conversation, the app must warn that unmuting will move it out of archive.

## UX Requirements

### Main Inbox

The inbox has three top-level views:

- `All`
- `Groups`
- `Threads`

Archive should integrate into each view as follows:

- `Groups`:
  - show an `Archived` row as the first row only if archived chats exist
  - row badge shows archived unread chat count only
  - active chat list excludes archived chats
- `Threads`:
  - show an `Archived` row as the first row only if archived threads exist
  - row badge shows archived unread thread count only
  - active thread list excludes archived threads
- `All`:
  - show one `Archived` row as the first row if archived chats or archived threads exist
  - row badge shows combined archived unread count across chats and threads
  - active combined list excludes archived chats and archived threads

### Archived View

- Tapping the `Archived` row opens an `Archived` screen.
- The `Archived` screen uses the same segmented model as the inbox:
  - `All`
  - `Groups`
  - `Threads`
- The `Archived` screen uses minimal chrome:
  - title: `Archived`
  - no extra explanatory copy in v1
- Sorting matches the active inbox:
  - chats sorted by latest chat activity
  - threads sorted by latest thread reply activity
  - archived `All` is interleaved by latest activity timestamp

### Entry Points

V1 archive entrypoints:

- chats: swipe action from the chat list
- threads: swipe action from the thread list

V1 unarchive entrypoints:

- swipe action from archived chat/thread lists
- implicit unarchive when the user confirms an unmute action on an archived item

### Unmute Confirmation

If a user attempts to unmute an archived conversation:

- show confirmation dialog
- message should explain that unmuting will move the conversation back to the active inbox
- confirm action performs:
  - unarchive
  - unmute
- cancel action leaves the conversation archived and muted indefinitely

Suggested copy:

- chats: `Unmuting will move this chat back to Chats. Continue?`
- threads: `Unmuting will move this thread back to Threads. Continue?`

## State and Counting Rules

### Active vs Archived

Chats and threads each need explicit active vs archived state.

The system must maintain:

- active chats
- archived chats
- active threads
- archived threads

### Unread Counts

Unread counts must be split between active and archived.

Rules:

- active inbox unread counts exclude archived items
- archived unread counts are shown only on the `Archived` row
- `All` active unread count = active chats unread + active threads unread
- `All` archived unread count = archived chats unread + archived threads unread

### Activity Behavior

New activity in archived chats/threads:

- updates their preview and sort order inside Archived
- does not move them back into active inbox
- does not contribute to active unread badges
- does not trigger notifications

## Notification Rules

Archived items are notification-suppressed.

Required behavior:

- archiving sets notification state to muted indefinitely
- local notification generation must skip archived items
- push notification generation or delivery logic must treat archived items as muted
- mentions do not override archive

## API and Data Requirements

Archive must be represented explicitly in chat and thread models.

### Chat Requirements

Chat list/read models must expose:

- `archived: boolean`
- `mutedUntil: string | null`

Required chat operations:

- archive chat
- unarchive chat
- fetch active chats
- fetch archived chats
- fetch active unread count
- fetch archived unread count, or a combined count shape that returns both active and archived counts

### Thread Requirements

Thread list/read models must expose:

- `archived: boolean`

Required thread operations:

- archive thread
- unarchive thread
- fetch active threads
- fetch archived threads
- fetch active unread count
- fetch archived unread count, or a combined count shape that returns both active and archived counts

## Frontend Requirements

Frontend must:

- store archive state for chats and threads
- render active and archived lists separately
- render an `Archived` row conditionally per segment
- support swipe `Archive` and `Unarchive`
- support archived unread badges
- merge chats and threads correctly for `All`
- keep archive behavior consistent on mobile and desktop layouts within the PWA

## Backend Requirements

Backend must:

- persist archive state for chats and thread subscriptions
- enforce archive + mute semantics
- return archive state in list payloads
- expose counts needed by the inbox UI
- keep websocket/live-update behavior consistent with archive state
- prevent archived items from contributing to notification delivery

## Acceptance Criteria

- A user can archive a chat from the chat list.
- A user can archive a thread from the thread list.
- Archived items disappear from active inbox views immediately after archiving.
- Archived items appear in the Archived view.
- Archived items stay archived after new messages or mentions.
- Archived unread counts are not included in active unread badges.
- Archived unread counts appear on the `Archived` row.
- A user can unarchive via swipe in archived lists.
- A user who tries to unmute an archived item gets a confirmation dialog.
- Confirming the dialog unarchives and unmutes the item.
- Canceling the dialog leaves the item archived and muted.

## Defaults Chosen for V1

- Swipe-only archive entrypoint
- Minimal archived screen chrome
- Same segmented structure in active and archived inboxes
- No search
- No bulk actions
- No restore of previous mute state
- No auto-unarchive on activity or mentions
