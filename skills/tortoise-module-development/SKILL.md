---
name: tortoise-module-development
description: Develop this standalone camps module against verified local Tortoise declarations and native lifecycle contracts.
---

# Tortoise module development
Purpose: keep camps changes native, standalone and reviewable.
When to use: changing server hooks, catalogue, map objects or persistence here.
Required inputs: project AGENTS.md, target core path/revision, current Git state,
the affected operation and its protocol/database requirements.

## Workflow
1. Read project guidance and relevant compatibility/architecture documentation.
2. Inspect target module discovery, loader naming and existing Git changes.
3. Open current declarations AND native callers; do not infer APIs from a foreign core.
4. Trace ownership: command/world phases mutate manager state; teleport hooks queue IDs.
5. Implement in module source first; keep config, SQL and wire behavior consistent.
6. Validate failure/cancel paths, then run tools/verify.ps1, protocol tests and link mangosd.
7. Record source identity, changed files and explicit live-testing gaps.

Expected outputs: code, necessary migration/config/protocol changes and focused docs.
Verification checklist: native APIs, world-thread ownership, no retained runtime
pointers, safe admission, bounded state, compile AND final link, no reference edits.
Stop/blocker conditions: an essential missing native hook requires a core change;
document the exact seam and ask before editing core. Missing build dependencies
limit verification; report them precisely while finishing independent module work.
