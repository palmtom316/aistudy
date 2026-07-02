-- anki-sync-export.sql —— 从 Anki collection.anki2 导出复习日志 CSV
-- implements SPEC §5.1
-- 用法（先关闭 Anki 释放库锁）:
--   sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv
-- 产出列: anki_guid, review_date, interval, ease
--   anki_guid   = notes.guid（由 anki-export.sh 写入的稳定 guid，与 vault frontmatter anki_id 同口径）
--   review_date = 复习日 (YYYY-MM-DD)
--   interval    = 复习后间隔天数
--   ease        = ease 乘子（permille/1000，与 §5.1 阈值 1.5 口径一致）
-- 注: r.id 是 revlog 主键，每行唯一，无需 GROUP BY 聚合。
SELECT n.guid AS anki_guid,
       strftime('%Y-%m-%d', r.id / 1000, 'unixepoch') AS review_date,
       MAX(r.ivl, 0) AS interval,
       r.ease / 1000.0 AS ease
FROM revlog r
JOIN cards c ON r.cid = c.id
JOIN notes n ON c.nid = n.id
ORDER BY n.guid, r.id;
