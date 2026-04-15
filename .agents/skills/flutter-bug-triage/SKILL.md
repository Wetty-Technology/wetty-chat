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
- **App shell**: `wetty-chat-flutter/lib/app/app.dart` wires locale, auth session bridging, push setup, unread badges, and WebSocket routing
- **Routing**: `wetty-chat-flutter/lib/app/routing/app_router.dart` uses `go_router` with auth/bootstrap redirects and a `StatefulShellRoute`
- **State**: Riverpod manual providers, mostly `Provider`, `NotifierProvider`, and `AsyncNotifierProvider`
- **Networking**: Dio in `wetty-chat-flutter/lib/core/network/dio_client.dart`; feature APIs under `lib/features/**/data/`
- **Realtime**: `wetty-chat-flutter/lib/core/network/websocket_service.dart` and `ws_event_router.dart`
- **Persistence**: `SharedPreferences` stores under `lib/core/session/`, `lib/core/settings/`, and some feature-level stores
- **Testing**: widget and provider tests live under `wetty-chat-flutter/test/`

## Triage workflow

### 1. Understand the bug

Clarify the symptom before touching code:
- What did the user expect, and what happened instead?
- Is it reproducible, intermittent, or device-specific?
- Does it affect Android, iOS, desktop, or Flutter web?
- Does it happen on cold start, after backgrounding, or only after realtime activity?
- Did a recent Flutter or backend change likely introduce it?

When the report is vague, ask for the exact screen, route, user action, and whether the problem is
visual, state-related, networking-related, or performance-related.

### 2. Locate the first likely source

Start with the layer that owns the behavior:

| Symptom | Start looking at |
|---------|------------------|
| App does not start, wrong environment, white screen | `lib/main.dart`, `lib/app/app.dart`, `lib/core/network/api_config.dart` |
| Login, bootstrap, auth redirect loops | `lib/core/session/dev_session_store.dart`, `lib/features/auth/presentation/auth_bootstrap_view.dart`, `lib/features/auth/presentation/auth_login_view.dart`, `lib/app/routing/app_router.dart` |
| Navigation, shell tabs, deep links | `lib/app/routing/app_router.dart`, `lib/app/routing/route_names.dart`, `lib/app/presentation/home_root_view.dart` |
| Chat list stale, wrong order, unread counts | `lib/features/chats/list/data/chat_repository.dart`, `lib/features/chats/list/application/chat_list_view_model.dart`, `lib/core/notifications/unread_badge_provider.dart` |
| Conversation timeline gaps, duplicates, wrong ordering, optimistic send issues | `lib/features/chats/conversation/application/conversation_timeline_view_model.dart`, `lib/features/chats/conversation/data/conversation_repository.dart`, `lib/features/chats/message_domain/domain/message_domain_store.dart` |
| Composer, mentions, attachments, voice drafts | `lib/features/chats/conversation/presentation/compose/`, `lib/features/chats/conversation/application/conversation_composer_view_model.dart`, `lib/features/chats/conversation/data/attachment_service.dart`, `audio_recorder_service.dart` |
| Realtime delivery, reconnect, missed updates | `lib/core/network/websocket_service.dart`, `lib/core/network/ws_event_router.dart`, `lib/features/chats/conversation/application/conversation_realtime_registry.dart` |
| Push notifications or badge sync | `lib/core/notifications/push_notification_provider.dart`, `notification_tap_handler.dart`, `unread_badge_provider.dart`, `lib/app/app.dart` |
| Media, avatar, sticker, or cache issues | `lib/core/cache/`, `lib/features/stickers/`, `lib/shared/presentation/app_avatar.dart` |
| Settings or persisted state not sticking | `lib/core/settings/app_settings_store.dart`, `lib/core/session/dev_session_store.dart`, feature stores backed by `SharedPreferences` |
| Thread list or thread detail issues | `lib/features/chats/threads/data/thread_repository.dart`, `thread_list_view_model.dart`, `thread_list_view.dart`, `thread_detail_view.dart` |

