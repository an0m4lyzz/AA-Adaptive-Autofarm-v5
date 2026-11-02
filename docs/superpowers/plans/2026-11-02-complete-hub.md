# Complete native hub implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for native execution, or superpowers:subagent-driven-development if that method is explicitly selected. Implement task by task. Checkboxes track work; none is completed by publication of this plan.

**Goal:** Implement the complete accounted-for Zeno menu scope as original native modules, improve its reliability and usability, and complete the user's Rukia acquisition/build workflow.

**Architecture:** Extend the existing runtime and transport with focused domain planners, a shared evidence registry, one action coordinator and a durable resource ledger. Keep observation/planning pure where possible; the Roblox facade owns bounded game reads and approved endpoint calls. Domain planners propose actions; only the coordinator authorizes dispatch and confirms operation-specific receipts.

**Tech Stack:** Roblox Luau; existing bundled local modules and compact native UI; Python build/check scripts; official Luau CLI/compiler; mocked offline fixtures plus explicitly supervised Roblox/Delta checks.

**Spec:** [Complete hub master plan](../specs/2026-11-02-complete-hub-design.md). Its feature IDs and release labels are authoritative.

## Global constraints

- Preserve the existing `https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua` entrypoint and useful v7 modules/settings migrations.
- Default keys, summons, exchanges, rerolls, shop purchases, consumable use and inventory sales are disabled with cap 0.
- Follow authorization lasts at most **7200 seconds**; session duration may not exceed that original window when following is enabled.
- No startup metamethod hooks, GC scans, full GUI/workspace descendant scans or duplicate workers.
- Preserve one cooperative observer, initially the existing 0.8-second cadence, inventory refresh 4 seconds and UI refresh 2 seconds.
- Geometry remains bounded at 8 lanes × 96 nodes, 96 candidates per missing slot, 6 slots and 24 proposed placements unless measurements justify a reviewed change.
- An uncertain sent action keeps its fence until exact reconciliation or a proven invalidating lifecycle transition; a new round does not erase account spending uncertainty.
- Settings store preferences only. Imports never restore execution permission or spending grants. Evolution needs its separate one-action confirmation.
- Current unverified Rukia/trait/recipe facts cannot authorize farming or spending. No Zeno source/runtime, shared-service placement patch or destructive map optimizer is bundled.
- Every ledger row has a release/task and honest evidence status. A local `true`, successful pcall or a visible button cannot close it.

## Review focus

1. A paid request times out, then the player reloads/teleports: reserve the uncertain debit and block another purchase, including across a new round. T02/T07 tests own this.
2. An unrelated inventory/reward change arrives during a pull/roll/chest request: do not attribute it or retry; selected-target receipts remain required. T04/T10/T11 tests own this.
3. Terrain has multiple lanes/floors and a support unit cannot fit: explain the constraint, bound the search and preserve defense instead of infinite retry. T03/T05 tests own this.
4. A manual stage change, late result or queued old loader lands after Stop: never revive authorization or reuse old quotes. T01/T06/T07 tests own this.
5. Rukia's traits/stats/evolution mechanics differ from historical pages, or selected copy is replaced: refuse historical spending rules and preserve successful target traits/stats. T08/T11 tests own this.

## File boundaries and shared interfaces

Keep existing factories callable while wiring new facades incrementally. Do not rewrite all working controllers in one task. New modules use the existing local-factory style and injected clocks/IO for tests. Register every new module in dependency order in `scripts/build.py`; the generated `main.lua` is never hand-edited.

| File | Responsibility |
|---|---|
| `src/contracts.lua`, `src/evidence.lua` | Shared shape validators, lifecycle identities, supported capability and observation provenance |
| `src/budget.lua`, `src/actions.lua` | Resource permissions/reservations/checkpoints; single action lifecycle/receipts |
| `src/roblox.lua`, `src/inventory.lua` | Existing transport/reader facade; add only named bounded observations and gated endpoint adapters |
| `src/navigation.lua`, `src/threats.lua` | Legal candidate generation and pure current-threat summaries |
| `src/autoplay.lua`, `src/abilities.lua` | Role-aware placement/upgrade/priority policy and observed ability policy |
| `src/dungeon.lua`, `src/flow.lua`, `src/joiner.lua` | Dungeon phases; in-match start/skip/result/cards/sell/exit; lobby mode entry and party policy |
| `src/progression.lua`, `src/catalog.lua`, `src/build.lua`, `src/account.lua` | Goal planner/current verified catalog; selected-copy optimization; account claims/shops/summons/consumables |
| `src/session.lua`, `src/runtime.lua`, `src/entry.lua` | Persisted authorization/recovery; one orchestrator; construction and cooperative scheduling |
| `src/macro.lua`, `src/performance.lua`, `src/reports.lua` | Data-only recorder/player; reversible quality changes; bounded diagnostics/optional notifications |
| `src/ui.lua`, `src/uiadvanced.lua`, `src/core.lua` | Seven primary tabs; advanced feature controls; validated defaults/settings migration |
| `tests/*.test.luau`, `tests/fixtures/*.luau` | Focused pure/mocked tests; sanitized bounded game fixtures, no secrets or source dumps |
| `scripts/build.py`, `scripts/check.py`, `TESTING.md`, `docs/VALIDATION.md` | Bundle registration, guarded API checks and actual evidence record |

