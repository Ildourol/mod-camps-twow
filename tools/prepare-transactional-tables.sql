-- OPERATOR REVIEW ONLY. Not in the automatic migration directory.
-- Back up and schedule an offline maintenance window before running.
-- Native DeleteFromDB also touches the two association tables.
-- No rows, columns or indexes are removed; engine conversion can be expensive.
ALTER TABLE gameobject ENGINE=InnoDB, ROW_FORMAT=DYNAMIC;
ALTER TABLE game_event_gameobject ENGINE=InnoDB, ROW_FORMAT=DYNAMIC;
ALTER TABLE gameobject_battleground ENGINE=InnoDB, ROW_FORMAT=DYNAMIC;
