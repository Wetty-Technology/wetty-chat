# Conversation Timeline Use Case UML

## Purpose

This document captures concrete timeline use cases as sequence diagrams for the
`conversation_v2` rewrite.

It complements:

- [conversation_timeline_redesign_learnings.md](/Users/codetector/projects/wetty-chat/wetty-chat-flutter/docs/conversation/conversation_timeline_redesign_learnings.md:1)

The goal here is not to restate the architecture rules. It is to show how those
rules play out in specific user-visible flows.

## Shared Runtime Pieces

The diagrams use the same runtime pieces throughout:

- `TimelineView`
- `Composer`
- `TimelineVM`
- `ConversationRepository`
- `MessageDomainStore`
- `Backend API`
- `ws_event_router`

## Shared Rules

- `TimelineVM` issues commands to the repository.
- `Composer` issues send/edit intents to `TimelineVM`, not directly to the repository.
- `ConversationRepository` fetches or mutates through HTTP, then merges results
  into `MessageDomainStore`.
- `ws_event_router` applies websocket mutations into the same store.
- `TimelineVM` reacts to canonical store updates.
- `TimelineView` reports viewport facts up and applies viewport effects down.

For send confirmation specifically:

- the message is keyed by `clientGeneratedId` until or unless a `serverMessageId`
  is needed
- either the HTTP response or the websocket echo is enough to mark the send as
  accepted/confirmed by the server
- if both arrive, the store merges them idempotently by `clientGeneratedId`

For jump handling specifically:

- the VM first decides whether the target is already in the current slice
- if yes, the VM emits a reveal effect directly
- if not, the VM enters a resolving state, replaces or expands the slice, then
  emits the reveal effect after the correct slice is available
- highlight is metadata on the reveal target, not a separate navigation path

## 1. Open A Chat At Latest

```mermaid
sequenceDiagram
  actor User
  participant View as TimelineView
  participant VM as TimelineVM
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore

  User->>View: Open chat
  View->>VM: init(conversation identity, launch=latest)
  VM->>Repo: loadLatest()
  Repo->>API: fetch latest window
  API-->>Repo: latest messages
  Repo->>Store: merge latest messages + activate latest range
  Store-->>VM: scoped canonical update
  VM-->>View: state + ViewportEffect(bottom)
  View->>View: reveal live edge
```

## 2. Open A Chat At Unread (History)

```mermaid
sequenceDiagram
  actor User
  participant View as TimelineView
  participant VM as TimelineVM
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore

  User->>View: Open chat
  View->>VM: init(conversation identity, launch=unread(lastReadMessageId))
  VM->>VM: enter resolving-jump state
  VM->>Repo: resolve unread target
  Repo->>API: fetch first unread or around-target window
  API-->>Repo: target + surrounding messages
  Repo->>Store: merge messages + activate historical range
  Store-->>VM: scoped canonical update
  VM-->>View: state + ViewportEffect(target, alignment=top, highlight=true)
  View->>View: place unread target as high as possible
```

## 3. Jump To History From Latest

```mermaid
sequenceDiagram
  actor User
  participant View as TimelineView
  participant VM as TimelineVM
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore

  User->>View: Tap reply/thread/history target
  View->>VM: jumpToMessage(targetMessageId)
  alt target already covered by active window
    VM-->>View: ViewportEffect(target, alignment=top, highlight=true)
    View->>View: reveal target immediately
  else target not loaded
    VM->>VM: enter resolving-jump state
    VM->>Repo: loadAroundMessage(targetMessageId)
    Repo->>API: fetch around target
    API-->>Repo: surrounding messages
    Repo->>Store: merge messages + activate historical range
    Store-->>VM: scoped canonical update
    VM-->>View: ViewportEffect(target, alignment=top, highlight=true)
    View->>View: reveal target after data arrives
  end
```

## 4. Jump To History From History

```mermaid
sequenceDiagram
  actor User
  participant View as TimelineView
  participant VM as TimelineVM
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore

  User->>View: Tap another historical target
  View->>VM: jumpToMessage(targetMessageId)
  alt target already cached in current history window
    VM-->>View: ViewportEffect(target, alignment=top, highlight=true)
    View->>View: reveal target
  else target outside current history window
    VM->>VM: enter resolving-jump state
    VM->>Repo: loadAroundMessage(targetMessageId)
    Repo->>API: fetch around target
    API-->>Repo: surrounding messages
    Repo->>Store: merge messages + activate new historical range
    Store-->>VM: scoped canonical update
    VM-->>View: ViewportEffect(target, alignment=top, highlight=true)
    View->>View: reveal target
  end
```

## 5. Scroll To Load More (Older Or Newer)

```mermaid
sequenceDiagram
  actor User
  participant View as TimelineView
  participant VM as TimelineVM
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore

  User->>View: Scroll history
  View->>VM: ViewportSnapshot(anchorKey, anchorDy, visibleRows, thresholds)
  alt near older edge
    VM->>Repo: loadOlder(anchorStableKey)
    Repo->>API: fetch older page
    API-->>Repo: older messages
    Repo->>Store: merge older page + extend active range
    Store-->>VM: scoped canonical update
    VM-->>View: ViewportEffect(stableKey=anchorKey, restoreDy=anchorDy)
    View->>View: preserve anchor after prepend
  else near newer edge while browsing history
    VM->>Repo: loadNewer(anchorStableKey)
    Repo->>API: fetch newer page
    API-->>Repo: newer messages
    Repo->>Store: merge newer page + extend active range
    Store-->>VM: scoped canonical update
    VM-->>View: ViewportEffect(stableKey=anchorKey, restoreDy=anchorDy)
    View->>View: preserve anchor after append
  end
```