Types below are plain validated Luau tables. Define their exact shape once in `contracts.lua`; other modules consume it rather than invent aliases:

- `Context = {accountId, universeId, jobId, roundId, stageId, mode, epoch}`. Actual native job identity is required; `epoch` increments on an invalidating lifecycle change.
- `Evidence = {source, schema, observedAt, context, scope, complete}`. `scope` is `static`, `account`, `round` or `offer`; observation time alone never means server freshness.
- `Observation = {now, context, evidence, roster, towers, battlefield, threats, flow, dungeon, account, goals}`. Unreadable sections are absent, not empty/zero.
- `Capability = {id, schema, requiredFields, status, reason}`. Status is `missing`, `offline` or `live`; live evidence records device/build/mode/date separately.
- `Intent = {id, capabilityId, context, kind, target, quoteToken, cost, expected, deadline, permissionId}`. `cost` maps exact resource IDs to nonnegative maximum debits. Endpoint/arguments are constructed by a fixed native adapter, never imported from configuration.
- `Receipt = {intentId, status, context, observedAt, proof, debits, rewards}`. Status is `confirmed`, `rejected` or `uncertain`; `proof` is operation-specific. Rewards may be absent even when an action is confirmed.
- `Decision = {kind, reason, intent}` where kind is `action`, `wait`, `stop` or `done`; only `action` includes an Intent.
- `RunContext = {sessionId, budgetId, permissionId, deadline, goal, policy}`. The persisted budget ID outlives controller replacement; new allowance requires a new explicit spending review.
- `StrategyProfile = {schema, mapId, rosterSignature, modifierSignature, slots, placement, upgrades, abilities, flow}`. Slots hold ID/copy binding, place/upgrade cap, start wave and order; imported profiles have no permission ID.
- `MacroStep = {sequence, kind, preconditions, target, timing, expected, timeout}`. Allowed kinds are place, upgrade, sell, priority, ability and skip. No Lua source, arbitrary URL or remote name is valid input.

Stable module contracts:

- `Evidence.inspect(capabilityId, view, now) -> {ready, reason, evidence}`; `Evidence.capture(view, limits) -> sanitizedFixture`.
- `Budget.review(policy, view) -> preview`; `Budget.grant(preview, acknowledgement) -> grant`; `Budget.reserve(intent) -> reservation?`; `Budget.settle(receipt) -> state`; `Budget.checkpoint() -> data`; `Budget.restore(data, identity) -> state`.
- `Actions.submit(intent, view, run) -> Decision`; `Actions.observe(view) -> Receipt?`; `Actions.stop(reason)`; `Actions.pending() -> Intent?`. Inject native send and checkpoint functions. Only Actions invokes the send facade after a successful durable checkpoint for account-sensitive actions/continuation.
- Each domain planner implements `Planner.tick(view, run) -> Decision` and `Planner.accept(receipt)` on its instance. Factory injection supplies Contracts, Evidence, Budget read access, settings and logger; domain planners cannot send RPCs themselves.
- `Progression.plan(view, catalog, goal) -> {objective, deficits, route, stop, blocker}`; `Reports.record(event)`, `Reports.render() -> string`, `Reports.exportFixture() -> table`.

`now` uses an injected monotonic clock. Dynamic offer/quote evidence is reobserved before dispatch, bound to the same token/context and at most 2 seconds old; account/Dungeon snapshots are at most 5 seconds old. These are conservative local support limits, not claims about server cache refresh. Static definitions require a matching schema/build identity. Transition deadlines retain the existing 8-second combat and 20-second Dungeon feedback defaults; documented mode-specific deadlines may differ only with fixtures/live evidence. No deadline authorizes resending an uncertain mutation.

