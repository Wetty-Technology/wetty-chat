# Conversation V2 Missing Features

## Purpose

This document records the remaining user-facing behavior that still exists in
`features/chats/conversation/` or is still missing from
`features/chats/conversation_v2/`.

It is meant to stay useful even after the original `conversation` folder is
deleted. For each gap, this doc captures:

- what behavior is still missing
- where the current V2 code lives
- where the old V1 implementation lived
- where the replacement should probably land
- how to recover the old implementation from git history later

This is intentionally a cutover document, not a redesign doc. The question here
is not whether V2 is architecturally better. The question is what still blocks
deleting V1 without losing behavior.

## Current Status

The router is already V2-first:

- chat routes use `ChatDetailV2Page`
- thread routes use `ThreadDetailV2Page`
- the attachment viewer route already points at the V2-owned viewer

Relevant files:

- `lib/app/routing/app_router.dart`
- `lib/features/chats/conversation_v2/presentation/chat_detail_v2_view.dart`
- `lib/features/chats/conversation_v2/presentation/thread_detail_v2_view.dart`
- `lib/features/chats/conversation_v2/presentation/attachment_viewer_page.dart`

V2 already has several pieces that earlier audits called out as missing:

- sticker picker hosting via `ConversationComposeV2`
- swipe-to-reply via `ReplySwipeActionV2`
- long-press overlay via `MessageOverlayV2`
- thread-open wiring from message rows
- dedicated voice-message rendering via `VoiceMessageBubbleV2`

So the remaining cutover work is narrower than "build all of conversation
again". The remaining work is mostly:

- missing interaction plumbing
- missing page-shell behavior
- lingering shared dependencies on `features/chats/conversation/`

## Feature Gaps

### 1. Unread launch is still a stub

Status:

- V2 accepts `UnreadLaunchRequest`.
- The view model still does not implement the behavior.

Current V2 code:

- `lib/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart`
  - `initialize(...)`
  - `jumpToUnread(int lastReadMessageId)`

Current behavior:

- `UnreadLaunchRequest` reaches `jumpToUnread(...)`
- `jumpToUnread(...)` only calls `_markRepositoryTodo(...)`
- no actual range resolution, anchor selection, or viewport effect happens

Why this matters:

- unread entry was one of the most fragile timeline behaviors in V1
- deleting V1 before V2 implements this means notification/open-from-list flows
  will regress to latest-or-wrong-position behavior

Likely landing zone:

- repository logic in
  `conversation_timeline_v2_repository.dart`
- state/effect selection in
  `conversation_timeline_v2_view_model.dart`
- no widget-only workaround

What to recover from V1 / history:

- V1 implementation behavior lived in the old timeline VM and associated unread
  launch handling
- related history is already called out in
  `docs/conversation/conversation_timeline_redesign_learnings.md`
- especially useful commit from prior timeline history:
  - `18919c5` `Handle unread chat launch intent in conversation view`

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/application/conversation_timeline_view_model.dart
git show 18919c5
git grep -n "jumpToUnread\\|UnreadLaunchRequest"
```

### 2. Attachment taps are still non-functional in V2 rows

Status:

- V2 can render image, video, file, and audio attachments.
- Image and video previews do not open anything when tapped.
- Generic file attachments have no open behavior.

Current V2 code:

- `lib/features/chats/conversation_v2/presentation/message_bubble/message_bubble_content_v2.dart`

Current behavior:

- image preview uses `onTap: () {}`
- video preview uses `onTap: () {}`
- file tile is rendered as static UI only

V1 reference:

- `lib/features/chats/conversation/presentation/message_row.dart`
- `lib/features/chats/conversation/presentation/message_bubble/message_bubble_content.dart`

V1 behavior to preserve:

- images/videos open the fullscreen attachment viewer
- non-media attachments open externally
- the request builder handles multi-attachment viewer context correctly

Good news:

- the attachment viewer itself is already rehomed into V2
- `buildAttachmentViewerRequest(...)` is already V2-owned

Likely landing zone:

- interaction wiring should probably live in V2 row/surface code, not inside the
  low-level bubble content alone
- likely implementation path:
  - surface or timeline passes an `onOpenAttachment` callback
  - row resolves viewer vs external-open
  - bubble content just emits tap events

Why this matters:

- deleting V1 currently removes the only working attachment-open path

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/presentation/message_row.dart
git log --follow -- lib/features/chats/conversation/presentation/message_bubble/message_bubble_content.dart
git grep -n "attachmentViewer\\|launchUrl\\|buildAttachmentViewerRequest"
```

