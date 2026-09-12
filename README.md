# mod-camps-twow / TurtleCamps

![TurtleCamps Banner](docs/images/turtle_camps_banner.jpg)

A standalone decorative camp and GM world editor for the Tortoise Turtle 1.18.1 (build 7272) core. Open `/tc`, search safe props, buildings, creatures, or items, preview them in the world, move/raise/rotate/snap them, and Save. Manage account camps, adjust territory size, toggle public/private visibility, or force delete spawns anytime.

**Status:** Implementation compiles and `mangosd` links cleanly on Windows x64 Release. Full protocol tests (10,042 assertions + 10,000 fuzz checks) and static verification pass.

## Features
- **Categorized Catalogue**: Dedicated browsing tabs for **Props**, **Buildings**, **Creatures & NPCs**, and placeable **Items / Ground Clutter**.
- **Contextual Filter Chips**: Quick preset chips dynamically adapted per category (e.g., Tents, Seats, Fires, Storage, Nature; Houses, Towers, Pavilions; Humanoids, Beasts, Critters; Weapons, Armor, Food, Potions).
- **Interactive 2D Portrait Cards**: Real-time icon inspection, category badge, and entity ID info card for any selected or edited object.
- **Database & 3D Web Viewer Integration**: One-click URL generation to view selected entities in the Classic Wowhead database, Turtle WoW Database, or the Tortoise 3D Web Model Viewer.
- **Mouse Scroll Wheel Navigation**: Scroll through catalog, owned spawns, and public camp listing pages using the mouse scroll wheel over the table or row buttons.
- **Camp Territory Management**: Claim or relocate personal camps with customizable territory sizes (20y, 40y, 60y, 80y) and Public/Private visitor permissions.
- **Camp Group Filtering**: Cycle between viewing All props, Camp-assigned props, or free World props in the Owned list.
- **Force Delete**: Unconditional server force-deletion of placed spawns directly from the world and database, with instant client cleanup and `/tc delete <guid>` support.
- **Precision 3D Transform Controls**: Character-relative nudge buttons (Forward, Back, Left, Right, Up, Down, Ground Snap, Rotate Yaw) with Fine / Normal / Coarse step toggles.
- **Mouse & Keyboard Shortcuts**: Wheel for elevation (Z), Shift+Wheel for rotation (Yaw), Ctrl+Wheel for forward/back, Alt+Wheel for strafe.
- **Double-Click & Shift-Click**: Double-click any row to preview immediately; Shift-click to paste item or entity links into chat.
- **Informative Delayed Tooltips**: Rich 3-second hover tooltips on all UI buttons explaining exact actions and keybindings.
- **Dual Authority**: Normal Player Camp mode vs. GM World Mode (`SEC_DEVELOPER`); cross-editor locks, 20-action undo stack, and ownership validation.
- **Personal Bookmarks**: 50 persistent favorites and 20 recent placement history slots saved per character.

## Installation and build integration
Keep this repository standalone. Place a copy or directory junction at
`<core>/modules/mod-camps-twow` (the src directory must be directly beneath it).
The core discovers `Addmod_camps_twowScripts()` automatically; no custom module
CMake file is needed. The provided workspace already has a junction.

Configure the selected build with `-DMODULE_MOD_CAMPS_TWOW=static`. Global MODULES
may remain disabled so unrelated optional modules are not enabled. Preserve your
existing PlayerBots settings. Then build `mangosd`, not just `modules`:

```powershell
cmake --build "<build-directory>" --config Release --target mangosd --parallel 8
```

The exact verified configuration and output are in [build-and-test.md](docs/build-and-test.md).
No installation/deployment or live SQL application was performed by this project.
The standalone directory currently has no Git metadata; initialize/version it
according to your own repository workflow.

## Database and configuration
1. Back up the world database. Review native table engines and the optional manual
   `tools/prepare-transactional-tables.sql`. Apply engine changes only in an operator
   maintenance window. They are deliberately outside the automatic updater path.
2. Apply `data/sql/world/20260911_01_camps.sql` to the **world** database, manually
   or through the target updater's module allowlist. No auth/character migration.
3. Put `conf/mod-camps-twow.conf.dist` beside the target's other module config files
   as `mod-camps-twow.conf` without `.dist`, retaining `[ModuleConf]`.
4. Set `Camps.Enable = 1`. Keep `Camps.Players = 0` for GM-only use. Set it to 1
   for personal camps after checking safe entries and location policy.

| Key | Default | Meaning / enforced range |
|---|---:|---|
| Camps.Enable | 0 | Master enable |
| Camps.Players | 0 | Normal-player camp building |
| Camps.Visits | 0 | Travel to another public camp |
| Camps.PropCap | 100 | 1–500 props per personal camp |
| Camps.Radius | 40 | 5–100 yards, three-dimensional prop boundary |
| Camps.MinimumSpacing | 100 | At least twice radius, at most 1000; horizontal spacing |
| Camps.EditTimeoutSeconds | 120 | 15–600 seconds idle edit timeout |
| Camps.TravelCooldownSeconds | 60 | 15–3600 seconds, shared Go/Visit per active character |
| Camps.ForbiddenMaps | empty | Comma-separated native map IDs; ordinary camps already require 0/1 |
| Camps.ForbiddenZones | empty | Comma-separated native zone IDs |
| Camps.ForbiddenAreas | empty | Comma-separated native area IDs |

