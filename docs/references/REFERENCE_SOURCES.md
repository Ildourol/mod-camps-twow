# Source identity and consulted evidence

Discovery date: 2026-09-11. Paths below are this review's environment evidence,
not runtime/build-script dependencies. Source priority is in AGENTS.md.

## Repositories

| Role | Full local path | Git SHA / branch | Initial state |
|---|---|---|---|
| Standalone deliverable | C:\Users\Admin\Downloads\mod -camps-twow\mod -camps-twow | No .git | Empty; Git revision/diff claims unavailable |
| Authoritative core | C:\Users\Admin\Downloads\mod -camps-twow\tortoise-wow-extended | 788227f2de05eb04781d2117e218ffb9bb08afe7 / playerbots | .git present, clean |
| Authoring reference | C:\Users\Admin\Downloads\mod -camps-twow\MangosSuperUI | d575020a91ae39f8799faabcb23cf906c47534c4 / main | .git present, clean |
| Editor interaction reference | C:\Users\Admin\Downloads\mod -camps-twow\MSUIClient | 40875e6a5bdcfeba21c6c8aa79b71447f12de53e / main | .git present, clean |
| Camp behavior reference | C:\Users\Admin\Downloads\mod -camps-twow\WOW_Legends_Server_Source | a5be9c2a6eda9ba38bba757fd32c7a6d95c516ea / main | .git present, tracked files clean; module source is ignored |

The WOW Legends manifest describes a copied upstream build-tree provenance rather
than the later local Git mirror SHA: upstream 82d3bf237d5166934062ec8b6758fc65f1826c87,
PlayerBots 1041b0b0705e3347f766ce22f5799ca03836ccae, overlay
9e2b66d415a84d9e19042c9f51e98cc19a2e6b02 plus manifest-described working changes.
Those are manifest claims, not independently verified Git ancestors of this mirror.

**Actual Warband module IS present**, despite default rg/git ls-files hiding it.
`modules/mod-wowlegends/src/wowlegends_warbandcamp.cpp` SHA256:
`3A25526306100F8C5C4294651DAAA6200E5BC0C6BB75F2F5B082F4A71C530D43`.
Its AGPL-3.0-or-later source was reviewed for behavior only; no code copied.
Clean Git status does not describe the contents/revision of ignored files.

