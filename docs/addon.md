# Stock Turtle addon

TurtleCamps targets Interface 11200 / Turtle 1.18.1, with the checked-out target's
DungeonClear-1.12 addon as evidence for CreateFrame, backdrop, event globals,
OnClick/OnUpdate and vanilla SavedVariables patterns. Runtime syntax avoids `#`,
string.match/gmatch, table.unpack, C_ChatInfo, C_Timer and modern event parameters.
No Lua executable was found in the inspected PATH, vcpkg or Codex tool directories;
syntax execution/live loading remains unverified. Static checks alone are not Lua QA.

One TOC-listed file registers `/tc` and `/turtlecamps`, creates a draggable panel,
and listens for VARIABLES_LOADED, PLAYER_ENTERING_WORLD and CHAT_MSG_SYSTEM.
Bindings.xml defines native Key Bindings under "Turtle Camps" for toggling the UI,
saving, canceling, grounding, fine translation along all axes, rotation, and cycling step sizes.
TurtleCampsDB stores only sanitized bounded favorites and recent entries; no server
edit token, owner or permission persists through UI reload.

Catalogue/Owned/Camps tabs ask the server for eight rows per page. Dedicated category
filter tabs ([Props], [Buildings], [Creatures], [Items]) query the server's sObjectMgr stores
on-demand with zero client or server preloading. Paging is completely uncapped across all
20,000+ templates with fast navigation (<<, <, >, >>). Favorites/Recent are local lists and
are revalidated by the server when previewing. Search is explicit (button or Enter) with a
quick-clear ('X') button, never one SQL/chat operation per keystroke. Current page and total
pages are clearly displayed.

Preview movement is relative to character facing. Normal step is 0.5 yard,
Shift 2 yards, Ctrl 0.1 yard; presets (0.1y, 0.5y) can be toggled via HUD buttons or keybinds.
Yaw changes use 0.261799 * step radians (~15° or ~3° depending on step); the HUD displays
orientation yaw in degrees (0-359°). Ground calls native height lookup. Save and Cancel
operate on the last acknowledged edit token. Choosing any new item from the catalogue automatically
cancels any previous active preview. Closing the panel queues Cancel. Transfer
clears local state and reconnects when open. A timed-out request is never blindly retried.

Chat spam is completely eliminated: outbound .camp whispers and incoming server protocol
messages are intercepted via ChatFrame_OnEvent and AddMessage hooks, keeping player chat 100% clean.

Mouse wheel nudging is supported directly over the main canvas frame:
- Default Scroll: Z elevation (Up / Down)
- Shift + Scroll: Yaw rotation (Clockwise / Counter-Clockwise)
- Ctrl + Scroll: Forward / Backward translation
- Alt + Scroll: Left / Right (Strafe) translation

The UI features a dark slate/gold Warcraft theme with structured card panels:
- Table rows display discrete columns (ID, Name, Category, Type badge) with alternating zebra striping and gold selection highlights.
- Double-clicking any row instantly previews or edits the entity.
- Hovering over rows displays rich GameTooltip previews (native SetHyperlink for items, model/display details for creatures and props).
- Shift-clicking any row pastes formatted item hyperlinks or entity tags directly into an open chat box (ChatFrameEditBox).
- The Database Links card dynamically computes deep URLs with toggles for Classic Wowhead (wowhead.com/classic), Turtle WoW Database (database.turtle-wow.org), and Tortoise 3D Web Viewer (xian55.github.io/tortoise-db-viewer), with 1-click text auto-highlight for instant Ctrl+C copying.
- The 3D preview model box uses native DressUpModel supporting both GameObjects and Creatures (SetCreature), with camera initialization, interactive dragging, auto-spin, and zoom controls.
- Creatures are categorized by native CreatureType (Beast, Critter, Demon, Dragonkin, Elemental, Giant, Humanoid, Undead, Mechanical).
- The Transform HUD shows coordinates and orientation in degrees along with cardinal compass directions (e.g. Yaw: 180° [S]).
- Native Escape key (UISpecialFrames) closes the window smoothly.

Missing/disabled module is reported by handshake or five-second timeout. A disabled
module still supports server STATUS and administrator RELOAD. Reconnect after
configuration reload. Native PlayerCommands must permit normal-player dot commands.

Live QA must check panel geometry/font clipping at the intended resolution/UI scale,
event/global semantics, response ordering, special characters, all buttons, SavedVariables
roundtrip, timeout/reload and separate-account visibility. See manual-test-plan.md.


