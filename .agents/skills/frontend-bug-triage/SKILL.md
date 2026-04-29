---
name: frontend-bug-triage
description: >
  Triage frontend bugs in the wetty-chat-mobile React application.
  Use this skill whenever the user reports a bug,
  describes unexpected UI behavior, mentions something broken or not working, or asks to investigate
  a frontend issue. This includes visual glitches, state management problems, WebSocket/real-time
  issues, API errors surfacing in the UI, broken navigation, notification bugs, and performance
  regressions. Even if the root cause might be in the backend, start here if the symptom is
  observed in the frontend.
---

# Frontend Bug Triage

You are triaging a bug in wetty-chat, a React/Ionic PWA chat application (~20k users).
Your goal is to systematically analyze the reported bug, locate the likely source, suggest
reproduction steps, add diagnostic logging where it helps, and produce a root cause analysis
with a concrete fix.

## Project context

- **Frontend**: `wetty-chat-mobile/` — React 19 + Ionic 8, Redux Toolkit, Axios, Vite
- **Backend**: `backend/` — Rust + Axum + Diesel/PostgreSQL
- **Bootstrap**: `src/main.tsx` hydrates settings, sticker preferences, client ID, JWT, and locale before rendering; it also installs bootstrap recovery handlers
- **App shell**: `src/App.tsx` initializes websocket, current user, app update toast, push notification bootstrap, notification open handling, lifecycle handling, and routing
- **Routing**: Ionic React Router with React Router v5; top-level routes include `/oobe`, `/landing`, `/push-open`, `/m/:encoded`, then mobile or desktop app layouts
- **Layouts**: `src/layouts/MobileLayout.tsx` owns mobile tab/router-outlet behavior; `src/layouts/DesktopSplitLayout.tsx` owns desktop split layout and route/modal behavior
- **State**: Redux slices in `src/store/`; listener middleware in `src/store/index.ts` projects message events into chats, threads, pins, and persisted sticker preferences
- **Imperative store access**: the store is created during async bootstrap and exposed to non-React modules through `src/store/index.ts`
- **Messages**: `src/store/messagesSlice.ts`, `messageEvents.ts`, and `messageProjection.ts` manage windowed message state and projections
- **Real-time**: WebSocket via `src/api/ws.ts`; events dispatch Redux actions and can trigger notifications, thread refreshes, and sync
- **Sync/recovery**: `src/api/sync.ts` refreshes active/archived chats and threads, badge count, and loaded message windows; app lifecycle lives in `src/hooks/useAppLifecycle.ts`
- **API client**: Axios with interceptors in `src/api/client.ts` for auth and version headers
- **i18n**: Lingui (`t`/`<Trans>`) with locale files under `locales/`
- **Storage**: IndexedDB helpers in `src/utils/db.ts`; persisted values include settings, client ID, effective locale, sticker preferences, and notification state; JWT also has cookie/cache handling in `src/utils/jwtToken.ts`
- **PWA/service worker**: app update and recovery flows use `src/serviceWorker.ts`, `src/hooks/AppUpdateProvider.tsx`, `src/hooks/useAppUpdate.ts`, and `src/bootstrapRecovery.ts`
- **Verification**: `npm run verify` runs lint and typecheck; no dedicated frontend test script is currently configured

## Triage process

### 1. Understand the bug

Start by making sure you understand the reported symptom clearly. If the description is vague,
ask clarifying questions:
- What did the user expect versus what happened?
- Is it reproducible or intermittent?
- Does it affect mobile layout, desktop layout, installed PWA, browser tab, or all of them?
- Does it happen on cold start, after app update, after returning from background, after reconnect, or after a notification open?
- Any recent changes that might have introduced it? Check `git log` when useful.

### 2. Locate the problem area

Explore the codebase to narrow down where the bug lives. Use this mental map:

| Symptom | Start looking at |
|---------|-----------------|
| App not loading, white screen, update loop | `src/main.tsx`, `src/bootstrapRecovery.ts`, `src/serviceWorker.ts`, app update hooks |
| OOBE, landing, permalink, push-open route issue | `src/App.tsx`, `src/pages/oobe.tsx`, `landing.tsx`, `permalink.tsx`, `push-open.tsx` |
| Mobile tabs or desktop split layout broken | `src/layouts/MobileLayout.tsx`, `src/layouts/DesktopSplitLayout.tsx`, `src/hooks/useChatRoutes.ts`, `src/utils/navigationHistory.ts` |
| Chat thread page issue | `src/pages/chat-thread/chat-thread.tsx`, `src/components/chat/messages/`, `src/components/chat/compose/` |
| Message not appearing, duplicate, wrong order | `src/store/messagesSlice.ts`, `src/store/messageEvents.ts`, `src/store/messageProjection.ts`, `src/api/messages.ts`, `src/api/ws.ts` |
| Optimistic send or confirmation issue | `src/components/chat/compose/`, `src/store/messagesSlice.ts`, `src/api/messages.ts`, `src/api/ws.ts`, `src/utils/clientId.ts` |
| Unread counts or app badge wrong | `src/store/chatsSlice.ts`, `src/store/threadsSlice.ts`, `src/api/sync.ts`, `src/utils/badges.ts`, listener middleware in `src/store/index.ts` |
| Chat list stale, wrong order, archived/muted state wrong | `src/components/chat/lists/`, `src/store/chatsSlice.ts`, `src/api/chats.ts`, `src/api/sync.ts`, `src/api/ws.ts` |
| Thread list, subscription, thread reply issues | `src/pages/threads.tsx`, `src/store/threadsSlice.ts`, `src/api/threads.ts`, websocket thread handlers |
| WebSocket disconnects, reconnect loops, missed events | `src/api/ws.ts`, `src/hooks/useAppLifecycle.ts`, `src/api/sync.ts`, `src/store/connectionSlice.ts` |
| App resume, background, online/offline sync bugs | `src/hooks/useAppLifecycle.ts`, `src/api/ws.ts`, `src/api/sync.ts`, `src/constants/chatTiming.ts` |
| Compose, mentions, uploads, voice recording, stickers | `src/components/chat/compose/`, `src/api/upload.ts`, sticker APIs and preferences |
| Scroll, virtualized rendering, jump-to-message bugs | `src/components/chat/virtualScroll/`, `src/pages/chat-thread/chat-thread.tsx` |
| Reactions or pins not updating | `src/store/messageEvents.ts`, `src/store/pinsSlice.ts`, `src/components/chat/reactions/`, `src/components/chat/pins/`, `src/api/pins.ts`, `src/api/ws.ts` |
| Media, image viewer, video preview, HEIC behavior | `src/components/chat/messages/media/`, `src/utils/heicMedia.ts`, `src/constants/media.ts` |
| Sticker rendering, picker, pack order, settings | `src/components/chat/compose/StickerPicker.tsx`, `src/components/chat/messages/StickerBubble.tsx`, `src/store/stickerPreferencesSlice.ts`, `src/pages/settings/stickers.tsx`, `src/api/stickers.ts` |
| Group settings, members, invites, permissions | `src/pages/chat-thread/`, `src/components/chat/settings/`, `src/components/chat-members/`, `src/components/permissions/`, `src/api/group.ts`, `src/api/invites.ts` |
| Auth, JWT, 401 errors, current user | `src/api/client.ts`, `src/utils/jwtToken.ts`, `src/store/userSlice.ts`, `src/js/current-user.ts` |
| Push notifications, notification tap/open routing | `src/hooks/usePushNotifications.ts`, `src/hooks/useNotificationOpenHandler.ts`, `src/serviceWorker.ts`, `src/pages/push-open.tsx`, notification navigation utilities |
| Settings not persisting, locale wrong | `src/store/settingsSlice.ts`, `src/utils/db.ts`, `src/i18n.ts`, settings pages |
| Performance or jank | virtual scroll config, Redux selectors, listener middleware, expensive render paths, missing memoization |

When the symptom could originate from the backend (wrong data shape, missing fields, race
conditions in API responses), also look at:
- The corresponding backend handler in `backend/src/handlers/`
- The service layer in `backend/src/services/`
- Database queries and migrations in `backend/`

Read the actual code. Trace the data flow from the user action through the component, hook,
Redux dispatch, API call, websocket event, listener middleware, and back through the state update
to the re-render.

### 3. Trace state and event flow

For Redux bugs, verify whether the problem is:
- the API/websocket event never arrived
- the action was dispatched but a reducer ignored or misclassified it
- listener middleware projected the event into one slice but not another
- a selector or component reads stale or incomplete state
- optimistic `cg_` IDs were not reconciled with server IDs
- a loaded message window was evicted or the active window index changed

For routing bugs, distinguish between:
- React Router path matching is wrong
- Ionic router outlet or tab state is wrong
- desktop split layout state is wrong
- notification/permalink navigation generated the wrong target
- route state such as background modal state survived a mobile/desktop transition

For lifecycle/realtime bugs, distinguish between:
- websocket connection/backoff state
- browser online/offline state
- app visibility/focus state
- `syncApp()` debounce/timing
- service worker notification handling versus in-page notification handling