Each forbidden-ID list is limited to 64 entries / 512 bytes; malformed lists disable
the module. Restrictions apply at the proposed prop coordinates and travel destination;
GM placement bypasses personal camp restrictions.

Global safety bounds: 2000 camps, 10000 owned props, 20000 catalogue entries/overrides,
4096 active client states. Invalid/incomplete persistence loads disable building.

The target resolves module configs under `<main-config-directory>/modules/`. It loads
the list generated for enabled modules, and a missing module config can prevent
normal startup. See the target modules README for its install conventions.

## Addon setup and workflows
Copy `addon/TurtleCamps` to `<Turtle client>/Interface/AddOns/TurtleCamps`. Enable it
on the character screen. Its TOC uses vanilla Interface 11200. `/tc` and
`/turtlecamps` open the panel and negotiate protocol version 1.

Normal player: choose Camp mode, stand on valid ground on map 0 or 1, Claim, search
for a prop, select the row and Preview. Use the directional controls; Shift is
coarse, Ctrl is fine. Save makes it persistent; Cancel discards it. Owned lists
nearby props. Nearest/Facing starts an edit immediately. Cancel before Delete.
Go home travels to your camp. Mark Public to permit visits when the server allows
them. Camps lists accessible camps; select a camp and Visit. Break requires two
clicks within 15 seconds and deletes its props; stand near the loaded camp first.

GM: SEC_DEVELOPER or higher defaults to GM mode. Place on a supported outdoor map
without claiming a camp. GM edits are still limited to module-owned decorative
spawns within 60 yards. The module does not edit arbitrary native world content.
GM/Camp switches mode and cancels an active preview. Camp mode uses ordinary rules.

The buttons use private self-whisper `.camp` commands and tagged private system
replies. There is no public broadcast. Target `PlayerCommands` must allow normal
player commands. The addon sends at most one request every 0.8 seconds and waits
for each response. This is a conservative button editor, not smooth 3D dragging.

## Commands and diagnostics
Use the UI normally. Raw diagnostics (each request ID increases):

```text
.camp 1~1~HELLO
.camp 1~2~STATUS
.camp 1~3~RELOAD
```

RELOAD requires SEC_ADMINISTRATOR and reloads the manager from the **currently
loaded** sConfig values and catalogue tables; it does not reread config files itself.
Use the core's config reload to reread files; its hook then reloads camps. Reconnect
the addon afterwards. [protocol.md](docs/protocol.md) defines all commands.

## Safety, limitations and troubleshooting
Only verified generic decorative templates pass admission; overrides cannot enable
doors, chests, spell foci, transports, scripted or quest templates. Catalogue
categories describe appearance and never grant permission. Some visual props may
therefore not appear. See [catalogue-safety.md](docs/catalogue-safety.md).

No modified executable, raycast, direct world dragging, transform gizmo, personal
phasing, arbitrary scale, bank/crafting interaction or PlayerBot gathering exists.
Preview objects are opaque and visible to nearby players. Collision depends on
native GameObjectModel and extracted assets; MMAP paths do not rebuild around props.
Personal camps permit maps 0/1 only; GM mode also excludes dungeons/battlegrounds.
Native continent partitions are supported at code level; a preview cannot move
across a partition boundary. That runtime configuration remains untested. Normal
camp policy has configurable forbidden zones/areas but no automatic city/water blacklist.

- No reply: reconnect; check module discovery/config, PlayerCommands and server logs.
- Disabled: check schema version, InnoDB prerequisite, startup count/mismatch errors.
- Empty catalogue: inspect templates/overrides; do not weaken safety to get results.
- Rejected placement: check mode, account camp, cap, radius, distance and combat/map.
- Break rejected: load all props by standing centrally; resolve other editors first.
- Database failure: building latches off until restart. Review read-only diagnostics,
  repair deliberately, then restart through your normal operator process.
- Deleted undo needs a world tick to drain native removal before GUID reuse.
- Native GM commands/SQL editing these spawns externally can invalidate module state;
  coordinate maintenance and reload after deliberate native changes.

## Upgrade and removal
Back up world DB/config/SavedVariables, cancel editors, update module and addon
together, rebuild/link, review/apply forward migrations and restart through normal
operations. Protocol version mismatches fail; no silent downgrade exists.

For uninstall, first decide whether to retain persistent scenery. Break personal
camps and delete GM props while the module is enabled if removal is desired.
Disabling/removing the module alone leaves native spawns intact. Do not drop
ownership tables before accounting for every native spawn. Remove the addon and
SavedVariables only after preserving desired favorites. No automatic purge script
is supplied.

## Project map and credits
[Architecture](ARCHITECTURE.md), [source identity](docs/references/REFERENCE_SOURCES.md),
[manual tests](docs/manual-test-plan.md), [compatibility](docs/compatibility.md),
[project guidance](AGENTS.md), and reusable workflows in `skills/`.

Original implementation follows the target's GPL native API patterns. Camp concepts
reference WOW Legends; browsing/authoring concepts reference MangosSuperUI; editor
state concepts reference MSUIClient. No AGPL server code is copied. See
[THIRD_PARTY.md](docs/THIRD_PARTY.md) and LICENSE.
