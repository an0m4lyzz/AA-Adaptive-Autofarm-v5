# Validation and review

Validated locally with the official Luau CLI at source revision 2a3d8937c19c8fd9f7b72b6ec9068c62760e6588. Run scripts/check.py to reproduce with that compiler/interpreter.

- 38 pure-core tests: exact identity, unknown versus zero, budget boundaries, target protection including multiple traits, raw-grade scope, fresh roster, unrelated/existing tower rejection, outcome ambiguity, timeouts, stop-on-goal, Dungeon replay prohibition, transitions, log bounds, persisted settings, level readback, free replay limits, asynchronous map readback, scoped permission, selected-copy retention, battle-only ownership rejection, cost modifier/price changes and preserved fallback costs.
- 48 mocked Roblox tests: observer/transport/metadata behavior plus explicit-only cache connection, capabilities, loaded status, cache schema and refresh, pending/timeout/closed-instance handling, synchronous native deadline expiry, registry-entry removal, match cash, loaded level/definition data, scaled costs, stale level guards including nil gaps, bounded map retries, late reply rejection, late-loading Units, snapshot isolation and redacted combat reports.
- 16 pure inventory-parser tests: UUID-keyed ownership, actual equipped slots, potential/attack separation, traits, zero versus missing resources, owner validation, strict UUID and slot aliases, bounded reads, structural cache lookup, no metamethod calls, disappearing schema and registry replacement.
- All active source modules and main.lua compile with Luau; bundle is reproducible; active forbidden-API checks and unchanged loader checks pass.
- Archived v5 main.lua is byte-identical to the audited base revision.

A fresh independent reviewer found four Important problems: replay identity arriving asynchronously, stale stage after an early reset, capped unit scans masquerading as complete, and replay/cost confirmations carrying to other stages. Each now has regression coverage and was corrected. Selected-copy fallback, classified Minor by the reviewer, was corrected because it could falsely satisfy a chosen-copy goal. Passive outcome flicker and unreadable finished-state handling also have regression coverage.

No direct Roblox, Delta or Android session was executed from this workspace. User reports establish that the UI/report path, account-balance observer and client-cache parser execute; v6.0.3 recognized 77 owned records and six equipped slots in the reported session. Native memory/FPS, server freshness, full inventory coverage, combat data semantics, actual placement, abilities, drops, Rukia availability and complete progression remain unverified. Local tests are not evidence of successful unattended farming. Hosted CI completion is separate from local results.

## Implementation decisions

- Use a new controller and retain v5 as rollback, because patching the old coupled state/action/UI loops would retain the false-positive and concurrency hazards. Cost: legacy card/equip/queue tools are archived instead of active.
- Use player-replicated Instances and recorded maps by default; provide a manual loaded-Loader cache reader for the reported table-based layout. Cost: native cache isolation and API availability in Delta remain unverified.
- Block premium mutations and dungeon navigation without a verified current adapter. Cost: progression cannot be unattended yet.
- Bind confirmations to stage/mode/place; do not restore them from settings. Cost: manual reconfirmation on a different stage or new injection.

## v6.0.1 live report follow-up

The user's first report verified that the UI/report path executes, but all four inventory Instance candidates were absent. It does not establish ownership, equipped roster or current game compatibility. That lobby contained _UNITS and _wave_num, exposing a false match-context assumption. Added a regression-tested lobby guard and explicit manual metadata diagnostic. The diagnostic is an evidence-gathering step, not a fix for the unknown current inventory schema. Complete current progression remains unverified.

Independent review of the follow-up caught unrelated replicated folders being enumerated before filtering and incomplete redaction of braced/prefixed UUID names. Both now have failing-then-passing regression coverage. The diagnostic omits values and source and does not change readiness.

## v6.0.2 live report follow-up

The v6.0.1 report verified lobby classification and identified player/_stats numeric account fields, src/Loader, src/client and gui/_R. It also reproduced budget starvation before client service entries. Added regression-tested client-first traversal, prompt/settings filtering and separate typed account balances. The unclassified resource field never supplies match cash. Existing UUID redaction and no-module-execution constraints remain tested. Total offline tests: 57. No current owned/equipped unit schema is verified by this patch.

Independent review caught reverse insertion discarding priority children near the global node cap. The regression reproduces a deep client branch crowded by effect siblings; the corrected insertion retains the priority prefix within remaining capacity.

## v6.0.3: targeted client-cache reader

The v6.0.2 live report confirms the wallet reader and opaque numeric client module names; metadata traversal still does not expose inventory. Historical primary code identifies Loader closure caches holding named client-service exports. Added an explicit manual reader, current-registry binding and a pure typed parser; no service getter or initializer is explicitly invoked. Detailed references, native require/VM limitations and live-test instructions are in CLIENT-CACHE.md.

Independent review found conflicting UUID aliases and conflicting numeric/string slot aliases being accepted. Both were reproduced with failing tests and corrected. Exposed owner errors, registry removal/replacement, stale schemas, synchronous deadline expiry and battle-only acquisition claims also have regression coverage. Total offline tests: 85. The code compiles and bundles reproducibly; live inventory compatibility is still unverified. Cache observation time is not proof of server freshness or continued ownership of a wholly replaced Loader registry.

## v6.0.4: combat adapter fixes

The live v6.0.3 report supplies the working inventory path. Code comparison with the primary Game/autoplay implementations identified missing match cash, cached level and definition-cost inputs; the previous broad metadata scan could not supply them. Added manual reported-loaded Units retrieval, read-only current Loader.LevelData, typed match-only resource cash, explicit modifier costs and a focused combat report. No new startup introspection, premium endpoints or generated coordinates were added.

Independent review reproduced four Important problems before publication: completed bad map responses preventing retry, a missing endpoint exhausting actual-request budget, inventory-first connection missing later-loaded Units, and a nil gap bypassing the stale-level guard. Each received a regression and correction. A further late map response arriving before poll could bypass the elapsed timeout; a regression now rejects it directly at completion. Recorded cost/scale changes disarm readiness, disappearing modifiers clear derived costs, and fallback cost settings persist. Total offline tests: **102**. Current game data, actual combat acceptance and Android performance still need the single free-match test in TESTING.md.
