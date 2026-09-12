# Completed Plan: TurtleCamps Visual Overhaul, Database Links & Bug Fixes — 2026-09-12

## Goal
Implement UI visual improvements, deep database linking (Turtle DB + 3D Viewer), in-game chat hyperlinks, rich row tooltips, and bug fixes (NPC/Item preview and favoriting) in TurtleCamps.

## Status
- [x] Deleted previous build folders (`build-camps`, `build-camps-tests`).
- [x] Implement enhanced UI layout, styling, and card containers in `TurtleCamps.lua`.
- [x] Implement deep database links (Turtle DB & Tortoise 3D viewer) with auto-highlight.
- [x] Implement row hover tooltips and Shift-Click chat hyperlink insertion.
- [x] Implement bug fixes: `needSelection` for NPCs/Items, `UISpecialFrames` for Escape, `/tc spawn <id> [type]` parsing.
- [x] Run static verification script `tools/verify.ps1`.
- [x] Audit changes and update documentation (`addon.md`, `CHANGELOG.md`).
- [x] Move active plan to completed and update walkthrough.

## Evidence & Summary
- Deleted previous builds (`build-camps`, `build-camps-tests`) as requested.
- UI styling overhauled to dark slate/gold Warcraft aesthetic with card containers and structured table columns.
- Alternating zebra row backgrounds, hover highlights, and gold selection borders implemented.
- Database Links card dynamically computes deep URLs for either the official Turtle WoW Database (`database.turtle-wow.org`) or Tortoise 3D Web Viewer (`xian55.github.io/tortoise-db-viewer`), with 1-click text auto-highlight for instant Ctrl+C copying.
- Shift-clicking any row pastes formatted item hyperlinks or entity tags directly into an open chat box (`ChatFrameEditBox`).
- Hovering over rows displays rich `GameTooltip` previews (`SetHyperlink` for items, model/display details for creatures and props).
- Double-clicking any row immediately triggers `Preview` or `Edit`.
- Real-time Transform HUD shows coordinates and orientation in degrees with cardinal compass direction (`Yaw: 180° [S]`).
- Fixed `needSelection` restriction blocking NPC/Item previewing and favoriting.
- Preserved `entityKind` across SavedVariables sessions for favorites and recent history.
- Registered window with `UISpecialFrames` for standard Escape key closing.
- Verified via `tools/verify.ps1` (11 config keys, 22 addon operations, zero modern Lua APIs).
