# Source responsibilities

| File | Responsibility |
|---|---|
| src/CampsProtocol.h/.cpp | Engine-independent framing, strict numeric parsing, escaping |
| src/CampsManager.h | Value models, bounded state containers, manager interface |
| src/CampsManager.cpp | Config/cache loading, safety, map lifecycle and persistence |
| src/CampsCommands.cpp | Authenticated request routing, permissions, camp operations/undo |
| src/CampsScripts.cpp | Native registration and lifecycle hooks |
| addon/TurtleCamps/TurtleCamps.lua | Stock UI, private transport, favorites/recent |
| data/sql/world/20260911_01_camps.sql | Forward module schema |
| tools/prepare-transactional-tables.sql | Separate operator-reviewed native engine preparation |
| tools/diagnostics.sql | Read-only integrity report |
| tools/verify.ps1 | TOC/config/protocol/API static verification |
| tests/protocol_tests.cpp | Executable strict-parser and fuzz regression checks |

Declarations/call sites in the target and reference repository revisions are indexed
in references/REFERENCE_SOURCES.md. Documentation has distinct roles: architecture
describes lifecycle, protocol the wire contract, database operations/recovery,
catalogue-safety admission, addon client limits, compatibility native APIs,
build-and-test reproducibility, manual-test-plan live acceptance. ADRs record
nontrivial choices; the execution plan tracks evidence and unfinished acceptance.