Online player addon: [WOWLegendsHQ/wow-legends-player-addon](https://github.com/WOWLegendsHQ/wow-legends-player-addon),
main HEAD reported by git ls-remote as d00ab1bec98209330e183af60eb1e155b9ed4c01.
No local checkout, so no local dirty/clean status. The raw files were fetched from
main on this date, rather than from a commit-pinned URL; remote HEAD was observed
separately. Consulted `WoWLegendsPlayer/Core/Warband.lua`,
`WoWLegendsPlayer/Data/WarbandProps.lua`, `WoWLegendsPlayer/UI/Tabs/Warband.lua`,
and root README/license identification. Initial URLs lacking the WoWLegendsPlayer
prefix returned 404; corrected paths were available. No remote code was copied.

## Instructions and native source consulted
All discovered AGENTS.md/AGENTS.override.md files were searched, including ignored
directories: core AGENTS.md and MSUIClient AGENTS.md (plus this newly created project
guidance); no pre-existing AGENTS.override.md found. MangosSuperUI has no AGENTS.md
in this copy. MSUIClient CODE_STRUCTURE_LAW.md was read as reference guidance.
Core docs/CORE_SYSTEMS_GUIDE.md and docs/CORE_COMPATIBILITY_AUDIT_2026-09-05.md
were consulted for world/map ownership and native GO behavior, then declarations
and current callers were inspected. Root READMEs and licenses were consulted.

| Target files consulted | Evidence used |
|---|---|
| CMakeLists.txt; cmake/ConfigureModules.cmake | C++/platform flags and src-based discovery |
| modules/CMakeLists.txt; modules/README.md; modules/templates/basic/src/* | Sanitized loader, config and SQL conventions |
| modules/ModulesLoader.cpp.in.cmake | Generated/static loader design |
| src/game/ScriptObjects.h | AllCommand, World/Player hooks and signatures |
| modules/mod-dungeon-clear/src/DungeonClearCommand.cpp | Native module command interception example |
| src/game/Chat/Chat.h/.cpp | Session handler, command consumption, PlayerCommands gate |
| src/shared/Common.h; src/game/SharedDefines.h | Actual security levels, GO enums/flags |
| src/game/Objects/GameObject.h/.cpp | Create, save/load/delete, rotation, respawn, collision model |
| src/game/Commands/Commands.cpp | Native gobject add/move/turn/delete implementation |
| src/game/ObjectMgr.h/.cpp | Info map, GUID allocation, spawn cache/grid management, quest relations |
| src/game/Objects/Object.h | Active object pinning and deletion state |
| src/game/Maps/Map.h; MapManager.h/.cpp | Add/remove/lookup/height/instances and joined map workers |
| src/game/Maps/GridMap.h; src/game/Objects/Object.cpp | Coordinate-based native zone/area resolution |
| src/game/ObjectGridLoader.cpp; ObjectMgr.cpp native GO loader | Continent partition field and per-map spawn selection |
| src/game/Objects/Player.cpp; src/game/WorldSession.cpp | Before-teleport/logout hook placement |
| src/game/ObjectAccessor.h | Player identity lookup |
| src/game/World.h/.cpp | Startup/config/update/shutdown, ExecuteUpdate into WorldDatabase |
| src/game/Handlers/ChatHandler.cpp; src/game/Protocol/Opcodes.cpp | Private chat dispatch, strict link checks, world-thread processing |
| src/shared/Config/Config.h/.cpp | Module section loading under main-config-directory/modules |
| src/shared/Database/Database.h/.cpp; AutoUpdater.cpp | TransactionDirect and module SQL discovery |
| sql/create_databases.sql | Native MyISAM spawn/association schemas |
| modules/mod-playerbots/src/playerbot/PlayerbotScripts.cpp | Bot command/master attachment hooks; no camps gathering contract selected |
| modules/mod-dungeon-clear/addon/DungeonClear-1.12/*.toc and DungeonClear.lua | Vanilla interface, UI/event globals and addon style |
| tools/batch-compile-and-audit.ps1; cmake/FindACE.cmake; FindMySQL.cmake | Local tool paths/build evidence and dependency resolution |

## Reference behavior reviewed
MangosSuperUI: `MangosSuperUI/wwwroot/js/gameobjects.js` (template fields/types and
search presentation), `MangosSuperUI/Controllers/WorldEditorController.cs`
(authoring staging, coordinate representation, terrain nearest-vertex lookup and
patch rollback). Native Map::GetHeight takes precedence over that web terrain path.

MSUIClient: `MSUIClient/GameLoop/Scene/GameLoop.GameObjectRender.cs`,
`GameLoop/CreatorMode/GameLoop.Creator.World.cs`,
`GameLoop/CreatorMode/GameLoop.Creator.Gizmos.cs`,
`GameLoop/Dev/GameLoop.DevWindow.Edit.cs`, `GameLoop/Dev/GameLoop.DevWindow.Overlays.cs`,
`MSUIClient/Engine/ClientWindow.cs`. Findings: render-world-owned picking and model
placements, armed gesture ownership, copied working state, original transform,
ghost preview disposal, bounded overlays. The inspected gizmo code itself concerns
spell emitters; it is not proof of a stock addon transform gizmo.

WOW Legends: SOURCE_MANIFEST.txt, module LICENSE, and
`modules/mod-wowlegends/src/wowlegends_warbandcamp.cpp`: account claim/spacing,
catalogue validation, materialization after grid unload, no player-summoner lifetime,
location validation, cooldown/travel, phase state, alt-gather queue, startup and
world-update paths. Its character-database materialization/phasing and foreign
command/PlayerBots APIs are deliberately not adopted. Our requested architecture
uses native Tortoise persistent world spawns. Player addon behavior provides
confirmation/disabled detection and category ideas, while ours queries the server.

## Build cache map
No CMakeCache.txt existed in the initial workspace search. A directory containing a
binary was not treated as a build tree. These two caches were created and inspected:

| Field | build-camps | build-camps-tests |
|---|---|---|
| Absolute path | C:\Users\Admin\Downloads\mod -camps-twow\build-camps | C:\Users\Admin\Downloads\mod -camps-twow\build-camps-tests |
| CMAKE_HOME_DIRECTORY | C:/Users/Admin/Downloads/mod -camps-twow/tortoise-wow-extended | C:/Users/Admin/Downloads/mod -camps-twow/mod -camps-twow/tests |
| CMAKE_INSTALL_PREFIX | C:/Program Files/TurtleWoW | C:/Program Files/CampsProtocolTests |
| Generator / architecture | Visual Studio 17 2022 / x64 | same |
| Configuration used | Release | Release |
| Multi-config values | Debug;Release;MinSizeRel;RelWithDebInfo | same |
| MODULES | disabled; MODULE_MOD_CAMPS_TWOW=static | not applicable |
| BUILD_PLAYERBOTS | OFF | not applicable |
| Turtle flags | ALLOW_TURTLE_ADDONS=ON; anticheat ON; scripts ON | not applicable |
| Other choices | BUILD_ELUNA=OFF, ENABLE_SOAP=OFF, ENABLE_LTO=OFF, USE_LIBCURL=OFF | protocol-only C++ |

Effective module language standard: C++17 (generated modules.vcxproj stdcpp17).
Compiler: C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64/cl.exe.
SDK 10.0.26100.0; compiler reports 19.44.35228.0.
CMake: C:/vcpkg/downloads/tools/cmake-4.4.2-windows/cmake-4.4.2-windows-x86_64/bin/cmake.exe.
Toolchain: C:/vcpkg/scripts/buildsystems/vcpkg.cmake.
ACE include/lib: C:/vcpkg/installed/x64-windows/include and lib/ACE.lib.
MySQL headers: target/dep/windows/include/mysql; native Windows dependency library
directories include target/dep/windows/lib/x64_release and the vcpkg x64-windows tree.
Native Windows dependency configuration resolves remaining MySQL/SSL/zlib headers
and libraries through target CMake/vcpkg; successful link and post-build DLL copies
include libmysql, libssl-3-x64, libcrypto-3-x64, z, zstd and ACE.
No credential-bearing runtime configuration was read or copied into this project.
