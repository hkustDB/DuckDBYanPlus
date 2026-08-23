-- Exact minimal round-3 annotation plan for local LSQB Q5.
-- The former imported artifact retained four logical semijoin views before
-- performing these same joins. Because DuckDB inlines views, that duplicated
-- scans and made the measured final statement substantially slower.
CREATE OR REPLACE TEMP VIEW ya_q5_message_tags AS
SELECT MessageId, TagId AS message_tag_id, count(*)::HUGEINT AS annot
FROM Message_hasTag_Tag_T
GROUP BY MessageId, TagId;

CREATE OR REPLACE TEMP VIEW ya_q5_replies AS
SELECT r.CommentId, m.message_tag_id, m.annot
FROM Comment_replyOf_Message_T AS r
JOIN ya_q5_message_tags AS m ON r.ParentMessageId = m.MessageId;

CREATE OR REPLACE TEMP VIEW ya_q5_comment_tags AS
SELECT CommentId, TagId AS comment_tag_id, count(*)::HUGEINT AS annot
FROM Comment_hasTag_Tag
GROUP BY CommentId, TagId;

SELECT coalesce(sum(r.annot * c.annot), 0) AS v7
FROM ya_q5_replies AS r
JOIN ya_q5_comment_tags AS c ON r.CommentId = c.CommentId
WHERE r.message_tag_id < c.comment_tag_id;