### 3. Sticker preview tap is missing in V2

Status:

- V2 can send and render sticker messages.
- V2 does not open the sticker preview modal when a sticker row is tapped.

Current V2 code:

- `lib/features/chats/conversation_v2/presentation/message_bubble/sticker_message_bubble_v2.dart`

Current behavior:

- the sticker is rendered directly with `StickerImage`
- there is no tap wrapper for preview behavior

V1 reference:

- `lib/features/chats/conversation/presentation/conversation_surface.dart`
- `lib/features/chats/conversation/presentation/message_bubble/sticker_message_bubble.dart`

V1 behavior to preserve:

- tapping the sticker opens `showStickerPreviewModal(...)`

Likely landing zone:

- same ownership pattern as V1 is still reasonable:
  - row/bubble emits sticker tap
  - surface decides to show the modal

Why this matters:

- this is not a data-layer blocker, but it is a visible interaction regression

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/presentation/conversation_surface.dart
git log --follow -- lib/features/chats/conversation/presentation/message_bubble/sticker_message_bubble.dart
git grep -n "showStickerPreviewModal\\|onTapSticker"
```

### 4. Mention taps are parsed but not wired through the V2 surface

Status:

- V2 text rendering supports mention token parsing and mention tap callbacks.
- The callback is not actually threaded through the V2 row/bubble/surface API.

Current V2 code:

- mention rendering support:
  - `lib/features/chats/conversation_v2/presentation/message_bubble/linkified_message_text.dart`
- callback is absent from:
  - `message_bubble_v2.dart`
  - `message_row_v2.dart`
  - `conversation_timeline_v2.dart`
  - `conversation_surface_v2.dart`
  - chat/thread V2 page shells

V1 reference:

- `lib/features/chats/conversation/presentation/chat_detail_view.dart`
- `lib/features/chats/conversation/presentation/thread_detail_view.dart`
- `lib/features/chats/conversation/presentation/message_row.dart`
- `lib/features/chats/conversation/presentation/message_bubble/message_bubble.dart`

V1 behavior to preserve:

- the tap path existed all the way up to the page shell
- the final action was still a TODO log, but the plumbing existed

Why this matters:

- once V1 is deleted, the remaining TODO at the page shell becomes harder to
  finish if the callback path itself is also gone

Likely landing zone:

- add `onTapMention` support all the way through:
  - `ConversationSurfaceV2`
  - `ConversationTimelineV2`
  - `MessageRowV2`
  - `MessageBubbleV2`
  - `MessageBubbleContentV2`
  - page shell entry points

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/presentation/message_row.dart
git log --follow -- lib/features/chats/conversation/presentation/message_bubble/message_bubble.dart
git grep -n "onTapMention"
```

### 5. Chat page shell parity is still incomplete

Status:

- `ChatDetailV2Page` is a thin shell around `ConversationSurfaceV2`.
- Several V1 shell responsibilities have not been ported.

Current V2 code:

- `lib/features/chats/conversation_v2/presentation/chat_detail_v2_view.dart`

V1 reference:

- `lib/features/chats/conversation/presentation/chat_detail_view.dart`

Missing or not yet ported:

- lifecycle hooks for resume refresh and best-effort read flush
- explicit back-pop behavior that returns a refresh result
- chat members button
- chat settings button
- shell-owned mention tap callback path

Already present in V2:

- title resolution from list metadata
- thread open navigation

Why this matters:

- this is where several correctness behaviors used to live
- deleting V1 without porting these means the timeline itself may work, but page
  lifecycle correctness and surrounding navigation affordances regress

Likely landing zone:

- `chat_detail_v2_view.dart`
- potentially a shared page-shell helper if chat and thread need parallel
  lifecycle handling

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/presentation/chat_detail_view.dart
git grep -n "refreshOnResume\\|flushReadStatus\\|chatMembers\\|chatSettings"
```

### 6. Thread page shell parity is still incomplete

Status:

- `ThreadDetailV2Page` is still a placeholder shell.

Current V2 code:

- `lib/features/chats/conversation_v2/presentation/thread_detail_v2_view.dart`

V1 reference:

- `lib/features/chats/conversation/presentation/thread_detail_view.dart`

Missing or not yet ported:

- dynamic subtitle showing parent chat name
- lifecycle refresh and read flush behavior
- thread-specific mark-as-read debounce using latest visible message
- subscription bell button
- shell-owned mention tap callback path

Why this matters:

- thread detail correctness was not just "render a conversation in thread scope"
- V1 thread page had thread-specific read semantics and subscription UI

Likely landing zone:

- `thread_detail_v2_view.dart`
- `ConversationSurfaceV2` callback support for latest visible message may be
  needed if thread mark-as-read stays page-owned

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/presentation/thread_detail_view.dart
git grep -n "markThreadAsRead\\|threadSubscriptionProvider\\|onLatestVisibleMessageChanged"
```

### 7. V2 overlay is simpler than the V1 overlay preview

Status:

- V2 has a working long-press overlay.
- It is not yet feature-equivalent to the richer V1 overlay presentation.

Current V2 code:

- `lib/features/chats/conversation_v2/presentation/message_overlay_v2.dart`

V1 reference:

- `lib/features/chats/conversation/presentation/message_overlay.dart`

Current difference:

- V2 shows reaction pills and an action panel
- V1 also rendered a richer preview/bubble snapshot layout around the selected
  message

Priority:

- lower than unread launch or attachment open
- still worth keeping documented because it becomes much harder to visually match
  later if the V1 file is gone and nobody remembers what the old overlay felt
  like

Likely landing zone:

- `message_overlay_v2.dart`
- possibly a shared overlay preview widget if we want to avoid timeline coupling

Recovery hints:

```bash
git log --follow -- lib/features/chats/conversation/presentation/message_overlay.dart
git diff -- lib/features/chats/conversation/presentation/message_overlay.dart lib/features/chats/conversation_v2/presentation/message_overlay_v2.dart
```

## Non-Feature Deletion Blockers

These are not user-facing gaps, but they still block deleting
`features/chats/conversation/`.

### Shared message domain still depends on V1 types

Current imports:

- `lib/features/chats/models/message_api_mapper.dart`
- `lib/features/chats/message_domain/domain/message_domain_models.dart`
- `lib/features/chats/message_domain/domain/message_domain_store.dart`

Problem:

- shared message infrastructure still imports `ConversationMessage` and
  `ConversationScope` from V1-owned paths

Needed direction:

- either move these types to a shared neutral package
- or replace the shared layer with V2-owned equivalents

### Chat list read-state transport still uses V1 `message_api_service.dart`

Current file:

- `lib/features/chats/list/data/chat_repository.dart`

Problem:

- swipe mark-read and related flows still depend on V1 service location

Needed direction:

- rehome service or create a shared read-state service independent from V1

### Cache settings still invalidate V1 voice providers

Current file:

- `lib/features/settings/presentation/cache_settings_view.dart`

Problem:

- settings still imports:
  - `voice_message_presentation_provider.dart`
  - `voice_message_playback_controller.dart`
  - `audio_duration_probe_service.dart`

Needed direction:

- either migrate the remaining service/provider ownership to V2/shared
- or switch cache settings to invalidate the V2 providers only

### V2 voice code still imports old audio services

Current files:

- `lib/features/chats/conversation_v2/application/voice_message_playback_controller_v2.dart`
- `lib/features/chats/conversation_v2/application/voice_message_presentation_provider_v2.dart`

Problem:

- V2 still depends on:
  - `conversation/data/audio_playback_driver.dart`
  - `conversation/data/audio_duration_probe_service.dart`

Needed direction:

- move these to `conversation_v2/data` or a shared audio module

