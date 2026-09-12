-- Read-only, execute against the world database.
SELECT * FROM camps_schema;
SELECT table_name,engine FROM information_schema.tables
WHERE table_schema=DATABASE() AND table_name IN
('gameobject','game_event_gameobject','gameobject_battleground','camps_camp','camps_prop');
SELECT p.* FROM camps_prop p LEFT JOIN gameobject g ON g.guid=p.guid
WHERE g.guid IS NULL OR g.id<>p.entry;
SELECT p.* FROM camps_prop p LEFT JOIN camps_camp c ON c.account=p.camp
WHERE p.camp<>0 AND (c.account IS NULL OR p.account<>p.camp);
SELECT account,COUNT(*) AS props FROM camps_prop GROUP BY account;
