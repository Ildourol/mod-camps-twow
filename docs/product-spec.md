# Version 0.1 scope

The principal workflow is search -> select -> preview -> adjust -> Save; subsequent
owned selection -> Edit -> adjust -> Save or Cancel. It is a mouse-operated button
editor on the stock client, with temporary server-world previews.

Personal camps are account-wide, optional, and disabled by default. Claim is on
current ground on maps 0/1. One camp/account, configurable radius/cap/spacing,
public-visit opt-in, camp travel, accessible camp list, and confirmed removal.
Travel has a configurable 60-second default per-active-character cooldown shared between Go/Visit.
It is not persisted through logout/reload and is not an account-wide hearth cooldown.
Forbidden map/zone/area ID lists restrict normal placement and travel destinations.

GM world building defaults on for authenticated SEC_DEVELOPER users when enabled.
It permits safe module-owned scenery on non-instanced maps without a personal camp.
It does not expose arbitrary native world spawns, unsafe types or unrestricted
coordinate teleport/spawn. All placement stays within 60 yards of the builder.

Required editor features implemented: dynamic bounded catalogue, name/entry/category
search, metadata/pages, forward/side/height/yaw controls, fine/coarse increments,
ground snap, new save/cancel, existing edit/restore, nearest/facing/list selection,
duplicate/delete, bounded undo, persistent ownership and lifecycle cleanup.

Explicit omissions: PlayerBot gathering, client raycast, direct world dragging,
ghost translucency, personal phasing, scale, interactive furniture/crafting,
GM unsafe catalogue and per-character camp mode. These are not negotiated capabilities.
Safe-type filtering is fixed to generic decoration rather than an optional UI type filter.

All gameplay acceptance in docs/manual-test-plan.md remains pending. This is a
reviewable first implementation with a successful server link, not a live-tested release.
