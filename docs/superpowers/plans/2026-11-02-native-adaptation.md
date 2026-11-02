# Native adaptation implementation plan

> Use executing-plans inline for integration and dispatching-parallel-agents for independent modules; each module has its own tests and no shared edits. One fresh whole-change review before publication.

Goal: Native Zeno-like automatic play, existing-run Dungeon flow and opt-in teleport persistence with one simple control panel.

Spec: docs/superpowers/specs/2026-11-02-native-adaptation-design.md

Global constraints: no startup hooks/GC/full GUI scans; no external runtime source; one native mutation; exact observed readback; all automation OFF until enabled; max24 targets; strict user/universe-bound continuation; no automatic key spending. Feature branch zeno-adaptation-v6_2, baseline335eb63. Full baseline202 tests green.

Review focus: unresolved calls across teleport/reload; stale or missing cache schema; concurrent Zeno/native controllers; false placement confirmation; room/chest/spending feedback and limits.

1. Pure automatic combat and observed lane/terrain planner. Files src/autoplay.lua, src/navigation.lua, tests/autoplay.test.luau, tests/navigation.test.luau. Write RED tests before code; GREEN includes all-slot completeness, cap/Unique, affordable opening/upgrades, exact readback, timeout, no lane fallback, geometry bounds/cleanup.
2. Pure Dungeon parser/engine. Files src/dungeon.lua, tests/dungeon.test.luau. RED then GREEN for correct loaded service schema, safe/reward ranks, shop cap/known-price/feedback, shrine skipping, chest consent/counters, death/unknown state, timeout, no key endpoints.
3. Persisted opt-in session. Files src/session.lua, tests/session.test.luau. RED then GREEN for revocation, identity/universe/expiry, queue once, fixed loader, unarmed GUI reload, expected-transition continuation, unresolved-action rejection and malformed files.
4. Native cache/transport and simple UI integration. Files src/core.lua, src/roblox.lua, src/entry.lua, src/ui.lua, tests/adapter.test.luau, scripts/build.py, scripts/check.py. Connect new factories, explicit permissions, serialized actions, manual slot-position fallback/report, auto-follow and stop lifecycle. Preserve previous modules. Add regression tests before each adapter change.
5. Documentation, full tests, independent review/fix pass and lease-protected publication. README.md, TESTING.md, docs/VALIDATION.md, docs/ZENO-ADAPTATION.md. State honest live limits; preserve old entry point. No claim of complete Rukia farming without live evidence.
