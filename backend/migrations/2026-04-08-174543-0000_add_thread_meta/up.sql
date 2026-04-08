CREATE TABLE thread_meta (
    chat_id          BIGINT NOT NULL REFERENCES groups(id),
    thread_root_id   BIGINT NOT NULL REFERENCES messages(id),
    reply_count      BIGINT NOT NULL DEFAULT 0,
    last_reply_at    TIMESTAMPTZ NULL,
    PRIMARY KEY (chat_id, thread_root_id)
);

-- Backfill from existing thread reply data
INSERT INTO thread_meta (chat_id, thread_root_id, reply_count, last_reply_at)
SELECT m.chat_id, m.reply_root_id, COUNT(*)::bigint, MAX(m.created_at)
FROM messages m
WHERE m.reply_root_id IS NOT NULL
  AND m.deleted_at IS NULL
GROUP BY m.chat_id, m.reply_root_id;
