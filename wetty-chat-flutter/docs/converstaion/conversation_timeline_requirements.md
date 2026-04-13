# Conversation Timeline Requirements

## Purpose

This document defines the product requirements for the Flutter conversation timeline.
It is intentionally solution-agnostic. It describes the required user-visible behavior
for opening, scrolling, paging, navigating, and receiving updates in chat and thread detail.

This applies to:

- chat detail
- thread detail
- open at latest
- open at unread
- open at specific message

## Product Principles

The conversation timeline should feel:

- stable: visible content should not jump or jitter
- user-controlled: the app must not fight a drag gesture
- deterministic: the same input should lead to the same final viewport state
- context-preserving: when reading history, new data must not disrupt the reading position
- explicit: automatic relocation should happen only in clearly defined cases

## Glossary

- `live edge`: the viewport is at the newest end of the conversation and follows bottom changes
- `historical launch`: opening the conversation around an unread message or a specific message
- `target message`: the message requested by launch or jump navigation
- `jump to latest`: the explicit action that returns the viewport to live edge

## Launch Modes

There are only 3 launch modes:

- open at latest
- open at unread
- open at specific message

For requirements purposes:

- `open at latest` is its own mode
- `open at unread` and `open at specific message` share the same placement and scroll rules
- the only optional extra behavior for `open at unread` is rendering an unread marker

## Global Rules

- Live-edge state is derived from the actual scroll position.
- The app must never override an active user drag with a programmatic scroll.
- `jump to latest` must be visible whenever the user is not in live-edge mode.
- `jump to latest` must be hidden whenever the user is in live-edge mode.
- Re-entering live edge happens only when the viewport actually reaches bottom.
- There is no “near bottom” snap-to-live behavior.
- Paging older or newer content must preserve the current reading position.
- Realtime updates must not move the viewport unless the user is in live-edge mode.

## Allowed Automatic Relocations

Automatic relocation is allowed only in these cases:

- open at latest
- open at unread
- open at specific message
- user sends a message in the conversation
- user naturally reaches bottom and re-enters live edge

Automatic relocation is not allowed for:

- incoming realtime messages while browsing history
- older-page load
- newer-page load
- row-level updates such as reactions, edits, deletes, or delivery-state changes

## Core Behaviors

### 1. Open at latest

Expected behavior:

- the conversation opens at live edge
- the newest message is visible in its correct final position
- new incoming messages follow naturally
- `jump to latest` is hidden

### 2. Historical launch: unread or specific message

Unread and specific-message launch follow the same core behavior.

Expected behavior:

- the target message is loaded with surrounding context
- the target message is placed as high in the viewport as physically possible
- if there is enough content below, the target appears at the top of the viewport
- if there is not enough content below, the target appears at the highest final position physically possible
- the app must render directly into that correct final position rather than render one state and correct later
- the target receives a temporary highlight that fades out
- the fade must not move the viewport
- if the final physical placement is effectively live edge, the conversation is considered launched in live-edge mode immediately
- if the final physical placement is not live edge, the conversation starts out of live-edge mode and shows `jump to latest`

Unread-specific note:

- rendering an unread marker is optional, not a hard requirement

### 3. Historical target placement rule

This rule applies to unread launch, specific-message launch, and in-conversation jump-to-message.

Expected behavior:

- the target is placed as high as physically possible
- “as high as possible” is constrained by the actual amount of content below the target
- if the target is too close to the end of the conversation to reach the top, the app should calculate the correct final placement before presenting the timeline
- if that final placement is effectively live edge, the result is treated as live edge
- the target should still be highlighted in that case

### 4. Jump to message from an open conversation

This applies to reply taps and any other in-conversation jump action.

Expected behavior:

- tapping a reply uses the same target-jump flow as any other jump-to-message action
- if the target is already visible, the app should use a smooth in-place scroll
- if the target is loaded and only a short distance off-screen, the app may still use a smooth in-place scroll
- if the target is far away, or not loaded in the current list, the app should use the full jump flow and load/rebuild around the target
- the app should not animate an excessively long travel through history
- smooth-scroll and full-jump paths must converge to the same final state
- that final state is the same historical-target placement rule described above
- after the target is reached, it receives the same temporary highlight behavior

Open detail:

- the exact threshold between “near enough for smooth scroll” and “far enough for full jump flow” is left to the implementation, but it must be reasonable

### 5. Stay at live edge

Expected behavior:

- new messages appear naturally at the bottom
- the viewport follows them
- `jump to latest` remains hidden

### 6. Leave live edge by scrolling up

Expected behavior:

- leaving live edge happens on the first deliberate upward drag
- the app must not resist the gesture
- there is no bounce back to bottom
- once the user has left live edge, `jump to latest` becomes visible

Note:

- the implementation may reference how other chat apps behave, but the hard requirement is immediate exit on deliberate upward drag without fighting the user

