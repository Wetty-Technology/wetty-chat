---
name: flutter-bug-triage
description: >
  Triage bugs in the wetty-chat Flutter application.
  Use this skill whenever the user reports a Flutter app bug, describes unexpected mobile or desktop
  UI behavior, mentions something broken or not working in `wetty-chat-flutter`, or asks to investigate
  a frontend issue in the Flutter client. This includes startup and auth problems, navigation and
  deep-link issues, chat list or conversation timeline regressions, Riverpod state bugs, WebSocket
  or push notification problems, media or voice-message failures, cache or persistence issues, and
  performance regressions. Even if the backend may be involved, start here when the symptom is
  observed in the Flutter app.
---

# Flutter Bug Triage

You are triaging a bug in wetty-chat, a Flutter chat client. Systematically narrow the symptom,
identify the likely source, propose reproduction steps, add focused diagnostics when needed,
and produce a root cause analysis with a concrete fix.

## Project context

- **App bootstrap**: `wetty-chat-flutter/lib/main.dart` initializes `SharedPreferences`, app version headers, and `ProviderScope`
- **App shell**: `wetty-chat-flutter/lib/app/app.dart` wires locale, auth session bridging, push setup, unread badges, lifecycle recovery, and WebSocket routing
- **Routing**: `wetty-chat-flutter/lib/app/routing/app_router.dart` uses `go_router` with auth/bootstrap redirects, a `StatefulShellRoute`, chat workspace routing, full-screen media routes, and settings routes
- **State**: Riverpod manual providers, mostly `Provider`, `NotifierProvider`, `AsyncNotifierProvider`, and provider families; no codegen
- **API models and services**: shared DTOs and service clients live under `wetty-chat-flutter/lib/core/api/models/` and `wetty-chat-flutter/lib/core/api/services/`
- **Networking**: Dio in `wetty-chat-flutter/lib/core/network/dio_client.dart`; API configuration in `api_config.dart`; auth/session headers in `lib/core/session/dev_session_store.dart`
- **Realtime**: `wetty-chat-flutter/lib/core/network/websocket_service.dart` owns the socket; `ws_event_router.dart` fans events out to list stores, unread badges, conversation timeline, pins, stickers, and reconciliation
- **Recovery/reconcile**: `wetty-chat-flutter/lib/features/shared/application/app_refresh_coordinator.dart` and `chat_inbox_reconciler.dart` coordinate resume, notification, tab reselection, pull-to-refresh, and websocket reconnect recovery
- **Chat list**: group, thread, and combined list behavior lives under `wetty-chat-flutter/lib/features/chat_list/`
- **Conversation**: conversation behavior lives under `wetty-chat-flutter/lib/features/conversation/`, split into `compose`, `timeline`, `message_bubble`, `media`, `pins`, and `shared`
- **Shared message domain**: canonical message models, read-state logic, attachment service, and shared presentation helpers live under `wetty-chat-flutter/lib/features/shared/`
- **Groups**: group members, metadata, and settings live under `wetty-chat-flutter/lib/features/groups/`
- **Audio and voice messages**: audio services live under `wetty-chat-flutter/lib/features/audio/`, recorder code under `features/conversation/compose/application/`, and the local voice widget package under `wetty-chat-flutter/packages/voice_message/`
- **Persistence**: `SharedPreferences` stores under `lib/core/session/`, `lib/core/settings/`, notifications, sticker order, drafts, and other feature-level stores
- **Localization**: user-facing Flutter strings belong in `wetty-chat-flutter/lib/l10n/app_*.arb` and are accessed through `AppLocalizations`
- **Testing**: widget, provider, repository, and service tests live under `wetty-chat-flutter/test/`; some older test folders still use legacy chat-list and chat-domain names

Some current filenames and test folders still contain transitional suffixes. Treat those suffixes as
implementation details and search by feature/domain when paths have been renamed.

## Triage workflow

### 1. Understand the bug

Clarify the symptom before touching code:
- What did the user expect, and what happened instead?
- Is it reproducible, intermittent, or device-specific?
- Does it affect Android, iOS, desktop, or Flutter web?
- Does it happen on cold start, after backgrounding, after notification launch, or only after realtime activity?
- Did a recent Flutter or backend change likely introduce it?

When the report is vague, ask for the exact screen, route, user action, and whether the problem is
visual, state-related, networking-related, realtime-related, persistence-related, or performance-related.

### 2. Locate the first likely source

Start with the layer that owns the behavior:

| Symptom | Start looking at |
|---------|------------------|
| App does not start, wrong environment, white screen | `lib/main.dart`, `lib/app/app.dart`, `lib/core/network/api_config.dart`, `lib/core/network/app_version.dart` |
| Login, bootstrap, auth redirect loops | `lib/core/session/dev_session_store.dart`, `lib/features/auth/presentation/auth_bootstrap_view.dart`, `lib/features/auth/presentation/auth_login_view.dart`, `lib/app/routing/app_router.dart` |
| Navigation, shell tabs, deep links, wrong detail route | `lib/app/routing/app_router.dart`, `lib/app/routing/route_names.dart`, `lib/app/presentation/home_root_view.dart`, `lib/features/chat_list/presentation/chat_workspace_shell.dart` |
| Chat list stale, wrong order, missing group/thread, pagination issues | `lib/features/chat_list/application/`, `lib/features/chat_list/data/`, `lib/features/chat_list/model/`, `lib/core/api/services/chat_api_service.dart`, `lib/core/api/services/thread_api_service.dart` |
| Combined list projection issues | `lib/features/chat_list/application/`, especially all-list projection, group-list store, and thread-list store code |
| Unread counts or read state wrong | `lib/core/notifications/unread_badge_provider.dart`, `lib/features/shared/data/read_state_repository.dart`, chat/thread list stores, `lib/features/shared/application/chat_inbox_reconciler.dart` |
| Conversation timeline gaps, duplicates, wrong ordering, stale messages | `lib/features/conversation/timeline/presentation/`, `lib/features/conversation/shared/data/`, `lib/features/conversation/shared/application/conversation_canonical_message_store.dart` |
| Optimistic send, composer, mentions, drafts, attachments, voice drafts | `lib/features/conversation/compose/`, `lib/features/shared/data/attachment_service.dart`, `lib/features/conversation/compose/application/audio_recorder_service.dart` |
| Message bubble rendering, reactions, replies, stickers, voice bubble UI | `lib/features/conversation/message_bubble/`, `lib/features/shared/model/message/`, `lib/features/stickers/`, `lib/features/audio/` |
| Realtime delivery, reconnect, missed updates, duplicate fan-out | `lib/core/network/websocket_service.dart`, `lib/core/network/ws_event_router.dart`, `lib/features/conversation/shared/data/conversation_realtime_message_applier.dart`, list stores |
| App resume, notification tap, pull-to-refresh, tab reselection recovery | `lib/features/shared/application/app_refresh_coordinator.dart`, `lib/features/shared/application/chat_inbox_reconciler.dart`, `lib/app/app.dart` |
| Push notifications or badge sync | `lib/core/notifications/push_notification_provider.dart`, `push_platform_client.dart`, `notification_tap_handler.dart`, `unread_badge_provider.dart`, `lib/app/app.dart` |
| Media viewer, save, thumbnails, avatar, or cache issues | `lib/features/conversation/media/`, `lib/core/cache/`, `lib/features/shared/presentation/app_avatar.dart` |
| Audio playback, waveform, source resolution, voice message failures | `lib/features/audio/`, `lib/features/conversation/timeline/presentation/voice_message_*`, `lib/features/conversation/message_bubble/presentation/voice*`, `packages/voice_message/` |
| Settings or persisted state not sticking | `lib/core/settings/app_settings_store.dart`, `lib/features/settings/presentation/`, `lib/core/session/dev_session_store.dart`, feature stores backed by `SharedPreferences` |
| Group members, group metadata, group settings | `lib/features/groups/members/`, `lib/features/groups/metadata/`, `lib/features/groups/settings/` |
| Sticker picker, pack order, pack detail, sticker websocket event | `lib/features/stickers/`, `lib/core/api/models/stickers_api_models.dart`, `lib/core/network/ws_event_router.dart` |
| Pins and pinned message banner/list behavior | `lib/features/conversation/pins/`, `lib/core/api/services/pinned_messages_api_service.dart`, `lib/core/api/models/pins_api_models.dart` |

If a listed file has been renamed, search by the feature directory and provider/class name rather
than assuming the suffix is stable. If the UI symptom looks correct locally but the payload is wrong
or incomplete, inspect the corresponding API service in `lib/core/api/services/` or feature data
service, then inspect the backend handler/service.

### 3. Trace the data flow

Read the real code path instead of guessing from filenames:
1. Start from the widget or route where the symptom appears.
2. Identify the provider or view model the widget watches.
3. Follow that provider into stores, repositories, API services, and realtime appliers.
4. Check how the resulting state flows back into the widget tree.

For Riverpod bugs, verify whether the problem is:
- stale provider state
- wrong provider invalidation or refresh timing
- a `select` watching the wrong field
- an `AsyncValue` state transition problem
- UI using `ref.read()` where it needs `ref.watch()`
- a store mutation that updates a repository-owned cache but not the provider state the UI reads

