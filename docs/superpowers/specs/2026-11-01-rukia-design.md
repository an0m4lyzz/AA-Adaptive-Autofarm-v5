# Rukia progression controller

The user's detailed implementation request is the specification and authorizes execution. Prioritize acquisition, then traits, stats and evolution. Use a bundled single-file Luau entry point for Android/Delta. No claim of live compatibility without Roblox evidence.

## Evidence and constraints
Official Roblox title now identifies Update 21. Older unit/trait data is historical, not patch verification. No current client, remote payload capture, inventory schema, or dungeon navigation adapter is available here. Previously observed Fool's Hunt failures remain unresolved. No invented route, recipe, unit ownership, pity or outcome.

## Approach
Selected by implementer: replace the active unsafe controller with small testable modules, bundle them into main.lua, preserve the complete v5 source and instructions under legacy/. Alternatives: patch the coupled 2,875-line v5 engine (retains unrelated placement confirmation and concurrent call hazards); construct an unattended dungeon bot from old signatures (no evidence supports it). Existing v5 settings are read for migration context and preserved byte-for-byte; old macros are never silently certified for the new patch.

## Modules
Core: identity/provenance, resource deficits, goals, budgets, strict action verification, bounded reports, match state machine.
Observer/transport: direct replicated state, optional explicit inventory/resource paths, bounded manual map read, one outstanding request, new-model placement confirmation and exact upgrades. No hooks, GC enumeration or global GUI scans.
UI: seven requested dark touch tabs; one scheduler; all connections owned and disconnected on shutdown. Close stops automation; minimize keeps observer alive. Mutation defaults OFF; no saved armed state.

## Supported contract
Recorded positions are labeled user-recorded, bound to verified stage and exact unit identity; unknown costs prevent placements. Completion requires actual visible result evidence. Replay requires a confirmed free mode and opt-in, never keys/portals/dungeon. Dungeon rooms, chests and all premium mutations remain unavailable until their actual protocols and evidence can be validated. No repeated spending or speculative remote calls.

## Validation
Luau compiler on all active source and generated bundle, pure-core tests for budget boundaries, ambiguous results, unrelated tower additions, timeouts, transitions, stale inventory, goal completion and session cleanup. Live Android performance, new-patch schemas, placements, upgrade feedback and dungeon rewards remain live-test requirements.
