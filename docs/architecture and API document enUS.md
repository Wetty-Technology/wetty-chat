# Wetty Chat IM API Document

## Global Notes

- **Routing convention:** HTTP API paths follow the pattern `/<module key>/<business action>`.
- **Request/response format:** Default content type is `application/json`; the default response code just uses http status code.
- **Authentication:** Apart from registration/login, all HTTP/WS/File requests must carry a Token in the header (e.g., `Authorization: Bearer <token>`) or as a query parameter. Token length is 100 chars, composed as:
  - 1–32: user uid
  - 33–64: user secret key (32 chars)
  - 65–68: client type (4 chars)
  - 69–76: transient refresh secret_key (reissued periodically) (8 chars)
  - 77–92: client key (16 chars)
  - 93–100: int32 timestamp (seconds) (8 chars)

---

## Part I: HTTP API

### 1. Users Module (Key: `users`)

_Handles user auth and basic profile._
- **POST** `/users/auth/register`
  - **Desc:** User registration.
  - **Req:** `{"username": "xx", "password": "xx"}`
- **POST** `/users/auth/login`
  - **Desc:** User login. Returns tokens with different lifetimes per client type.
  - **Req:** `{"username": "xx", "password": "xx", "client_type": "web|mobile"}`
  - **Res:** `{"token": "xxx", "user_key": "xxx"}` _(Web returns short‑lived token; Mobile returns long‑lived token.)_
- **GET** `/users/profile`
  - **Desc:** Get personal profile.
  - **Res:** `{"nickname": "xx", "avatar_fid": "xx", "bio": "xx", "sr_link": "xx", "add_friend_setting": "xx"}`
- **PUT** `/users/profile`
  - **Desc:** Update personal profile (avatar, bio, SR site link, add‑friend rules, etc.).
  - **Req:** `{"avatar_fid": "xx", "bio": "xx", ...}`

### 2. Friends Module (Key: `friend`)

_Manages friend relationships._
- **POST** `/friend/apply`
  - **Desc:** Send a friend request.
  - **Req:** `{"target_user_id": "xx", "apply_msg": "hi" }`
- **DELETE** `/friend/{user_id}`
  - **Desc:** Remove a friend.
- **POST** `/friend/block`
  - **Desc:** Block a user.
  - **Req:** `{"target_user_id": "xx"}`

### 3. Groups Module (Key: `group`)

_Covers group lifecycle and membership._
- **POST** `/group`  *(implemented)*
  - **Desc:** Create a group.
  - **Req:** `{"name": "xx"}`
  - **Res:** `{"id": "xxx", "name": "xx", "created_at": "..."}`  
- **GET** `/group/{group_id}`  *(implemented)*
  - **Desc:** Get group profile.
- **DELETE** `/group/{group_id}`
  - **Desc:** Disband a group (owner only).
- **PUT** `/group/{group_id}/profile`
  - **Desc:** Edit group profile (name, avatar, public/private, join‑verification rule, category, etc.).
- **GET** `/group/{group_id}/members`  *(implemented)*
  - **Desc:** List group members.
- **POST** `/group/{group_id}/members`  *(implemented)*
  - **Desc:** Admin adds members to group.
- **POST** `/group/{group_id}/members/apply`
  - **Desc:** Apply to join group.
- **DELETE** `/group/{group_id}/members/{user_id}`
  - **Desc:** Leave or kick a member.
- **PUT** `/group/{group_id}/managers`
  - **Desc:** Set group managers (assign/revoke).
- **POST** `/group/{group_id}/mute`
  - **Desc:** Mute/unmute a member.
  - **Req:** `{"target_user_id": "xx", "mute_status": true, "duration_seconds": 3600}`

### 4. Chats Module (Key: `chats`) — HTTP side

_Sending actions use HTTP for durability; receiving uses WS. Message types covered elsewhere._
- **GET** `/chats`  *(implemented)*
  - **Desc:** List current user’s chats.
- **GET** `/chats/{chat_id}/messages?before={message_id}&max={max_num_message}`  *(implemented)*
  - **Desc:** Paginate messages in a chat (cursor by `before`).
- **POST** `/chats/{chat_id}/messages`  *(implemented)*
  - **Desc:** Send a message (text, emoji, file, reminder, etc.).
  - **Req:** `{"message": "...", "message_type": "text|image|file|emote|...", "client_generated_id": "idempotency_key", "reply_to_id": "xx", "reply_root_id": "xx"}`
