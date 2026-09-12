# ADR-004: live preview with bounded button controls
Context: MSUIClient can own world gestures and raycast; stock Lua evidence does not
provide those APIs. Native Tortoise move/turn already uses Map removal/re-addition.
Decision: server-authoritative live preview, value original/working transforms,
character-relative buttons, yaw/height/snap, explicit Save/Cancel and token checks.
Alternatives: client synthetic ghost/raycast, immediate save on each movement.
Consequences: nearby players see previews; movement is deliberately paced; no scale
or free 3D drag. Existing unsaved edits survive a crash as the old DB pose. Evidence:
Commands.cpp gobject handlers, GameObject.cpp model APIs, vanilla DungeonClear addon,
MSUIClient DevWindow.Edit working-copy/gesture lifecycle.
