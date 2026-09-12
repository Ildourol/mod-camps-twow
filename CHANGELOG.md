# Changelog

## 0.3.0 — 2026-09-12
Zero-touch auto-connection, instant catalog, thematic quick-chips, and camp social sharing:
- Eliminated manual "Connect" button and "Server unavailable. Press Connect." prompts.
- Added transparent background auto-negotiation on login (PLAYER_ENTERING_WORLD) and frame toggle.
- Added intelligent startup request queuing: actions performed during connection negotiation are queued and dispatched as soon as the HELLO handshake completes.
- Auto-populates the default props catalog on first opening so the table is immediately full of content.
- Added thematic category quick-filter chips ([All], [Tents], [Seats], [Fires], [Lights], [Banners], [Crates]) for 1-click prop discovery.
- Added 2.0y coarse sensitivity step button in addition to 0.1y and 0.5y presets.
- Implemented PUBLIC command seam and camp visibility toggling (Make Public / Make Private) with permitted public camp visiting when Camps.Visits is enabled.
- Fixed Delete Spawn: C++ server now automatically cancels active edit on target spawn and only blocks if another client is busy editing it; addon now handles DELETED, removes row from table, clears selection, and syncs with database.
- Removed minimap icon completely per user request for a cleaner UI footprint (access builder via `/tc` or keybinding).
- Added comprehensive server response handlers for DELETED, UNDONE, CLAIMED, TRAVEL, and BROKEN.
- Added dynamic countdown timer (CONFIRM 15s) for safe camp deletion.
- Added silent self-healing on HANDSHAKE_OR_REPLAY and timeout events.

## 0.2.1 — 2026-09-12
UI declutter, 2D framed display card, and contextual controls:
- Replaced buggy 3D model frame with high-fidelity framed 2D picture/icon card (queries GetItemInfo, native CreatureType icons, and prop categories) eliminating camera clipping and visual bugs.
- Streamlined compact window footprint (840x560) removing visual bloat.
- Contextual action bar: [Preview]/[Favorite] on Catalogue; [Edit]/[Duplicate]/[Delete]/[Nearest]/[Facing] exclusively on Owned props; [Visit]/[Claim]/[Go Home]/[Public]/[Break] exclusively on Camps.
- Dynamic button disabling: movement, [Save], and [Cancel] buttons are automatically disabled and greyed out when no preview is actively manipulated.

## 0.2.0 — 2026-09-12
Visual overhaul, expanded catalogue, deep database links, and enhanced client controls.
Zero-preload on-demand database lookups for entire database (GameObjects, Buildings,
Creatures, Items) directly from sObjectMgr with uncapped paging (removed 500 count limit).
Added << and >> fast-jump pagination for browsing thousands of entries.
Client UI overhauled with dark slate/gold card containers, alternating zebra rows,
discrete table columns, and real-time compass HUD (degrees + N/NE/E/SE/S/SW/W/NW).
Fixed 3D model display using native DressUpModel with SetCreature and camera initialization.
Added Classic Wowhead, Turtle WoW Database, and Tortoise 3D Web Viewer deep links with 1-click copy.
Categorized creatures by native CreatureType (Beast, Critter, Humanoid, Undead, Dragonkin, etc.).
Completely eliminated chat protocol spam via ChatFrame_OnEvent and AddMessage suppression.
Auto-cancels previous preview when selecting a different item from the list.
Static verify script passes cleanly.



## 0.1.0 — 2026-09-11
Initial standalone module and stock Lua editor. Account camps, safe dynamic
catalogue, transactional native spawn persistence, preview/edit/cancel, 20-action
undo, private versioned transport, favorites/recent props and operating documentation.
Windows x64 Release compile/link and protocol/static checks completed. Live gameplay
acceptance remains pending. PlayerBots gathering and free 3D picking are not included.
