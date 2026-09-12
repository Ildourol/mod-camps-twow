# Persistence and operator preparation

The **world database** is authoritative for both native spawns and module ownership.
`gameobject` stores transform/rotation/entry. `camps_prop` stores guid, owner account,
camp account (zero for GM world props), and entry for mismatch detection.
`camps_camp` stores one centre/public-visit setting per account. `camps_schema`
records version 1. `camps_catalog_override` configures optional presentation/admission.
No auth/character database migration and no duplicated persistent prop transform.

## Files and updater
- `data/sql/world/20260911_01_camps.sql`: forward, idempotent initial module tables.
  Target AutoUpdater discovers `modules/<name>/data/sql/world`, controlled by
  Database.AutoUpdate.AllowedModules and its configured modules path.
- `tools/prepare-transactional-tables.sql`: **manual operator preparation**, outside
  auto-discovery. It converts three native tables to InnoDB without deleting data.
- `tools/diagnostics.sql`: read-only checks for engines, mismatch and usage.

All files are prepared only. None were run against a database in this task.

## Why table engine preparation is required
The target `sql/create_databases.sql` defines gameobject and related association
tables as MyISAM. A transaction cannot atomically couple a MyISAM spawn to InnoDB
ownership. The module checks gameobject, game_event_gameobject,
gameobject_battleground, camps_camp and camps_prop are InnoDB and remains disabled
otherwise. This avoids silently imposing an expensive native-table conversion.

An operator must back up, inspect table sizes, schedule maintenance, review the
prepared ALTER statements, and run them explicitly before enabling the module.
ROW_FORMAT=DYNAMIC avoids carrying MyISAM FIXED format into InnoDB. Converting
storage engines is an operational change, not a core-source modification.

## Native lifecycle and transactions
Save uses GameObject::SaveToDB, which calls sWorld.ExecuteUpdate and writes through
WorldDatabase. The module starts a transaction on that same thread/database, appends
ownership SQL, and uses CommitTransactionDirect to confirm completion before success.
Delete calls native DeleteFromDB (including native grid/respawn/association cleanup)
and deletes metadata inside one transaction. Break batches all its loaded prop
deletions and the camp row. No asynchronous write is acknowledged as durable.

Core SaveToDB/DeleteFromDB update native memory before committing. Rollback handlers
restore original GameObjectData/grid entries and live transforms where relevant.
The module latches off on commit failure even after restoration, because native
respawn state and migration-log side effects are not covered by the world transaction.
Restart/reconcile through an operator after diagnosing the failure. Existing world
spawns still load natively, even when building is disabled.

No SQL runs during movement/snap/cancel. Existing edits leave the native DB pose
unchanged until Save. A process crash discards temporary GUIDs and in-memory undo;
native grid loading reconstructs committed spawns on restart.

## Ownership, integrity and external edits
Account identity comes only from WorldSession. Camp IDs are account IDs, not an
authority-bearing client token. Spawn entry metadata must match the native cache.
Missing spawns/camps or entry mismatches at startup disable building. Row-count
checks catch incomplete table loads; all stores have hard upper bounds.
Diagnostics report mismatches and never delete orphans automatically.

Native GM/SQL tools can edit outside the module's locks. Do not operate them on an
actively edited camps spawn. Begin/delete checks reject native pose drift against
the module snapshot. After deliberate external changes, cancel builders and reload.
A native GUID reused for the identical template/pose cannot be distinguished solely
by the existing native schema; coordinate such maintenance explicitly.

Undo recreation uses the original static GUID only when no native spawn or live
object owns it. Native deferred removal must complete first. Undo is bounded and
session-only; it is not a transaction journal or an undelete service across restart.

## Backups and uninstall
Back up native spawns and camps metadata together. Reimporting a stock world dump
without camps-owned spawns loses scenery even if character/auth databases survive.
If retaining scenery on removal, export the ownership list first. If purging, use
module deletion/break while maps are loaded, then verify diagnostics/counts before
dropping module tables. Do not infer which native rows are camps-owned by an entry
ID or GUID range. No destructive automatic uninstall is supplied.
