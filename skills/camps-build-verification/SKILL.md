---
name: camps-build-verification
description: Reproduce camps module discovery, static checks, compile and final mangosd link using a validated CMake build tree.
---

# Camps build verification
Purpose: obtain precise build evidence without deploying.
When to use: verifying server/addon/SQL changes or preparing a review handoff.
Required inputs: source paths, Git status, CMakeCache.txt, installed compiler/dependency
paths, requested target/configuration and docs/build-and-test.md.

## Workflow
1. Inspect CMAKE_HOME_DIRECTORY, generator, architecture, configuration, install
   prefix, MODULES, per-module overrides, BUILD_PLAYERBOTS and Turtle flags.
2. Preserve existing valid builds; reconfigure only for changed inputs/options.
3. Confirm canonical src discovery and generated Addmod_camps_twowScripts invocation.
4. Run stale-symbol, config-key, SQL-directory/schema and TOC/load-order validation.
5. Compile touched sources and link mangosd; an archive-only success is insufficient.
6. Run the standalone protocol tests and examine final Git status/reference hashes.
7. Record exact commands, failures fixed, warning provenance, binary location and
   untested bots/client/DB configurations. Keep live acceptance separate.

Expected outputs: passing checks or concrete blockers, logs and updated verification report.
Verification checklist: no stale loader/core symbols, correct SQL world target,
native dependencies, actual server link, artifact path, no accidental reference edits.
Stop/blocker conditions: unavailable dependency/toolchain prevents its check; report
the precise failure and continue independent checks. No install/deploy/live SQL or
server restart unless the user separately authorizes those operations.