## 6. Sending A Message At Live Edge

```mermaid
sequenceDiagram
  actor User
  participant Composer
  participant VM as TimelineVM
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore
  participant View as TimelineView
  participant WS as ws_event_router

  User->>Composer: Send message
  Composer->>VM: sendMessage(draft)
  VM->>Repo: sendMessage(draft with clientGeneratedId)
  Repo->>Store: apply optimistic send
  Store-->>VM: scoped canonical update
  VM-->>View: state update
  Note over View: already at confirmed live edge, stay pinned

  par HTTP response path
    Repo->>API: POST send message
    API-->>Repo: accepted/confirmed message with serverMessageId
    Repo->>Store: merge confirmation by clientGeneratedId
    Store-->>VM: scoped canonical update
    VM-->>View: state update
  and WebSocket echo path
    API-->>WS: echo message event
    WS->>Store: merge echoed message by clientGeneratedId
    Store-->>VM: scoped canonical update
    VM-->>View: state update
  end

  Note over Store: Either path is sufficient to accept the send. If both arrive, merge idempotently.
```

## 7. Sending A Message While Browsing History

Assumption: existing product behavior is preserved, so sending from history
returns the user to live edge.

```mermaid
sequenceDiagram
  actor User
  participant Composer
  participant VM as TimelineVM
  participant View as TimelineView
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore
  participant WS as ws_event_router

  User->>Composer: Send message
  Composer->>VM: sendMessage(draft)
  VM->>VM: enter resolving-latest state
  VM->>Repo: sendMessage(draft with clientGeneratedId)
  Repo->>Store: apply optimistic send
  Store-->>VM: scoped canonical update
  VM-->>View: state update + ViewportEffect(bottom)
  View->>View: reveal live edge after latest slice is active

  par HTTP response path
    Repo->>API: POST send message
    API-->>Repo: accepted/confirmed message with serverMessageId
    Repo->>Store: merge confirmation by clientGeneratedId
    Store-->>VM: scoped canonical update
    VM-->>View: state update + optional settle-bottom effect
  and WebSocket echo path
    API-->>WS: echo message event
    WS->>Store: merge echoed message by clientGeneratedId
    Store-->>VM: scoped canonical update
    VM-->>View: state update + optional settle-bottom effect
  end
```

The repository call is the same in both send cases.
The difference is VM policy:

- when already at live edge, do not emit a bottom-reveal effect
- when browsing history and product behavior says "send returns to latest",
  switch toward the latest slice, then emit the bottom-reveal effect once the
  correct slice is active

## 8. User Receives A Message While Not At Live Edge

```mermaid
sequenceDiagram
  participant API as Backend API
  participant WS as ws_event_router
  participant Store as MessageDomainStore
  participant VM as TimelineVM
  participant View as TimelineView
  actor User

  API-->>WS: incoming message event
  WS->>Store: apply incoming message
  Store-->>VM: scoped canonical update
  VM->>VM: add stableKey to pending-live set
  VM-->>View: state update (pendingLiveCount > 0)
  Note over View: do not auto-scroll while user is browsing history
  User->>View: Tap jump-to-latest
  View->>VM: jumpToLatest()
  VM->>VM: resolve whether current slice is already latest
  alt latest slice already active
    VM-->>View: ViewportEffect(bottom)
  else latest slice not active
    VM->>VM: enter resolving-latest state
    VM->>Repo: loadLatest()
    Repo->>API: fetch latest window
    API-->>Repo: latest messages
    Repo->>Store: merge latest messages + activate latest range
    Store-->>VM: scoped canonical update
    VM-->>View: state update + ViewportEffect(bottom)
  end
```

## 9. User Receives A Message While At Live Edge

```mermaid
sequenceDiagram
  participant API as Backend API
  participant WS as ws_event_router
  participant Store as MessageDomainStore
  participant VM as TimelineVM
  participant View as TimelineView

  API-->>WS: incoming message event
  WS->>Store: apply incoming message
  Store-->>VM: scoped canonical update
  VM->>VM: detect confirmed live edge
  VM-->>View: state update
  View->>View: keep timeline pinned to bottom
```

## 10. User Edits A Message

```mermaid
sequenceDiagram
  actor User
  participant View as TimelineView
  participant Repo as ConversationRepository
  participant API as Backend API
  participant Store as MessageDomainStore
  participant VM as TimelineVM
  participant WS as ws_event_router

  User->>View: Edit message
  View->>Repo: editMessage(serverMessageId, newBody)
  Repo->>Store: apply optimistic edit
  Store-->>VM: scoped canonical update
  VM-->>View: state update

  par HTTP response path
    Repo->>API: PATCH edit
    API-->>Repo: accepted/confirmed edited message
    Repo->>Store: merge confirmed edit
    Store-->>VM: scoped canonical update
    VM-->>View: state update
  and WebSocket echo path
    API-->>WS: edited message event
    WS->>Store: merge edited message event
    Store-->>VM: scoped canonical update
    VM-->>View: state update
  end

  Note over Store: HTTP and websocket edit confirmations must merge idempotently.
```