### Tests still import V1 symbols

Current files:

- `test/features/chats/message_domain/domain/message_domain_store_test.dart`
- `test/core/network/ws_event_router_test.dart`

Problem:

- the message domain store test uses V1 `ConversationMessage` and
  `ConversationScope` as fixtures
- the ws event router test asserts dispatch through the V1-owned
  `conversationRealtimeRegistryProvider`

Needed direction:

- migrate both tests onto V2-owned (or shared neutral) equivalents before
  deleting the V1 folder, otherwise the test suite fails to compile

### Realtime dispatch may still route through the V1 registry

Current symbol:

- `conversationRealtimeRegistryProvider` lives under
  `lib/features/chats/conversation/`

Problem:

- `wsEventRouter` test coverage implies realtime events are dispatched through
  the V1 registry
- if the live app is still wired the same way, deleting V1 silently breaks
  realtime event delivery — not just compilation

Needed direction:

- confirm whether the production router wires to a V1 or V2 registry
- if V1, rehome the registry to `conversation_v2/` (or a shared neutral
  location) and repoint the router before deletion
- treat this as a correctness blocker, not just a compile-time blocker

### Audio services are tangled in both directions

In addition to V2 voice code importing old audio services (noted above), the
reverse is also true — V1 code now imports V2 audio services:

- `lib/features/chats/conversation/application/conversation_composer_view_model.dart`
  imports V2 `audio_recorder_service` and `audio_waveform_cache_service`
- `lib/features/chats/conversation/application/voice_message_playback_controller.dart`
  imports V2 `audio_source_resolver_service`
- `lib/features/chats/conversation/presentation/message_bubble/voice_message_bubble.dart`
  imports V2 `audio_waveform_cache_service`

Why this matters:

- rehoming audio is not a one-way move of V1 → V2; services are split across
  both folders with imports going both ways
- a naive move will leave dangling imports on whichever side is touched second
- cache settings invalidation is wrong partly because there is no single
  canonical owner today

Needed direction:

- pick one canonical audio owner (V2 or a shared `audio/` module)
- move all audio services there in one pass
- update V1 (pre-deletion) and V2 imports together

### Barrel exports still expose V1 paths

Current file:

- `lib/features/chats/chats.dart`

Problem:

- the barrel still exports V1 draft store and V1 chat list view

Needed direction:

- remove or replace these exports before deleting the folder

## Suggested Removal Order

This is the safest sequence for fully deleting `features/chats/conversation/`.

### Phase 1. Finish the still-missing V2 user-facing behavior

Implement first:

1. unread launch
2. attachment open flow
3. sticker preview tap
4. mention tap plumbing
5. chat page shell lifecycle/actions
6. thread page shell lifecycle/read/subscription behavior

Reason:

- once these are in place, deletion stops being blocked by visible regressions

### Phase 2. Rehome shared code that still lives under V1

Move or replace:

- `ConversationScope`
- `ConversationMessage`
- shared message mapper/domain store dependencies
- read-state transport service(s)
- remaining audio services/providers
- barrel exports

Reason:

- these are the build-time blockers for removing the folder

### Phase 3. Delete dead V1 presentation code last

Only after Phases 1 and 2:

- remove V1 page shells
- remove V1 presentation widgets
- remove V1 application/data leftovers that no longer have imports
- run `flutter analyze`

## Git History Playbook After V1 Deletion

If the old folder is gone and we need to recover how something worked, use:

```bash
git log --follow -- <old-path>
git show <commit>:<old-path>
git blame <old-path>
git grep -n "<symbol-name>" $(git rev-list --all -- lib/features/chats/conversation)
```

Useful examples:

```bash
git log --follow -- lib/features/chats/conversation/presentation/thread_detail_view.dart
git log --follow -- lib/features/chats/conversation/presentation/chat_detail_view.dart
git log --follow -- lib/features/chats/conversation/presentation/message_row.dart
git log --follow -- lib/features/chats/conversation/presentation/message_overlay.dart
git show 18919c5
```

If a future task starts with "how did V1 do this?", start by searching this doc
for the behavior name, then use the referenced old path with `git log --follow`.
