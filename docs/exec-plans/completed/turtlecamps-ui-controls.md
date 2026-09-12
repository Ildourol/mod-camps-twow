# Completed Plan: TurtleCamps UI, Controls & On-Demand Database Expansion — 2026-09-12

## Goal
Implement on-demand, zero-preload database catalogue browsing (gameobjects, buildings, creatures/NPCs, items) and enhance client controls (mouse-wheel nudging, Bindings.xml, step-size selector, visual highlights, degrees HUD).

## Status
- [x] Plan approved by user.
- [x] Implement server on-demand lookup and entity spawning in CampsManager / CampsCommands.
- [x] Add Bindings.xml and update TurtleCamps.toc.
- [x] Enhance TurtleCamps.lua with wheel nudging, highlights, step presets, and type filters.
- [x] Run verify.ps1 static checks.
- [x] Run CTest protocol tests.
- [x] Compile and link mangosd.exe.
- [x] Create walkthrough artifact.

## Evidence & Summary
- Zero duplicate startup caching: queries directly inspect sObjectMgr maps with pagination and debounced filtering.
- Creature/NPC preview and spawn support with safe unattackable flags (UNIT_FLAG_NOT_SELECTABLE | UNIT_FLAG_SPAWNING) and clean low-guid allocation.
- Turtle 1.18.1 (Interface 11200 / Lua 5.0) compatibility preserved with zero modern APIs.
- Bindings.xml integrated with standard Key Bindings menu.
- Mouse-wheel nudging active on canvas frame with modifier keys (Shift for Yaw, Ctrl for Fwd/Back, Alt for Strafe, default for Height).
- Static verification script passed (11 config keys, 22 operations, 0 modern APIs).
- CTest protocol suite passed 100%.
- Server build `mangosd.exe` linked with exit code 0.
