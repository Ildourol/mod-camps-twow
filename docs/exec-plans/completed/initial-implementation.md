# Initial implementation — completed 2026-09-11; live acceptance pending

## Discovered baseline
Standalone directory is empty and has no Git metadata. Core is clean at
788227f2de05eb04781d2117e218ffb9bb08afe7, branch playerbots.
Module discovery requires src/ and derives Addmod_camps_twowScripts.
AllCommandScript can consume commands before native member-function dispatch.
Chat packets use PACKET_PROCESS_WORLD; WorldScript::OnUpdate follows joined map jobs.
Native GameObject persistence uses WorldDatabase via sWorld.ExecuteUpdate.
CommitTransactionDirect is available for synchronous confirmation. SaveToDB mutates
the native cache before SQL completion, so failed writes must fail closed.
No CMakeCache.txt exists in the target tree; VS BuildTools and vcpkg CMake exist.

## Plan and acceptance gates
- [x] Inspect repository identity, instructions, module system and native GO APIs.
- [x] Finish reference/source map and architecture.
- [x] Implement module, config, safe catalogue and world-DB metadata migration.
- [x] Implement account camp ownership, preview/edit state and bounded undo.
- [x] Implement private versioned command protocol with strict parsing.
- [x] Implement stock Lua addon with button editor, catalogue and saved favorites.
- [x] Implement travel, visits, camp list and confirmed break.
- [x] Record optional PlayerBots decision; no coupling without safe verified API.
- [x] Verify discovery, compile and server link where local dependencies permit.
- [x] Complete documentation, project skills and static/manual validation plans.
- [ ] Live server/database/client acceptance (not authorized/executed in this run).

No live database, deployment or server restart is authorized. No core edits.
Runtime client/server acceptance remains separate from static and build checks.

## Final evidence and discovered adjustments
Native table engines are MyISAM in base SQL, so module startup requires operator-
reviewed InnoDB preparation before enabling. No ALTER or migration was applied.
Private self-whisper with tilde framing avoids native pipe hyperlink validation.
The existing ObjectMgr template cache replaces redundant startup template SQL.
Teleport/logout hooks enqueue values; world tick handles cleanup after map jobs join.
Cross-character commits invalidate stale undo. Native cache rollback is restored
where possible, with a persistence-failure latch requiring operator reconciliation.
Final target audit found optional continent partitions with nonzero instance IDs.
Edit state and spawn lookup now account for them; new native spawn cache records
initialize the loader's partition field, and cross-partition movement is rejected.
This variant was compiled/linked; runtime acceptance remains pending.

One compile scope error was fixed. Subsequent Release mangosd links succeeded;
parser CTest passes 10042 checks and 10000 malformed fuzz inputs. Static addon/config
checks pass. The build uses PlayerBots/Eluna/ SOAP off, with only camps statically
enabled. No claim is made for a combined bots-enabled build or live gameplay.

The ignored WOW Legends module source was found and reviewed; its SHA256 is recorded
alongside the mirror revision. It was not copied. Reference tracked Git states stay
clean; core has only the new module junction and generated ignored build outputs.