For UI bugs, distinguish between:
- state is wrong
- state is correct but not rendered
- state updates, but route, layout, scroll, lifecycle, or split-workspace behavior hides it

For realtime bugs, distinguish between:
- the websocket did not connect or reconnect
- the event model did not parse correctly
- the event reached `ws_event_router.dart` but was not fanned out to the right subsystem
- the subsystem applied the event but later reconciliation overwrote it
- the event applied to a list store but not to the active conversation, or the reverse

### 4. Write reproduction steps

Produce concrete steps another developer can follow:
- starting state
- exact route or screen
- taps, scrolls, and timing-sensitive actions
- expected versus actual result
- where to observe the failure: UI, logs, DevTools, network traces, websocket events, storage, or tests

Call out race conditions explicitly, for example: background the app, resume it, and wait for
push re-subscription, websocket reconnect, or inbox reconciliation before opening the conversation.

### 5. Add focused diagnostics

If the root cause is not obvious from reading code, add targeted logging at decision points.
When in doubt, add logs and ask the user to reproduce and provide logs. Do not make guesses when
the evidence is insufficient.

Prefer `dart:developer` `log` over `print`. Keep logs filterable and specific:

```dart
log(
  'ws reconnect scheduled',
  name: 'wetty.websocket',
  error: error,
);
```

Good places to log:
- provider state transitions
- route redirects, route extras, and launch parameters
- websocket connect, disconnect, reconnect, event parsing, and event fan-out
- recovery and reconciliation entry/exit points
- API request success or failure boundaries
- repository merge, read-state, or projection logic
- composer send flows and optimistic message reconciliation
- media, cache, audio source resolution, and voice playback boundaries

Add only enough logging to distinguish hypotheses. Remove one-off noise after fixing the bug.

### 6. Summarize root cause

State:
- **What is happening**
- **Why it happens**
- **Impact and scope**
- **Confidence level**
- **Evidence**

Separate confirmed findings from likely-but-unverified hypotheses.

### 7. Implement and verify the fix

After implementing the fix:
- run `dart format` on changed Dart files
- run `flutter analyze`
- run targeted `flutter test` files when relevant
- run broader verification if the change affects shared state, routing, auth, recovery, or realtime behavior

If the bug crosses into backend behavior, verify both sides.

## Common failure patterns in this app

- **Auth bootstrap and router redirect mismatch**: `app_router.dart` redirect logic depends on `authSessionProvider`; bad bootstrapping state can trap the app on login or bootstrap routes.
- **Provider state looks right, widget watches the wrong thing**: Riverpod rebuild issues often come from watching a provider or selected field that does not emit the changed value the UI needs.
- **Store and view model drift**: list and conversation flows often have a store plus a view model; the store can be correct while the view model exposes stale loading, pagination, or error state.
- **Realtime fan-out is incomplete**: a websocket event may reach `ws_event_router.dart` but never update the conversation, list store, unread badge, pins, stickers, or reconciler path the UI reads.
- **Conversation projection drift**: duplicates, missing rows, or wrong order often come from repository merge logic or canonical message state rather than the widget itself.
- **Reconciliation overwrites local state**: resume, notification, pull-to-refresh, or websocket reconnect can refresh inbox and active conversation state; check `AppRefreshCoordinator` and `ChatInboxReconciler`.
- **Lifecycle-sensitive bugs**: `WettyChatApp` performs work on resume, including push subscription and app recovery; cold-start, notification launch, resume, and manual refresh paths are not identical.
- **SharedPreferences assumptions**: settings, session, notifications, drafts, and sticker order are async-initialized or persisted; code that assumes immediate availability can fail on cold start or after clearing app data.
- **Route extras and path params**: attachment viewer, chat detail, thread detail, launch requests, and workspace transitions rely on typed extras and params; wrong casting or missing extras will fail at navigation boundaries.
- **Media and voice-message failures**: cache, storage, recorder, waveform, playback, and source-resolution services sit across feature and package boundaries; inspect both the feature service and `packages/voice_message/` when behavior diverges by platform.
- **Localization regressions**: user-facing strings must be in ARB files; hard-coded UI text can pass tests but break language coverage and review expectations.

## Verification guidance

- Prefer the smallest test or analyzer run that proves the fix, then widen only if the affected area is shared.
- For rendering or interaction regressions, start with existing widget and provider tests under `wetty-chat-flutter/test/`.
- For chat list bugs, check current and legacy chat-list tests under `test/features/`, including tests that still live under older chat-domain folder names.
- For conversation state bugs, check `test/features/conversation/` and tests around shared message domain behavior.
- For realtime, cache, read-state, or recovery bugs, add regression coverage close to the repository, store, provider, or coordinator that owns the behavior.
- If no automated test exists, document a manual repro and post-fix validation path.