- **POST** `/chats/message/recall`
  - **Desc:** Recall a message.
  - **Req:** `{"msg_id": "xx"}`

### 5. File Module (Key: `fserv`)

Writing requires internal key in header (not exposed to clients). Clients may stream files directly but still need authorization.
- **Upload**
  - **API:** `POST /fserv/upload`
  - **Desc:** Chat module uploads files as File Stream.
  - **Header:** `Content-Type: multipart/form-data` or `application/octet-stream`
  - **Res:** Returns unique file ID: `{"fid": "file_xxx123"}` (used when sending messages).
- **Download/Stream**
  - **API:** `GET /f/fserv/download/{fid}`
  - **Desc:** Client retrieves file stream for display/download (e.g., load image, download doc).

---

## Part II: WebSocket Message Flow

### 1. WebSocket Events (Chats Module)

_Persistent connection for real‑time push._

- **Endpoint:** `ws://<domain>/ws/chats?uid=<uid>`
- **Heartbeat:** Client sends `ping` every 30s; server replies `pong`.
- **Server downstream events:**
  - `on_message`: New message received (text, emoji, file, etc.).
  - `on_recall`: A message was recalled.
  - `on_notify`: System notifications (e.g., friend request accepted, reminder, added to group, muted).

---

## Part III: Requirements / Architecture Analysis (PRD)

This section describes business needs plus **internal gating logic**. Items marked as internal are not public APIs.

### 1. Users Module Requirements
- **Multi‑client login strategy (internal):** Distinguish Web vs Mobile. Web uses short‑lived “ephemeral” tokens; Mobile (e.g., Android) uses longer‑lived “persistent” tokens.
- **Profile center:** Users can set avatar, bio, SR-site link.
- **Privacy controls:** Users can configure who may add them (e.g., requires verification, only mutual contacts, or anyone).

### 2. Friends Module Requirements
- **Relationship governance:** Support mutual friendships, and one‑way blocking that prevents the other side from messaging.

### 3. Groups Module Requirements
- **Lifecycle:** Create / dissolve groups.
- **Granular management:**
  - **Basics:** Name, avatar, category (e.g., large vs small groups affecting resource allocation).
  - **Permissions:** Owner can set managers (permission tiers), mute/unmute specific members, invite/remove members.
  - **Visibility:** Support Public (searchable/joinable) and Private (hidden) groups; joining may require different verification flows.

### 4. Chats Module (core messaging) Requirements
- **Message formats:** Text, emoji/emote, files; special reminders; lightweight per-line reactions for emotes.
- **Markdown handling (front/back internal policy):** Users may send rich-text with Markdown syntax; recommended to **validate on client** (or parse to AST server-side) for formatting such as headers, emphasis, code blocks—without constraining the API itself.
- **Forwarding & recall:** Support forwarding message bodies (if a file, forward its `fid`); support time-bounded recall.
- **Voice/Video calls (optional extension):** Reserve as secondary channel.
- **Internal gating / content checks:**
  - **User state service (internal):** Invoked before send/receive. Checks: logged-in status; friendship; recipient in blacklist; same group membership; group mute status. Only after passing checks can messages flow.

### 5. File Module Requirements
- **Streaming:** For Web/Android and other clients, uploads/downloads must use streaming to save memory and support large files.
- **File identity:** After upload, system generates `fid`; only `fid` is stored/recorded, not the file blob itself.
- **Internal gating for files:** Same gating as messages. When handling `GET /f/fserv/download/{fid}`, verify the requester is allowed to view the file (e.g., belongs to the group where it was sent, sender isn’t blocked). Prevent unauthorized access by guessing `fid`.

---

## Part IV: Technology Stack

| Layer            | Choice             | Rationale |
|------------------|--------------------|-----------|
| **Database**     | PostgreSQL         | Handles users, groups, memberships, messages; fits model/scale. |
| **Backend**      | Axum (Rust)        | Async, high performance, type-safe; good for modular & resilient services. |
| **API**          | REST over HTTP     | Simple request/response for send/list/CRUD; cacheable. |
| **Real-time**    | WebSockets         | Server→client push for new messages, live typing/online state. |

---

## Part V: Traffic Estimates

IM concurrency forecast ~15k; daily new messages ~20k; daily active users ~1k. Peak QPS around 3–5.
