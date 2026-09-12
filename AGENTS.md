# mod-camps-twow

Build a standalone Tortoise module and stock Turtle 1.18.1 Lua camp editor.
Canonical integration directory: modules/mod-camps-twow; addon: TurtleCamps.

## Source map
The sibling tortoise-wow-extended tree is the authoritative target. Sibling
MangosSuperUI, MSUIClient and WOW_Legends_Server_Source are read-only references.
See docs/references/REFERENCE_SOURCES.md for absolute paths and pinned revisions.
Priority: explicit user request, checked-out target, its build evidence, native
module examples, reference behavior, upstream documentation, foreign concepts.

## Engineering constraints
- Keep implementation standalone. Never patch a missing core seam silently;
  document exact evidence and obtain direction before a necessary core change.
- Inspect declarations and callers before adopting any target API.
- World thread owns manager state and all native object mutations. Teleport
  notifications may originate on map workers; queue copied identities only.
- Long-lived state holds values and GUIDs, never Player/Map/GameObject pointers.
- Authenticated server security controls authority. Client input is untrusted.
- Preview movement never writes the database. Native spawn persistence and
  ownership metadata share the world database transaction.
- Reference code is behavioral evidence; inspect licenses before copying.
- Preserve unrelated Git changes. Do not deploy, install, restart or apply SQL.

## Workflows
Read ARCHITECTURE.md for lifecycle; docs/protocol.md for the wire contract;
docs/catalogue-safety.md for template admission; docs/database.md for persistence.
Use tools/verify.ps1 for static checks and docs/build-and-test.md for builds.
Repository workflow skills live in skills/; these are not an invented autoload path.

## Done criteria
Implement server and addon together, validate malformed/stale/unauthorized input,
confirm module discovery and compile/link where available, audit final changes,
and explicitly distinguish source checks from live tests. Keep execution status
in docs/exec-plans/. Never claim live gameplay validation from compilation.
