# Compatibility boundary

Verified source: Tortoise 788227f2de05eb04781d2117e218ffb9bb08afe7, playerbots branch,
whose README targets Turtle 1.18.1 build 7272. Vanilla addon Interface is 11200.
The complete module linked into mangosd in a fresh Windows x64 Release build.

| Responsibility | Target API/evidence |
|---|---|
| Loader | modules/CMakeLists.txt; sanitized Addmod_camps_twowScripts |
| Command | AllCommandScript::CanExecuteCommand; false consumes |
| Authority | WorldSession::GetAccountId/GetSecurity; SEC_DEVELOPER/ADMINISTRATOR |
| Config | sConfig GetBoolDefault/GetIntDefault; OnAfterConfigLoad |
| World lifecycle | WorldScript startup/update/shutdown; PlayerScript notifications |
| Identity lookup | ObjectAccessor::FindPlayer, MapManager::FindMap, Map::GetGameObject |
| Preview | Map::GenerateLocalLowGuid(HIGHGUID_GAMEOBJECT), GameObject::Create |
| Static spawn | ObjectMgr::GenerateStaticGameObjectLowGuid, SaveToDB, LoadFromDB |
| Transform | Map::Remove/Add, Relocate, position/facing fields, UpdateRotationFields |
| Collision transform | GameObject::UpdateModelPosition |
| Persistence | DeleteFromDB, ObjectMgr grid registration, WorldDatabase transactions |
| Ground | Map::GetHeight, MapManager::IsValidMapCoord |
| Map restrictions | Map::Instanceable, Player::GetMapId/GetTransport |
| Continent partition | GetContinentInstanceId, GetInstanceId, native GameObjectData partition field |
| Travel | Player::TeleportTo |

No core seam was required and no tracked core source was changed. The only core-tree
addition is the module junction. The native build writes binaries into core/bin/Release.
There are no AzerothCore command tables, sConfigMgr, AC helpers or WotLK hooks.

Core gameobject templates determine scale; no shared template cloning or editing.
Position, height and yaw are supported. Native GameObjectModel inserts/removes a
dynamic model and updates its transform, but useful collision depends on the model
and extracted assets. MMAP navigation is not rebuilt by spawning decorations.
No claim is made that every building/WMO is physically walkable or blocks pathfinding.

PlayerBots source is present as mod-playerbots. The verified build has BUILD_PLAYERBOTS
OFF and its module disabled. The camps code has no PlayerBots headers/symbols, but a
combined bots-enabled link/runtime was not performed. Camp alts integration remains
unimplemented; account ownership itself works across normal alternate characters.

Thread evidence: CMSG_MESSAGECHAT is PACKET_PROCESS_WORLD; World::Update calls
UpdateSessions before maps, and OnUpdate after maps. MapManager waits for its jobs
before returning. Teleport notifications can arise in map work and therefore only
queue IDs. Live high-load/transfer acceptance still requires testing.

The optional Continents.Instanciate runtime setting partitions maps 0/1 despite
their not being dungeon instances. Edit state records the actual instance ID;
stored props resolve the native partition by position. Cross-partition movement
is rejected and partition transfers cancel the session. SaveToDB does not populate
GameObjectData::instanciatedContinentInstanceId; the module assigns it through
NewGOData using the same GetContinentInstanceId contract as ObjectMgr's DB loader.
ObjectGridLoader uses that field to select spawns. No core patch is needed.