### 7. Realtime updates while browsing history

Expected behavior:

- visible content remains fixed
- the user’s reading position is preserved
- `jump to latest` remains visible
- new messages should ideally be inserted into the underlying conversation state so they become visible naturally as the user scrolls downward later
- if insertion is not possible in some intermediate loading state, the result should still avoid an artificial jump or relocation

### 8. Paging while browsing history

Expected behavior:

- loading older pages does not move the currently visible message content
- loading newer pages does not move the currently visible message content
- newly loaded rows may appear entirely off-screen above or below
- there is no snap to bottom
- loading indicators or gap rows may appear or disappear during pagination
- when a loading indicator is replaced by loaded messages, the visible message content the user was reading must remain fixed

### 9. Return toward bottom from history

Expected behavior:

- the user can scroll down through newer content freely
- there is no threshold-based snap when the user gets near bottom
- `jump to latest` remains visible until bottom is actually reached

### 10. Automatically re-enter live edge at bottom

Expected behavior:

- live edge resumes exactly when the viewport reaches bottom
- not before
- once re-entered, `jump to latest` is hidden
- new bottom changes follow naturally again

### 11. Use jump to latest

Expected behavior:

- tapping `jump to latest` returns the viewport to live edge
- `jump to latest` is hidden after the return

Open detail:

- whether this return is animated or immediate is left to the implementation
- there is a slight product preference for animated return when practical, but it is not a hard requirement

### 12. Send a message while reading history

Expected behavior:

- sending a message automatically jumps the user to bottom
- the sent message is visible in the final live-edge position
- this happens even if the user was deep in history
- the previous historical reading context is discarded
- there is no requirement to preserve or restore the old historical anchor after send

### 13. Row-level updates

This includes:

- reactions
- delivery-state changes
- edits
- deletes or tombstones

Expected behavior:

- in history mode, visible content stays stable
- in history mode, off-screen updates must not cause on-screen jitter or shifting
- in history mode, rows update in place without moving the current reading position
- in live-edge mode, mutations that change the effective bottom layout must leave the viewport at the true bottom by the end of the update
- in live-edge mode, it is acceptable for the layout/update pass to settle during the mutation as long as there is no visible glitch and the final state is still true bottom

Examples of bottom-affecting mutations:

- new incoming messages
- local sends
- reactions on the last visible or bottom message
- edits or deletes that change bottom-area height

Implementation note:

- the exact anchoring strategy is left to the implementation as long as the visual behavior is stable

### 14. Thread detail

Thread detail follows the same rules as chat detail.

Expected behavior:

- open at latest thread reply behaves like open at latest
- historical launch inside a thread behaves like historical launch in chat
- leaving live edge, paging, realtime handling, and re-entry at bottom follow the same rules

### 15. Viewport size changes at live edge

This includes:

- keyboard open
- keyboard close
- orientation change
- other viewport resize

Expected behavior:

- if the user is at live edge before the viewport changes size, they remain effectively at the true bottom afterward
- opening the keyboard at live edge keeps the bottom of the conversation visible
- closing the keyboard at live edge also keeps the viewport pinned to the true bottom
- live-edge viewport changes should not leave the user slightly above bottom in a broken intermediate state

Open detail:

- viewport changes while browsing history are not a hard requirement here

## Edge Cases

### Target near the end of the conversation

Expected behavior:

- if the target cannot be placed at the top because it is too close to the end, it is placed as high as possible
- if that highest possible placement is effectively live edge, the result is treated as live edge
- the target is still highlighted

### Target already at live edge

Expected behavior:

- if the final scroll position is already live edge, the app does not need a separate historical-mode transition
- if the target is already visible and already effectively at live edge, highlight-only behavior is acceptable

### Failed target resolution

Expected behavior:

- if an unread or specific-message target cannot be resolved, the conversation falls back to live edge
- the app does not leave the user in a broken or ambiguous historical state
- `jump to latest` is hidden after fallback

### Extremely short conversations

Expected behavior:

- behavior should remain stable and reasonable
- the app should not visibly glitch or jump

Open detail:

- whether a conversation shorter than the viewport is treated as always-live-edge or some other stable behavior is left to the implementation

## Non-Requirements

This document does not define:

- implementation architecture
- widget structure
- state machine shape
- repository/cache design beyond user-visible outcomes
- exact animation durations

## Acceptance Criteria

The conversation timeline is acceptable only if:

- the user can always scroll upward away from live edge without the app fighting the gesture
- historical targets appear as high as physically possible in their correct final position
- if a historical target is effectively at bottom, the result is treated as live edge immediately
- visible content does not move during paging
- visible content does not move when realtime messages arrive while browsing history
- sending a message always returns the user to bottom
- re-entry to live edge happens only when bottom is actually reached
- `jump to latest` is shown exactly when the user is not in live-edge mode
