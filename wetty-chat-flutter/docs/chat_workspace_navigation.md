# Chat Workspace Navigation

`ChatWorkspaceShell` wraps the chat branch and adapts the current `go_router`
route child between compact stack navigation and wide split-pane navigation.

## Main Pieces

- `ShellRoute` builds `ChatWorkspaceShell` and passes the matched nested route as
  `child`.
- `ChatWorkspaceShell` decides whether the workspace is compact or split based on
  width.
- `ChatWorkspaceLayoutScope` exposes that decision to descendants.
- `openChatListDetail` and `openArchivedChatList` choose navigation behavior from
  `ChatWorkspaceLayoutScope.isSplitLayout(context)`.
- `chatWorkspaceListScopeProvider` remembers whether the split list pane is
  showing active or archived chats.

## Route Child Examples

| Location | Shell `child` |
| --- | --- |
| `/` | `ChatListV2Page(scope: active)` |
| `/chat/:chatId` | `ChatDetailV2Page` |
| `/chat/:chatId/thread/:threadId` | `ThreadDetailV2Page` |
| `/chats/archived` | `ChatListV2Page(scope: archived)` |
| `/threads/archived` | `ChatListV2Page(scope: archived)` |
| `/thread/:chatId/:threadId` | `ThreadDetailV2Page` |

## Compact Flow

```mermaid
flowchart TD
  A["Location: /"] --> B["Shell child = ChatListV2Page"]
  B --> C["Tap chat row"]
  C --> D["openChatListDetail"]
  D --> E["isSplit = false"]
  E --> F["context.push('/chat/123')"]
  F --> G["Shell rebuilds with location /chat/123"]
  G --> H["Shell child = ChatDetailV2Page"]
  H --> I["Back pops route"]
  I --> A
```

On compact layouts, `ChatWorkspaceShell` is mostly a pass-through wrapper. The
visible page is the route child.

## Split Flow

```mermaid
flowchart TD
  A["Location: /"] --> B["Shell renders Row"]
  B --> C["Left pane = embedded ChatListV2Page"]
  B --> D["Right pane = empty detail pane"]
  C --> E["Tap chat row"]
  E --> F["openChatListDetail"]
  F --> G["isSplit = true"]
  G --> H["context.go('/chat/123')"]
  H --> I["Shell rebuilds with location /chat/123"]
  I --> J["Left pane = list"]
  I --> K["Right pane = ChatDetailV2Page"]
```

On split layouts, the shell owns the list pane and uses the route child as the
right detail pane unless the current route is a list root.

## Archived Chats

Archived navigation has two representations:

- Compact: `openArchivedChatList` pushes `/chats/archived`, so the archived list
  is a full page.
- Split: `openArchivedChatList` updates `chatWorkspaceListScopeProvider` to
  `ChatListV2Scope.archived`, so the left pane changes without pushing a route.

If a split layout is already at `/chats/archived` or `/threads/archived`,
`ChatWorkspaceShell` forces the left pane to archived and shows the empty detail
pane. This keeps direct links, refreshes, and resize transitions consistent.
