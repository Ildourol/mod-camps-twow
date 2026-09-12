# Catalogue admission

The native GameObjectInfo map is already loaded by ObjectMgr. Copying this bounded
cache avoids an unnecessary second gameobject_template SQL read. Overrides load
once per module startup/reload. Search is deterministic entry order, eight rows/page,
ASCII case-insensitive name substring, exact numeric entry, optional exact category.

Admission uses the target's named `GAMEOBJECT_TYPE_GENERIC`. No guessed type numbers
or foreign type definitions control authority. It further requires:
- Valid nonzero display ID in sGameObjectDisplayInfoStore.
- Finite template size >0 and <=10; size remains the native shared-template value.
- No ScriptId, PhaseQuestId, money loot or quest/involved-quest relation.
- Every generic raw payload word zero except index 3, the verified visual large flag.
  This excludes tooltip/highlight, server-only, float-on-water, quest and unknown data.

Doors, chairs with interaction, chests, traps, spell foci, transports, fishing nodes,
rituals and all other non-generic types are excluded even for GMs. There is no unsafe
advanced mode in version 1. A safe display/model alone is not proof of safe gameplay.
Global core/zone hooks still run normally; the module does not bypass native hooks.

`camps_catalog_override`: entry (PK), enabled, player_allowed, category, notes.
An override cannot elevate a rejected type into the cache. Missing override means
an otherwise-admitted template is player-allowed. Operators should curate before
enabling Camps.Players on a realm with custom template behavior. GM-only here means
safe but intentionally denied to ordinary players.

Categories are independent: explicit nonempty override, then deterministic name
keywords, then Miscellaneous. Rules include Shelter, Buildings, Furniture,
Fire & Light, Storage, Crafting, Banners, Food & Provisions, Nature, Yard,
Atmosphere. These are presentation only. Category requests must match the full
label, ignoring ASCII case; they never influence security.

Hard bounds: 20000 native safe records, 20000 overrides, query 48 bytes, category
32 bytes, eight response rows. Save/Begin recheck the current native template.
If an administrator changes/reloads templates externally, cancel editors and run
module reload before continuing; the module does not intercept native template edits.
