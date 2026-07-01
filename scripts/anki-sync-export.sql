-- anki-sync-export.sql —— 从 Anki collection.anki2 导出复习日志 CSV
-- implements SPEC §5.1
-- 用法（先关闭 Anki 释放库锁）:
--   sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv
-- 产出列: note_id, review_date, interval, ease
--   note_id     = Anki note id（与 vault frontmatter anki_id 同口径：anki-export 用 sha1(slug::key) 作 guid，
--                 Anki 内部 note id 即此 guid 的低 64 位——脚本侧 anki-sync.sh 用 sha1 重新匹配，不直接比 note_id 数值）
--   review_date = 复习日 (YYYY-MM-DD)
--   interval    = 复习后间隔天数
--   ease        = ease 乘子（permille/1000，与 §5.1 阈值 1.5 口径一致）
SELECT c.nid AS note_id,
       strftime('%Y-%m-%d', r.id / 1000, 'unixepoch') AS review_date,
       MAX(r.ivl, 0) AS interval,
       r.ease / 1000.0 AS ease
FROM revlog r
JOIN cards c ON r.cid = c.id
GROUP BY c.nid, r.id
ORDER BY c.nid, r.id;