If the UI symptom looks correct locally but the payload is wrong or incomplete, inspect the
corresponding API service in `lib/features/**/data/` and then the backend handler/service.

### 3. Trace the data flow

Read the real code path instead of guessing from filenames:
1. Start from the widget or route where the symptom appears.
2. Identify the provider or view model the widget watches.
3. Follow that provider into repository and API or realtime code.
4. Check how the resulting state flows back into the widget tree.

For Riverpod bugs, verify whether the problem is:
- stale provider state
- wrong provider invalidation or refresh timing
- an `AsyncValue` state transition problem
- UI not watching the provider that actually changes

For UI bugs, distinguish between:
- state is wrong
- state is correct but not rendered
- state updates, but route or lifecycle behavior hides it

### 4. Write reproduction steps

Produce concrete steps another developer can follow:
- starting state
- exact route or screen
- taps, scrolls, and timing-sensitive actions
- expected versus actual result
- where to observe the failure: UI, logs, DevTools, network traces, or tests

Call out race conditions explicitly, for example: background the app, resume it, and wait for
push re-subscription or websocket reconnect to happen before opening the conversation.

### 5. Add focused diagnostics

If the root cause is not obvious from reading code, add targeted logging at decision points.
When in doubt, add log and ask the user to repro / prodvide log *DO NOT* make guesses when you are not 100% certain.

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
- route redirects and launch parameters
- websocket connect, disconnect, reconnect, and event fan-out
- API request success or failure boundaries
- repository merge or projection logic
- composer send flows and optimistic message reconciliation

Add only enough logging to distinguish hypotheses. Remove one-off noise after fixing the bug.

### 6. Summarize root cause

State:
- **What is happening**
- **Why it happens**
- **Impact and scope**
- **Confidence level**

Separate confirmed findings from likely-but-unverified hypotheses.

### 7. Implement and verify the fix

After implementing the fix:
- run `dart format` on changed files
- run `flutter analyze`
- run targeted `flutter test` files when relevant
- run broader verification if the change affects shared state, routing, or realtime behavior

If the bug crosses into backend behavior, verify both sides.

## Common failure patterns in this app

- **Auth bootstrap and router redirect mismatch**: `app_router.dart` redirect logic depends on `authSessionProvider`; bad bootstrapping state can trap the app on login or bootstrap routes.
- **Provider state looks right, widget watches the wrong thing**: Riverpod rebuild issues often come from watching a higher-level provider that does not emit the changed field the UI needs.
- **Realtime fan-out is incomplete**: a websocket event may reach `ws_event_router.dart` but never update the conversation or list repository that the UI reads.
- **Conversation projection drift**: duplicates, missing rows, or wrong order often come from repository merge logic or message-domain canonicalization rather than the widget itself.
- **Lifecycle-sensitive bugs**: `WettyChatApp` performs work on resume, including push subscription and inbox reconcile; cold-start and resume paths are not identical.
- **SharedPreferences assumptions**: settings and session data are async-initialized at startup; code that assumes immediate availability can fail on cold start or after clearing app data.
- **Route extras and path params**: attachment viewer, chat detail, and thread routes rely on typed extras and params; wrong casting or missing extras will fail at navigation boundaries.
- **Media and voice-message failures**: storage, recorder, waveform, and playback services sit across feature and package boundaries; inspect both the feature service and `packages/voice_message/` when behavior diverges by platform.

## Verification guidance

- Prefer the smallest test or analyzer run that proves the fix, then widen only if the affected area is shared.
- For rendering or interaction regressions, start with existing widget and provider tests under `wetty-chat-flutter/test/`.
- For realtime or cache bugs, add regression coverage close to the repository, store, or provider that owns the behavior.
- If no automated test exists, document a manual repro and post-fix validation path.