## Common task cycle

Every T task below includes its own focused tests and source wiring. Use the existing `check(name, function() ... end)` Luau test style.

- [ ] Add the named failing cases/assertions in that task; run its test file and confirm failure reflects the missing behavior.
- [ ] Implement the task's interfaces and defaults; register required modules and wire the actual entry path, not only mocked factories.
- [ ] Run the targeted file(s), then build and run the full check at the release integration boundary; inspect actual output.
- [ ] Update the feature ledger/evidence, document any specific blocker, review the diff and commit one independently useful change.

Targeted command: `/workspace/scratch/d9e54890a5ea/luau-tools/luau tests/<name>.test.luau`. Full integration command:

```bash
python3 scripts/build.py
python3 scripts/check.py --luau /workspace/scratch/d9e54890a5ea/luau-tools/luau --compiler /workspace/scratch/d9e54890a5ea/luau-tools/luau-compile
git diff --check
```

The existing 397 tests are a baseline evidence record, not an expected permanent total. Update tests that intentionally encode a superseded default without weakening equivalent protection. Tests and compiler success do not establish live game behavior.

## T01 — evidence, current source contracts and batched capture

**Release / features:** R0; supports all rows, especially K01–K04. **Depends on:** baseline inspection only.

**Files:** Create `src/contracts.lua`, `src/evidence.lua`, `tests/evidence.test.luau`, `tests/fixtures/schema.lua`; modify `src/roblox.lua`, `src/inventory.lua`, `src/entry.lua`, `scripts/build.py`, `docs/RUKIA-RESEARCH.md`, `docs/ZENO-MENU-AUDIT.md`.

**Interfaces:** Produce Contracts and Evidence APIs above. Existing adapter outputs are translated once into Observation; preserve legacy readers while upgrading consumers.

- [ ] Test `missing_not_empty`: absent ownership remains unknown; `stale_offer` at 2.1 seconds blocks dispatch; `future_time` blocks; `epoch_changed` rejects old-stage evidence; missing abilities leave basic combat available.
- [ ] Recheck official/current in-game sources and pinned reference source for variant, reward route, recipe, effects and adapter schemas. Record source URL/build/date and certainty per fact; no source means a specific missing capability.
- [ ] Implement manual `Evidence.capture` over already-approved named fields and a maximum 64 KiB sanitized fixture. Reuse current map limits; no GC, arbitrary getter or GUI-tree expansion. Capture is observation-only. Permitted probes are separately listed actions through Actions, not a scan side effect.
- [ ] Run `tests/evidence.test.luau`, adapter/inventory regressions and API checks. Close when missing schema families have named blockers and usable fixture shapes, not when every unknown game fact has been guessed.

## T02 — single coordinator and durable resource ledger

**Release / features:** R0; all spending and concurrent control. **Depends on:** T01.

**Files:** Create `src/budget.lua`, `src/actions.lua`, `tests/budget.test.luau`, `tests/actions.test.luau`; modify `src/runtime.lua`, `src/roblox.lua`, `src/session.lua`, `src/entry.lua`, `scripts/build.py`, `scripts/check.py`.

**Interfaces:** Produce Budget/Actions APIs above. Adapt existing combat/route pending feedback into Receipts, preserving current actual-job transport locks and exact acknowledgement rules.

- [ ] Test `cap_zero_denies`; cap 100 with a 30 reservation leaves 70; unresolved 30 remains reserved after round/reload; a rejected-before-send reservation releases; unrelated +100 inventory does not settle it; cap cannot be reset by Stop/Start. Simultaneous combat/ability/shop intents dispatch exactly one request.
- [ ] Test checkpoint write/read mismatch prevents dispatch; late success after Stop is recorded without sending another action; new round clears only round-local Yen uncertainty; account keys remain fenced.
- [ ] Implement fixed action adapters, fresh preflight, reserve-before-send, durable checkpoint, exact settle and no blind retry. Distinguish queued-unsent cancellation from already-sent uncertainty. Budget grants bind selected operations/resources/copies and identity/expiry.
- [ ] Run actions/budget, runtime/session and actual-entry regressions; ensure ordinary injection and imported settings produce zero RPCs.

## T03 — battlefield, legal positioning and observed threats

**Release / features:** R0 foundation; R2 enhanced policy. A05–A06, G10, supports A01/G08. **Depends on:** T01; action integration T02.

