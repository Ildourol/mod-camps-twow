# Licensing and reference use

This module/addon implementation is distributed under GPL-2.0-or-later; see LICENSE.
It is an original implementation using the target's native API and persistence
patterns. Reference architecture is not a runtime dependency.

| Repository | Consulted concepts/files | Observed license | Reuse / attribution |
|---|---|---|---|
| Tortoise target | Native gobject commands, module loader/hooks, GO/cache/database APIs | GPL version 2 text; native source notices allow v2 or later | Native implementation patterns; preserve target project attribution |
| MangosSuperUI | gameobjects.js; WorldEditorController.cs | GPL version 2 text | Behavioral/reference review only; no code copied |
| MSUIClient | creator/world/editor state and GameObject rendering files | GPL version 2 text | Behavioral/reference review only; no C# code copied |
| WOW Legends server mirror | SOURCE_MANIFEST; mod-wowlegends/wowlegends_warbandcamp.cpp | Module explicitly AGPL-3.0-or-later | Behavior only; no AGPL source copied or linked |
| WOW Legends player addon | Core/Warband.lua, Data/WarbandProps.lua, UI/Tabs/Warband.lua | MIT per upstream repository | Behavior only; no Lua/catalogue copied |

Credit to Tortoise/vMaNGOS contributors for native systems, WOW Legends for camp
concepts, and Yafrovon's MangosSuperUI/MSUIClient for authoring/editor concepts.
Full paths/revisions and the ignored Warband source hash are in
references/REFERENCE_SOURCES.md. No proprietary client assets are included.

The GNU license text is reproduced from the target's LICENSE; it is license text,
not copied game implementation. Downstream distributors remain responsible for
applicable license notices and corresponding-source obligations of their full build.