### 4. Suggest reproduction steps

Write concrete steps another developer could follow to reproduce the bug. Include:
- starting state, such as installed PWA, logged-in user, open chat, archived chat, or loaded thread
- exact layout: mobile, desktop, or installed PWA
- actions to perform, including scroll, send, switch route, background, reconnect, or open notification
- what to observe and where: UI, console, Redux DevTools, network tab, websocket frames, service worker logs, storage, or badge count
- timing or race-condition aspects, such as switching chats while messages are still loading or reconnecting while a send is in flight

### 5. Add diagnostic logging

If the bug is hard to reproduce or the root cause is not immediately clear from reading the
code, add targeted logging to help narrow it down.

**Ephemeral logs** for quick one-off debugging:
```ts
console.log("descriptive message", relevantData);
```

**Persistent debug logs** for recurring issues or future visibility:
```ts
console.debug("[area:component] what happened", { relevantData });
```

Use a bracketed prefix so these can be filtered in DevTools, for example `[ws:reconnect]`,
`[messages:reconcile]`, `[sync:chats]`, `[notification:open]`, or `[virtual-scroll]`.

Place logs at decision points:
- API response boundaries
- websocket connect, reconnect, parse, and dispatch paths
- Redux reducer/listener middleware projections
- route target generation and route matching
- app lifecycle, online/offline, and sync entry points
- service worker notification and update flows
- virtual scroll measurement, staging, and preservation paths

A few well-placed logs at boundaries are more useful than logging every line. Remove one-off
noise after fixing the bug.

### 6. Root cause analysis

Summarize what you found:
- **What's happening**: the technical explanation of the bug
- **Why**: the underlying cause, such as missing null check, race condition, stale selector, wrong assumption about data shape, route mismatch, or incomplete event projection
- **Impact**: who is affected and under what conditions
- **Confidence**: distinguish confirmed evidence from likely-but-unverified hypotheses
- **Evidence**: code paths, reproduction result, logs, or network/websocket traces

### 7. Implement and verify the fix

After identifying the root cause, implement a focused fix:
- Make the smallest code change that addresses the confirmed cause
- Update related projections/listeners when state management is involved
- Check mobile and desktop layout behavior when routes or page structure change
- Check app lifecycle, websocket, and sync behavior when realtime state changes
- If the fix involves backend behavior, note and verify both frontend and backend changes

After frontend changes, run `npm run verify` from `wetty-chat-mobile/`.
This covers lint and TypeScript type checking. There is no dedicated frontend test script
configured at the moment, so document manual verification when behavior cannot be covered by
existing tooling.

For backend changes, run the appropriate Rust verification from `backend/`, usually `cargo build`,
`cargo test`, or `cargo clippy` depending on the affected area.

## Things to watch for

These are common patterns that cause bugs in this codebase:

- **Optimistic message IDs**: Messages get a `cg_` prefixed client ID on send, replaced with the server ID on confirmation. Bugs happen when code compares IDs without accounting for this.
- **Message window eviction**: Only 5 windows per chat are kept. Loading new message ranges can evict old ones, causing "messages disappeared" bugs.
- **Thread store keys**: Thread message windows use composite store keys like `chatId_thread_threadRootId`; code that treats them like chat IDs can call the wrong API or update the wrong slice.
- **WebSocket reconnection races**: After reconnect and lifecycle events, `syncApp()` runs with a debounce from `APP_SYNC_DEBOUNCE_MS`. Events around reconnect can still be duplicated, skipped, or overwritten by sync if projections are incomplete.
- **BigInt message ordering**: `messageProjection.ts` uses BigInt for ID comparison. Mixing string and number comparisons will break ordering silently.
- **Listener middleware projection drift**: A message event may update `messagesSlice` but not the corresponding chat list, thread list, unread count, pin state, or sticker preference state.
- **Stale closures in hooks**: WebSocket event handlers, notification handlers, and lifecycle callbacks can capture stale state if they bypass the store or depend on old route state.
- **IndexedDB async timing**: JWT token, settings, sticker preferences, locale, and client ID reads are async. Code that assumes synchronous availability will fail on cold start.
- **Desktop/mobile route differences**: A route can work in mobile tabs but fail in desktop split layout, or stale desktop modal route state can leak after switching to mobile.
- **Service worker versus page context**: Push notification, app update, and recovery bugs may involve both `serviceWorker.ts` and in-page hooks/utilities.
- **Localization regressions**: User-visible text should use Lingui `t` or `<Trans>`; hard-coded strings can be missed in review and extraction.