**Files:** Create `src/threats.lua`, `tests/threats.test.luau`; modify `src/navigation.lua`, `src/roblox.lua`, `tests/navigation.test.luau`, `tests/placement.test.luau`.

**Interfaces:** Produce `Threats.summarize(view) -> threats` and `Navigation.plan(view, profile) -> {spots, blockedSlots, evidence}`. Battlefield contains bounded lanes, observed ground/hill hits and occupancy; candidates retain exact world coordinates and evidence context.

- [ ] Test two unequal lanes, stacked floors, hill-only versus ground-only, occupied support area, missing range, truncated geometry and all-candidates-refused. Assert total proposed placements <=24 and a specific blockedSlots reason; no fabricated coordinate or infinite retry.
- [ ] Implement scores for observed lane coverage, support overlap, legal spacing and current unit class; reserve support space before farms. Bind saved spots to map identity and roster/modifier compatibility. A relaxed strategic constraint can change spacing only, never legal terrain/server rules.
- [ ] Add dirty-event caches and bounded enemy aggregation for actual air/shield/boss/type fields; unknown fields remain unknown. Preview renders only selected bounded candidates and cleans up on close/map change.
- [ ] Run threat/navigation/placement and adapter tests; record live accepted/rejected candidate receipts through Actions before claiming better placement.

## T04 — complete Dungeon phases and controlled entry

**Release / features:** R1; D01–D08. **Depends on:** T01–T03, T07 continuation, T08 route verification. Integration with T05/T06.

**Files:** Modify `src/dungeon.lua`, `src/roblox.lua`, `src/runtime.lua`, `src/core.lua`, `tests/dungeon.test.luau`, `tests/adapter.test.luau`, `scripts/check.py`; add `tests/fixtures/dungeon.lua`.

**Interfaces:** Extend Dungeon planner with new-run, recovery and shrine decisions using the common Planner contract. Offer tokens include exact phase/depth/choice/item data; fixed native adapters construct start, enter, buy, accept, continue and chest calls only for validated schemas.

- [ ] Test default zero keys never emits start; explicit key cap 1 cannot start twice across hops. Pending start with an unrelated currency change remains uncertain. Exact key debit/new active-run evidence settles once; deadline never resends.
- [ ] Test shrine known whitelist accepts once, unknown curse skips; changed offer blocks. Shop discount/stock changes requote. Wrong item/chest count or unrelated reward cannot confirm purchase/open. Post-Victory lag waits and never re-enters completed depth.
- [ ] Test confirmed defeat defaults stop; one permitted recovery requires positive observed lives, exact recovery receipt and eligible different phase; exhausted/unknown lives stop. A recovery cannot quietly purchase a fresh run.
- [ ] Implement current loaded item/curse effects, room/shop presets and bounded Dungeon Info. Enforce original key/shop/chest/recovery grants through the shared ledger. Replace the old absolute `dungeon_start` ban only with default-off, capped, preflight/receipt/uncertainty tests.
- [ ] Run Dungeon/adapter/runtime tests; validate one already-started run and at most one separately authorized key entry. Actual Rukia availability remains a T08 evidence requirement.

## T05 — complete equipped-team strategy, targeting and abilities

**Release / features:** R1 basic casts/opening, R2 full strategy; A01–A04/A07, G06–G08. **Depends on:** T01–T03. Supplies combat policy for T04/T06/T09.

**Files:** Create `src/abilities.lua`, `tests/abilities.test.luau`; modify `src/autoplay.lua`, `src/roblox.lua`, `src/runtime.lua`, `src/core.lua`, `tests/autoplay.test.luau`, `tests/entry.test.luau`.

**Interfaces:** Auto and Abilities instances implement Planner; consume StrategyProfile/current threats. Produce placement/upgrade/priority/ability intents with exact tower/copy/cost/cooldown expectations. Effective DPS-per-cost is a labeled estimate with required input evidence, not a raw range multiplier disguised as actual stats.

