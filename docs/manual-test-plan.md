# Live acceptance plan — not yet executed

Use a disposable development realm with operator-approved database preparation,
backups and two player accounts (A/B), an alt on A, and a SEC_DEVELOPER/ADMINISTRATOR
character. Record server SHA, addon version, config, client build, map/coordinates,
safe entry IDs, expected/observed results, and logs for every case. Do not run on a
live realm merely because this plan exists. Static/link evidence is in build-and-test.md.

## Module and addon
1. Without the module, open `/tc`. After five seconds show unavailable; verify no
   other player sees a query. Repeat with native PlayerCommands disabled.
2. With module disabled, HELLO reports disabled. STATUS works, building is rejected.
3. Enable with missing schema, then MyISAM native tables: fail closed with log reason.
4. With approved schema/engines and config, HELLO succeeds. Check GM/Camp capabilities.
5. Core config reload cancels a new preview and restores an existing edit. All
   editors reconnect; disabled configuration rejects subsequent placement.
6. Administrator RELOAD refreshes cached overrides/current config. Developer/player
   RELOAD is rejected. Verify it does not claim to reread config files itself.
7. `/tc`, `/turtlecamps`, Close, reopen, drag panel, `/reloadui`, relog and map transfer:
   no stale token reused. Test at 1024x768 and intended UI scale for clipped labels.
8. Save favorites/recent entries, reload UI: names survive, bounded 50/20. Manually
   malformed SavedVariables are sanitized. No token or server authority is persisted.

## Catalogue
1. Empty search, mixed-case partial name, exact valid entry, missing numeric entry.
2. Next/previous page, last page and beyond it: max eight rows and correct total.
3. Exact category label and empty category, unknown category, percent/tilde/pipe names.
4. Rejected entries: door, chest, trap, transport, spell focus, generic with script,
   quest relation, invalid display and server-only payload. Direct PREVIEW must fail.
5. Override disabled excludes a safe template; player_allowed=0 exposes it only in
   GM mode. A category override never grants spawning for an unsafe template.
6. Repeated Search requests hit the 750 ms throttle; typing alone sends nothing.

## Camp and permissions
1. A claims valid map-0/1 ground. A's alt sees the same camp/count and edits A's props.
2. Reclaim rejects. Map instance/custom-map normal claim, dead/combat/transport and
   unsupported ground claim reject. Configure forbidden map, zone and area IDs:
   claim, preview, delta into the restricted area and travel there must reject.
   GM placement bypasses personal restrictions; malformed lists disable startup.
   Confirm documented city/water policy separately.
3. Place exactly the cap; further save rejects, including two alts previewing the
   last slot concurrently. Global bounds should reject without partial state.
4. Test radius boundary +/-0.1 yard and horizontal minimum spacing, including camps
   above/below each other. GM mode bypasses camp rules but still obeys safe placement.
5. B sends A's spawn ID to edit/delete/duplicate and guessed native IDs: reject.
   Inject owner/map/coordinate fields or excess args: reject exact-arity validation.
6. A and an alt/GM attempt the same spawn edit simultaneously: only one lock succeeds.
   Commit from another editor invalidates stale undo for that GUID.
7. Normal user requests MODE GM: reject. Developer may edit module-owned objects of
   A; arbitrary non-module world spawns remain inaccessible through this module.
8. GO/VISIT test own, public, private, disabled visits, unknown camp, combat/dead,
   instance and transport. Verify shared default 60-second cooldown and changed
   Camps.TravelCooldownSeconds during the active session.
9. CAMPS lists own plus permitted public camps; GM sees all. Verify bounded pages.
10. BREAK REQUEST alone changes nothing. Expired/wrong confirmation rejects. Valid
    confirmation from the loaded camp atomically removes all camp props and row.
    GM world props on that account remain. Another active editor blocks break.

## Placement and persistence
1. Preview: object appears in front, no new gameobject/camps_prop rows. Verify from
   a second player that the preview is visible (no private phasing claim).
2. Forward/back/left/right at different character facings, raise/lower, yaw +/-;
   Shift coarse/Ctrl fine. Ground snap on terrain and extracted building floors.
3. Delta outside max per-step/total distance/radius is rejected with unchanged pose.
4. Cancel removes new preview. Existing edit Cancel restores exact original pose.
   No DB writes occur during repeated deltas, rotation, snap or Cancel.
5. Save a new object: native spawn + one ownership row, no duplicate temporary object.
   Operator restarts development server: object persists at saved transform.
6. Edit and save rotation/height/position across a grid boundary. Leave/reenter grid,
   restart, verify one object at the new transform and no stale spawn in old grid.
   Separately enable native continent partitioning in a development configuration:
   repeat preview/save/delete/undo on a nonzero partition, unload/reload its grid,
   reject deltas into a different partition and cancel on a partition transfer.
7. Delete then restart: native spawn and metadata are gone. No association orphan.
8. Let idle timeout expire, logout, transfer map, disable/reload and shut down during
   both new/existing edits: temporary object gone or old pose restored, no leak.
9. Crash disposable server during an unsaved edit: restart uses last committed pose.
10. Place representative M2/WMO decorations: check client collision, server height/LOS
    and bot pathfinding separately; record failures without assuming MMAP updates.

## Undo and failure injection
1. Place -> Undo removes. Edit move/rotate -> Undo restores. Delete -> wait a tick ->
   Undo recreates. Duplicate -> Save -> Undo removes only the duplicate.
2. Chain place/move/rotate/delete and undo in reverse order. Verify original GUID,
   cap/ownership and native grid state. More than 20 commits drops oldest history.
3. Map/radius/permission change before Undo rejects. Unsafe template change rejects.
   Logout/reload clears history. Concurrent changes cannot replay another user's undo.
4. In an isolated DB test, force ownership-insert/native-write/commit failure. No
   success reply, building latches off, data rollback and cached pose restore. Run
   read-only diagnostics; inspect native migration/respawn side effects separately.
5. Remove/mismatch a test ownership/native row offline: startup disables building;
   diagnostics identify it and do not automatically delete anything.
6. External native move/delete during maintenance: module rejects stale cached pose
   rather than applying an old snapshot; cancel and reload before resuming.

## Protocol abuse
Send wrong version, missing/excess fields, oversize payload, malformed percent escapes,
negative/overflow IDs, NaN/Infinity/exponent floats, invalid opcode, old request ID,
old edit token, token after map transfer, and movement flood. State and DB must remain
unchanged. Replies remain private and bounded. Drop a Save reply: addon reports
unknown state and never automatically repeats the mutation; reconnect and inspect.

PlayerBots gathering has no test case because it is not integrated. Before using a
bots-enabled realm, perform a combined build/link and repeat transfer/concurrency
tests with the actual bot population; no bot character should acquire implicit
authority from another character's addon.
