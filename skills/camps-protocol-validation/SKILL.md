---
name: camps-protocol-validation
description: Validate the paired TurtleCamps stock Lua and server wire contract, malformed input and edit-state security.
---

# Camps protocol validation
Purpose: prevent addon/server drift and authority errors.
When to use: changing operations, responses, transport, tokens or client state.
Required inputs: docs/protocol.md, server parser/router, addon, representative
valid/invalid requests and the available test/runtime environment.

## Workflow
1. Confirm version 1 and tilde framing on both sides; percent escaping is one-pass.
2. Check exact arity, positive/overflow IDs, finite bounded decimal deltas, query and
   message sizes. Include encoded delimiters/control bytes and malformed percent forms.
3. Trace HELLO/reload, request replay, stale token, map transfer and timeout transitions.
4. Verify identity/security derives from WorldSession and all IDs resolve ownership.
5. Test server admission/search limits and addon one-outstanding bounded queue.
6. Verify private self-whisper fallback when module absent or PlayerCommands is off.
   Do not introduce a raw-pipe separator that conflicts with native link validation.
7. Run CTest/parser fuzz checks and tools/verify.ps1; use the manual plan for live state.

Expected outputs: paired implementation, updated wire docs and focused regression evidence.
Verification checklist: no auto-retry of mutation, no public traffic, all response
fields consumed, permissions rechecked, no DB writes during deltas, state cleanup.
Stop/blocker conditions: required private consumption needs a missing core seam or
client API is unverified. Keep a proven fallback; do not claim custom-client raycast
capabilities for Lua. Never count a static parser test as live permission acceptance.
