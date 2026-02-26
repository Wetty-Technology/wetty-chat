HTTP API use Authorization header for auth token
WS API Token is passed??? Query Param? Or subprotocol need to think this through later

## HTTP API

### GET /chats — List all chats for the current user

**Auth:** Required. Resolve `Authorization` header to a user (`uid`). Return `401 Unauthorized` if missing or invalid. All results are scoped to chats where this user is a member.

**Scoping:** Returns only chats the current user belongs to. Requires a **group membership** table (e.g. `group_members(uid, gid, role?, joined_at)`) so the backend can filter groups by membership.

**Query parameters (optional):**

| Parameter | Type   | Description |
|-----------|--------|--------------|
| `limit`   | number | Max chats to return. Server applies `min(user_input, configurable_max)` (e.g. cap at 100). |
| `after`   | string | Cursor for pagination (e.g. chat id). Omit for first page. |

**Sort:** Chats are ordered by **last activity descending** (most recent first). Consider storing denormalized `last_message_at` on the group (or a summary table) and indexing `(uid, last_message_at)` for performance.

**Response shape (per chat):** At minimum include identifiers and sort key; optionally include preview and unread for a single “inbox” load.

- **Required:** `id` (chat id, maps to `gid`), `name` (from `groups.name`), `last_message_at` or equivalent for ordering.
- **Optional but recommended:** `last_message` (snippet or id), `last_message_id`; `unread_count` (requires e.g. `last_read_at` on membership).

**Pagination:** Cursor-based via `after` + `limit` is preferred for consistency; offset/limit is acceptable if chats-per-user stays modest. Include in response: `next_cursor` (or null if no more), and the list of chat objects.

**New messages:** This endpoint lists **conversation metadata**, not message history. New messages are delivered via **WebSockets** (e.g. “new message in chat X”). Clients can optionally poll `GET /chats` to refresh the list (e.g. with `If-Modified-Since` or an `updated_at`/etag), but real-time updates should use WS.

**Performance:** Index membership by `(uid, gid)` and, if sorting by last activity, by `(uid, last_message_at)`. Avoid N+1: fetch last message / last_activity in one or few queries (subquery, lateral join, or denormalized column).

---

POST /chats - Create a new chat
GET /chats/<chat_id>/messages?before=<message_id>&max=<max_num_message>
    The max here we should internally do a `min(user_input_max, some configurable constant)`
POST /chats/<chat_id>/messages
    Post a new chat message
GET /chats/<chat_id>/members

## WSS Messages

### Client -> Server
- Authenticate? 
- Ping 



### Server -> Client
- New Message