- [ ] Test all six equipped slots, per-slot caps/start wave/order, two farms, unsellable Bulma metadata, no early damage coverage, support blocked and enemy air/shield unknown. Verify an expensive farm upgrade cannot starve configured minimum defense.
- [ ] Test cheapest, slot, custom, round-robin and marginal-damage ordering on explicit fixtures; missing attack/trait/modifier fields use the documented deterministic fallback. Presets change no permissions and emit no actions.
- [ ] Test first/last/strongest/weakest/closest/farthest exact priority readback; boss disappearance cancels an unsent override. Unknown boss identity does not trigger every unit.
- [ ] Test cooldown/bar/toggle, buff overlap/range, spaced control, stale model and timeout. A global unit event or unrelated cooldown cannot confirm the selected caster. Implement only unit semantics with current evidence; keep per-unit strategy status visible.
- [ ] Run abilities/autoplay/adapter/runtime/entry regressions; measure comparable clears and blocked-slot counts before claiming strategy improvement.

## T06 — complete Game flow, cards and wave actions

**Release / features:** R1 current start/result; R2 remaining controls; G01–G05. **Depends on:** T01–T02, T05; transition eligibility from T09.

**Files:** Create `src/flow.lua`, `tests/flow.test.luau`; modify `src/runtime.lua`, `src/roblox.lua`, `src/core.lua`, `tests/runtime.test.luau`.

**Interfaces:** Flow Planner consumes current vote/card offer tokens, actual stage/mode/outcome and owned-tower state; produces start/skip/sell/card/finish/leave intents. Mode adapters supply exact next/replay cost and eligibility rather than Flow guessing by name.

- [ ] Test vote once per round; repeated offer event dedups; stop-skip-at-wave and mode rules; persistent auto-skip opt-in and restoration after settings/close. A late old-round result cannot increment counters or authorize next.
- [ ] Test sell-at-wave skips known unsellable Bulma and protected towers; exact removal is required, absent model identity blocks. Leave-at-wave uses a bounded confirmed transition, not both replay and lobby fallbacks.
- [ ] Test cards at caps, tied choices, changed token, unknown effects and refusal. All-capped offers stop unless an explicit fallback was reviewed; pcall success does not increase accepted count.
- [ ] Implement finite finish delays, genuine victory/defeat/unknown states and Action serialization for every flow mutation. Restore only persistent setting changes still owned by this session.
- [ ] Run flow/runtime/entry tests; validate actual vote/result/replay readback during the batched free-Story session.

## T07 — session following, loss policy and recovery

**Release / features:** R1 budgets/continuation, R4 recovery; D03, S03, X01–X03. **Depends on:** T01–T02; destination rules from T04/T09.

**Files:** Modify `src/session.lua`, `src/runtime.lua`, `src/entry.lua`, `src/roblox.lua`, `tests/session.test.luau`, `tests/runtime.test.luau`, `tests/entry.test.luau`.

**Interfaces:** Extend current continuation ticket/checkpoint with session/budget/intent IDs and exact expected destination; expose `Session.requestRecovery(view, run, policy) -> Decision`. Preserve existing actual-job queue replenishment, revoke/write-read verification and fixed self-loader.

- [ ] Test A→B→C queue registration, retained/new globals, manual map switch, old queued loader after Stop, wrong account/universe, expired 7200-second ticket and silent write failure. None may revive arm/spend permission.
- [ ] Test retry budget zero/one, repeated confirmed defeats, false freeze caused by stable ping, loading with advancing state and real multi-signal stale deadline. Recovery has a finite count and cannot reset run/time/spend limits.
- [ ] Implement explicit reconnect/follow-exact-ID and optional anti-AFK capability rules; no automatic kick bypass or friend-prefix guessing. Halt unsafe recovery when unresolved account mutations cannot be reconciled.
- [ ] Run session/runtime/actual-entry tests; validate GUI survives intended hops, manual route changes disarm, and Close blocks the next load whenever durable revocation succeeds.

## T08 — current Rukia catalog and goal planner

**Release / features:** R0 research, R1 acquire, R3 full build; K01–K06. **Depends on:** T01; uses T14 measurements.

**Files:** Create `src/catalog.lua`, `src/progression.lua`, `tests/progression.test.luau`; modify `src/inventory.lua`, `src/core.lua`, `src/runtime.lua`, `docs/RUKIA-RESEARCH.md`.

**Interfaces:** Produce Progression API above. Catalog entries include exact variant/recipe/trait/stat/resource IDs, sources, schema/build scope and certainty. Unverified historical entries are display-only and cannot supply Action preconditions.

- [ ] Test old Rukia vs War vs Final IDs; partial inventory never implies absence. Positive exact goal ownership stops all new farming before the next dispatch, including a queued summon/new key.
- [ ] Test changed recipe, missing pity, current trait-pool disagreement, unknown stat thresholds, worthiness and evolution stat-order rules. No historical recipe or Unique odds may become an authorization or guaranteed roll estimate.
- [ ] Implement deficit/route selection using current useful rewards and feasible roster. Rank measured confirmed progress per entry/time with success rate and resource costs; unknown yield cannot outrank a measured route as “best.”
- [ ] Emit trait trade-offs for actual attack role/cap/control coverage, grade/raw-stat targets and verified evolution order. If current data is missing, show the exact required panel/source instead of another general scan.
- [ ] Run progression/inventory/core tests; update source evidence with exact current facts or clearly unresolved fields. This task must not wait for the player to actually roll a rare drop to test stop logic.

## T09 — all mode entry, party and material routing

**Release / features:** R3 Rukia material subset; R4 remaining entry; J01–J06/G03/X02. **Depends on:** T01–T02/T07/T08.

**Files:** Create `src/joiner.lua`, `tests/joiner.test.luau`, `tests/fixtures/joiner.lua`; modify `src/roblox.lua`, `src/runtime.lua`, `src/core.lua`, `tests/adapter.test.luau`.

**Interfaces:** Joiner Planner consumes current unlock/rotation/pad/party/portal observations. Expose `Joiner.transitionPolicy(view, target) -> {eligible, cost, expected, reason}` to T06/T07. Implement a registered per-mode contract rather than a name-based generic paid join.

- [ ] Test pad ownership races, lock/difficulty mismatch, teleport already pending, unknown unlock versus genuinely locked, highest unlocked selection, exact Story destination, Infinite, Legend, Raid and Mansion observed floor.
- [ ] Test Challenge/Daily rotation and useful reward filters; a loss/join attempt does not mark it completed. Portal host selection consumes only the exact authorized item and has a receipt/finite cap.
- [ ] Test host/member exact IDs, missing required party member, cooldown/mode priority and no-fallback-start policy. Prefix/display-name matches are invalid.
- [ ] Implement the verified material routes first; then other modes. Preserve unknown-cost blocking, exact membership/destination readback and single-owner transitions. Mode-specific schemas discovered in T01 remain required.
- [ ] Run joiner/adapter/runtime/session tests; live-certify each enabled entry/exit separately. UI lists unavailable adapters with their specific blocker.

## T10 — Lobby rewards, shops, summons, consumables and codes

**Release / features:** R3 useful resource operations; R4 complete Lobby; L02–L10. **Depends on:** T01–T02/T08.

**Files:** Create `src/account.lua`, `tests/account.test.luau`, `tests/fixtures/account.lua`; modify `src/roblox.lua`, `src/inventory.lua`, `src/core.lua`, `scripts/check.py`.

**Interfaces:** Account Planner accepts an explicitly enabled operation policy and current exact account/offer/copy evidence. Adapter receipts distinguish eligible/claimed, bought/debited, consumed/rewarded, summoned, exchanged, sold and code acceptance. Unknown mutation schemas remain non-dispatchable.

- [ ] Test quest/daily/milestone/pass eligibility and exact claimed receipt. Gold/Gambler shops must handle key `id` versus `id_n`, bought stock, discount changes, quantity and resource identity; no stale/static-price fallback.
- [ ] Test Special/Legacy/Event pool and currency changes; exact pull target hit stops; batch size/total cap/reserve constraints; unrelated unit_added cannot confirm a pull. Exchange and summon have independent resource grants.
- [ ] Test selected capsule decrement with typed reward, changed inventory copy, locked/shiny/trait/goal-protected unit sale and missing receipt. Never sell an ambiguous copy or hide game rejection feedback.
- [ ] Test user/source-verified bounded code list with accepted/already-used/rejected outcomes; unsupported scrape text is not a code. Banner watching/unselection/lobby return cannot bypass exact eligibility or transition caps.
- [ ] Implement each action group behind fixed adapters and separate spend/consume/sale grants. Run account/budget/actions/adapter tests, deliberately replacing any old global endpoint ban with equally strong per-operation protections.

## T11 — controlled traits, stats and evolution

**Release / features:** R3; K02–K05. **Depends on:** T01–T02/T08 and current pool/recipe/cost evidence.

**Files:** Create `src/build.lua`, `tests/build.test.luau`, `tests/fixtures/build.lua`; modify `src/roblox.lua`, `src/inventory.lua`, `src/core.lua`, `src/runtime.lua`, `scripts/check.py`.

**Interfaces:** Build Planner consumes the selected exact owned copy, target trait/stat profile, current quote/worthiness/recipe and a reviewed grant. It produces at most one reroll/evolution intent and consumes fresh inventory feedback before any next roll. Stat targets represent damage minimum, SPA maximum, range minimum and optional required grades/scope.

- [ ] Test already-target trait emits nothing; scarce-resource cap zero; selective stat protection; all-stat roll rejected if it can overwrite protected results; sufficient worthiness and price recheck before each action.
- [ ] Test exact copy replaced/locked/unowned, recipe changes, historical grade thresholds, wrong trait response, token debit without selected-copy result and a late unrelated upgrade. Unexpected output stops immediately with uncertainty; no retry loop.
- [ ] Test evolution preview lacks permission until its separate one-action acknowledgement; missing material/takedown/currency stops; exact consumption plus evolved-copy identity/readback required. After evolution inspect actual trait/stats again, never auto-label perfect.
- [ ] Implement current interfaces only after schema probes; expose target trade-offs and realistic probability/resource estimates from verified mechanics. Reconfirm spending preview when copy/resource/quote changes.
- [ ] Run build/progression/account/budget/actions tests; live probes for reroll/evolution remain individually explicit, finite and optional until the user's materials/target are ready.

## T12 — complete data-only macro lifecycle

**Release / features:** R5; M01–M04/A06. **Depends on:** T02–T07, T13 profile validation.

**Files:** Create `src/macro.lua`, `tests/macro.test.luau`, `tests/fixtures/macro.lua`; modify `src/runtime.lua`, `src/session.lua`, `src/core.lua`, `src/entry.lua`.

**Interfaces:** `Macro.record(receipt, view) -> MacroStep?`; `Macro.captureManual(before, after, kind) -> MacroStep?`; `Macro.validate(data) -> {valid, errors, steps}`; playback implements Planner. Bind stage assignments/copy replacement to StrategyProfile and current map evidence.

- [ ] Test creation/rename/delete/selection/stage assignment; action/timing/sell timing serialization; manual capture ambiguity refuses record. Record only Actions receipts or explicit provable state differences; no claim of invisible game-click capture.
- [ ] Test playback conditions/timing/ignore-timing, unit replacement, known already-applied step, timeout and changed stage. Retry may wait for an unsent precondition; it never resends an uncertain sent action.
- [ ] Test oversize (>256 KiB), >2000 steps, unknown action, NaN/vector invalidity, arbitrary code/URL/remote name, unknown reference format and secret fields rejected. Implement known reference JSON mappings explicitly, with unsupported rows reported before import.
- [ ] Implement data-only import/export/share, bounded overlay and atomic local files. Macro owns the active policy slot; it cannot run beside Auto as a second writer.
- [ ] Run macro/session/runtime/entry tests; validate one short recorded sequence including supported action classes in a free stage before announcing playback support.

## T13 — simple full-feature mobile UI, settings and reversible performance

**Release / features:** every slice; complete at R5; L01/L09, G09, S01–S02, X01. **Depends on:** T01 for statuses; feature controls added alongside their owning tasks.

**Files:** Create `src/uiadvanced.lua`, `src/performance.lua`, `tests/settings.test.luau`, `tests/performance.test.luau`; modify `src/ui.lua`, `src/core.lua`, `src/entry.lua`, `scripts/build.py`.

**Interfaces:** `Performance.apply(profile, handles)`, `Performance.restore(handles)`; `Settings.validate(data) -> {valid, settings, errors}`; `Settings.migrate(data) -> settings`. UI produces reviewed policies, never sends native actions or persists grants.

- [ ] Test settings migrations/defaults, per-account profile schema, malformed/oversize import, atomic backup/reset and import always unarmed. Theme/scale/preset changes emit zero gameplay RPCs.
- [ ] Test performance apply/restore idempotence, external field changes not overwritten on restore, black-screen escape retained, unknown capability disabled and repeated close cleanup. Preserve terrain/lanes/identity; no destructive map delete.
- [ ] Build seven tabs, Goal-first FARM and advanced searchable groups for all ledger rows. Show selected unit/cost/cap/readiness and one concrete next step. Add screen open/zoom only for exposed supported handles; compact our notifications without disabling game listeners.
- [ ] Test touch layout manually at tablet portrait/landscape sizes: scroll, safe-area clamp, drag/minimize/restore/Stop. Keep supported/experimental/blocked labels derived from Evidence, not cosmetic switches.
- [ ] Run settings/performance/core/entry tests; document actual layout/quality measurements and unsupported executor capabilities.

## T14 — complete reports, fixtures and optional webhook transport

**Release / features:** R1 local reports; R5 notifications; R01/W01/K06. **Depends on:** T01–T02; domain receipt producers as they land.

**Files:** Create `src/reports.lua`, `tests/reports.test.luau`; modify `src/runtime.lua`, `src/entry.lua`, `src/ui.lua`, `src/core.lua`.

**Interfaces:** Produce Reports APIs above plus `Reports.queueNotification(event, consent) -> status`. A bounded outbound HTTP adapter is distinct from gameplay transport and requires its own explicit destination/send permission.

- [ ] Test duplicate game_finished counts once by round ID; unknown/contradictory result remains unknown; currency delta without receipt is observed delta only; chest rewards do not inflate match rewards; no Rukia count zero from partial inventory.
- [ ] Test retention at 500 log records and rendered/export report <=64 KiB; UUID/secret URL redaction; action uncertainty, feature statuses and blockers included. Keep all-time counters separately bounded rather than unbounded raw events.
- [ ] Test webhooks off/no destination send zero calls; explicit test permission sends only the test; 429/timeout/error produce bounded backoff, never repeat gameplay. Cap notification attempts at 3 per event and queue length at 20; exclude secret destination from shared config/report.
- [ ] Implement result/material/trait/stat/evolution summaries, sanitized capture fixture export and comparable stage/team/modifier performance records. Network delivery failure cannot change gameplay success status.
- [ ] Run reports/runtime/entry tests; actual outbound test is performed only when the user explicitly enables that destination, not as part of implementation verification.

## T15 — slice integration, evidence promotion and release

**Release / features:** each R1–R5. **Depends on:** the release's task subset; R0 alone is internal and does not advertise gameplay completion.

**Files:** Modify `tests/entry.test.luau`, `scripts/check.py`, `README.md`, `TESTING.md`, `docs/VALIDATION.md`, `docs/ZENO-ADAPTATION.md`, the master-plan feature ledger and generated `main.lua`; pin the prior validated release for rollback.

**Interfaces:** Actual entry integrates Observation → Progression/domain decisions → Actions → receipt → report/checkpoint. No disconnected alternate implementation satisfies a feature.

- [ ] Add integration cases for the release's complete slice, including mutual exclusion, settings/Stop, denied budget, missing fields, deadline and authorized continuation. Reconcile every ledger row touched against real source/wiring/tests.
- [ ] Run the full build/check command, inspect output and independently review the whole slice. Correct failures before repeating live checks; do not rerun unchanged checks without a reason.
- [ ] Execute the master-plan's batched free-stage, Dungeon, per-mode/per-spend and tablet gates as applicable. Keep a dated matrix of what actually passed, blocked and remained untested. Do not mark a rare reward obtained without observation.
- [ ] Before publishing, fetch the current remote main SHA and compare to the inspected parent; integrate concurrent changes and revalidate. Publish only the intended files; preserve the exact loadstring and a rollback bundle. Record commit, test output and known limits.

## Dependency and handoff checklist

- [ ] R0: T01 → T02; T03 baseline observations and T08 current research; T13/T14 minimal status/capture. Verify no new paid action is enabled.
- [ ] R1: T04 + T05 basic opening/casts + T06 start/result + T07 continuation + T08 acquisition policy + matching T13/T14 → T15. T04 may use manually entered existing run until its entry capability is genuinely verified; never close D02 without that adapter.
- [ ] R2: T03/T05 full strategy + T06 remaining Game controls + matching UI/reports → T15. Compare against the R1 baseline using the same stage/team/modifiers.
- [ ] R3: T08 verified build catalog → T09 needed material routes + T10 useful resource shops + T11 protected optimization/evolution → T15.
- [ ] R4: remaining T07 recovery + T09 mode/party + T10 Lobby → T15. Certify routes independently.
- [ ] R5: T12 macro + remaining T13/T14 options → T15 full ledger and tablet soak. No excluded implementation method is relabeled as a reproduced feature.

Review result for the master design: a fresh builder check returned **“nothing important left.”** Self-review covers every feature ID with an owning task, consistent interfaces and tests for the five cross-cutting failure classes above. That review checks the plan's completeness, not the runtime's correctness.

Execution has not started under this plan. The immediate next implementation target is the R0/R1 path, not another menu-only patch. Current live-schema gaps remain explicit work and can block an individual feature without being mistaken for completion.
