# [K] complete hub master plan

Date: 2026-11-02. Status: proposed delivery plan; no new runtime feature is claimed by this document.

## The result we are building

One original, mobile-first Anime Adventures script that can run the equipped team, complete supported farming loops, and pursue a selected progression goal. Rukia acquisition comes first, followed by trait, stats, materials and evolution. Every Zeno menu feature has a disposition in the ledger below; an absent adapter stays visible as unfinished work.

The normal flow is **choose goal → review team, route and limits → Start → observe progress or one actionable blocker**. Advanced controls remain available without being required for a first run. Repeated play continues until the goal, session limit, resource limit, failure limit or Stop. It must never turn an uncertain response into another purchase or another key-consuming entry.

The target is measurable improvement over the reference: clearer controls and failure explanations, verified action outcomes, fewer failed placements, better clear rates with the same team/stage/modifiers, efficient goal progress, and stable tablet performance. These are acceptance measurements, not results already obtained. No universal best position, guaranteed clear, guaranteed drop or completion date is promised.

## Starting point and evidence

- Our published baseline is **v7.0.0**, commit [`8d663bf`](https://github.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/commit/8d663bf46c8affc9d8189d961625dc30637beb24). Its validation records 397 offline tests; its new combat/Dungeon/teleport behavior has not passed live Roblox/Delta validation.
- Existing modules already implement experimental placement, upgrades, observed map/path planning, some Story transitions, existing-run Dungeon decisions and opted-in teleport following. Preserve those modules and regressions; extend them through focused adapters.
- The user's v6 reports provide narrower live evidence: six equipped units were detected; the exact Bulma placement and upgrades were observed. They do not validate v7 clears, all equipped units, Rukia farming or Android stability.
- Zeno reference: [`tfooio/zeno-hub-dist@5a3f913`](https://github.com/tfooio/zeno-hub-dist/tree/5a3f913c937159078df5c08099ca5f37c58229c1), inspected 2026-11-02. The [menu audit](../../ZENO-MENU-AUDIT.md) records the schemas, endpoints and weaknesses. No license was found in the inspected source. Build original implementations; do not bundle or execute Zeno.
- **Current Rukia availability, exact variant, acquisition rate/pity, evolution recipe, current trait effects/odds and reroll prices remain unverified.** The [research file](../../RUKIA-RESEARCH.md) contains historical information, not current spending authority. Revalidate before selecting a Rukia route or spending.

## Approach

Extend our native modules with one coordinator, evidence-aware adapters and a shared spending ledger. This preserves useful work and gives every feature the same stop, feedback, persistence and reporting rules.

A wholesale fork would inherit licensing uncertainty, global hooks and competing workers. Loading both hubs would retain two writers and hidden teleport behavior. Neither fits the user's mobile stability and independent-script requirements. The native extension is the engineering recommendation; the user has requested the complete feature scope, not approved a claim of complete parity today.

## Delivery order

Internal prerequisite work is R0. Each subsequent release must deliver a usable loop and pass its own gate. Release labels express order, not calendar estimates or announced version numbers.

| Release | User-visible result | Included work | Exit evidence |
|---|---|---|---|
| R0: foundation | One coherent status/capture report; current route and missing fields identified | Capability ledger; action/budget contracts; current-game research; one batched observation tool; basic goal UI | Existing suite retained; missing/stale schemas cannot arm; no gameplay release just to rename labels |
| R1: Rukia acquisition loop | Start a verified Dungeon route, run the team, navigate rooms, handle permitted shops/shrines, open permitted final chests, repeat within limits and stop on observed Rukia | Existing-run regression; optional verified/capped key entry; basic observed abilities; forward room flow; loss policy; Dungeon Info; following; acquisition/reward reports | Free-stage combat smoke test plus one supervised authorized Dungeon run; exact phase/receipt evidence. Rukia label enabled only if current reward route is verified |
| R2: stronger play | Better use of the whole equipped team against the observed map and modifiers | Multi-lane placement scores; support/farm reservations; caps/order/wave gates; upgrade methods; boss targeting; ability rotations; cards; skip/sell/leave rules | Comparable stage/team/modifier measurements; no regression to failed-placement loops or unsellable Bulma assumptions |
| R3: complete Rukia build | Acquire the needed reroll resources/materials, protect the chosen copy, reach configured trait/stat targets, and explicitly confirm evolution | Current recipe/build data; required Challenge/Infinite/Portal join paths; inventory accounting; budgeted rerolls; evolution preview/receipt; target-aware stopping | Selected-copy and resource-change receipts; old target traits/stat successes preserved; live checks for each spending action before support status |
| R4: remaining mode and Lobby parity | General joiners, party rules, rewards, shops, summons/capsules/codes, safe recovery and complete Game controls | All remaining mode adapters; exact host/member IDs; rotation/unlock checks; optional capped account actions; banner watching; reconnect policies | Every enabled route has its own entry, outcome, exit, cost and receipt contract; one mode passing does not certify the others |
| R5: full workflow and final polish | Record/replay/share strategies, full settings/mobile options, optional notifications, integrated reports | Data-only macro system; profiles/migration; remaining UI options; reversible performance controls; opt-in webhook transport; soak/rollback | Full ledger reconciled; live-tested features individually labeled; regression, tablet and teleport validation completed for the release |

Mobile controls, diagnostics, cleanup and tests ship with every release. R5 finishes them; it does not postpone them. R3 implements the material routes Rukia actually needs before R4 expands to unrelated stages. If research finds a different current Rukia route, change R1's route adapter before spending; do not keep farming Dungeon merely because the UI says Rukia.

## Complete feature ledger

**Baseline states:** `O` = native implementation exists with offline evidence only; `P` = partial native implementation; `N` = not implemented; `H` = historical/uncertain game data. These are not live-support badges. Release/task references identify where missing work belongs. T numbers refer to the [implementation plan](../plans/2026-11-02-complete-hub.md).

| ID | Menu / feature | Baseline | Target release / task | Completion evidence or explicit replacement |
|---|---|---|---|---|
| L01 | Open native game screens; camera zoom | N | R4 / T13 | Screen exists; bounded open/close; restore camera preference |
| L02 | Quests, daily missions, level milestones, battlepass claims | N | R4 / T10 | Exact eligible ID becomes claimed; unrelated rewards cannot confirm it |
| L03 | Gold Shop, stock, quantity, selected-item buying | N | R3–4 / T10 | Fresh effective price, remaining stock, exact item delta and debit within cap |
| L04 | Gambler's Shop and material purchases | N | R3–4 / T10 | Exact shop key, currency and stock; useful materials tied to current recipe |
| L05 | Owned stars/capsules and reward reveal | N | R4 / T10 | Selected consumable decrements once; correlated typed rewards; separate consumption consent |
| L06 | Special/Legacy/Event summons; target list; banner watch | N | R4 / T10 | Current pool/currency/price; exact pull receipt; stop-on-target and cap |
| L07 | Legacy currency exchange; gem reserve; batch size | N | R4 / T10 | Fresh conversion quote; separate exchange/pull budgets; no accidental use of reserved currency |
| L08 | Summon target unselection; newly featured target return | N | R4 / T10 | Exact rotation/target eligibility; one authorized transition, no summon after goal |
| L09 | Summon reveal suppression; auto-sale filters | N | R4 / T10,T13 | Preserve game feedback; compact our own notifications. Optional sale requires explicit eligible-copy policy, locked/shiny/trait/goal protections and receipt; shared listener suppression is not reproduced |
| L10 | Redeem codes | N | R4 / T10 | User-provided or source-verified code; bounded list; accepted/already-used/rejected distinguished |
| J01 | Story World/Act/Hard/highest unlocked | N | R3–4 / T09 | Exact unlocked level, owned pad, selected difficulty and destination |
| J02 | Infinite, Legend, Raid | P | R3–4 / T09 | Current combat exists partially; add exact entry/cost/repeat/exit contract per mode |
| J03 | Normal Challenge reward filter; Daily Challenge | N | R3–4 / T09 | Actual rotation/reward ID; record completion after confirmed win, not join attempt |
| J04 | Infinity Mansion floor/difficulty progression | N | R4 / T09 | Observed reached/unlocked floor; exact start and next-floor eligibility |
| J05 | Portal selection/host/join and finite inventory use | P | R3–4 / T09 | Selected owned portal, consumption permission, accepted entry and exact next inventory |
| J06 | Mode priority, cooldown, party follow and host wait | N | R4 / T09 | Exact user IDs; membership policy explicit; no start when required members are missing |
| D01 | Existing run rooms, compulsory boss/end phases | O | R1 / T04 | Exact forward depth/choice/phase readback; never re-enter a completed locked room |
| D02 | New Dungeon runs and key budget | N | R1 / T04 | Current key/eligibility/entry quote and accepted-run receipt; key cap defaults zero |
| D03 | Death recovery and repeated losses | N | R1 / T04,T07 | Observed remaining lives and recovery transition; optional finite retry, default stop on first confirmed loss |
| D04 | Room priorities, presets, ties, curse filters | P | R1 / T04 | Actual offer token/flags; configurable priorities; deterministic tie and unknown-rule handling |
| D05 | Shop presets, effective prices, capped purchases | P | R1 / T04 | Item effects/current price read from known schema; physical/magic/speed/range/economy/control/reward presets; exact receipt |
| D06 | Shrines: accept/decline and curse whitelist | P | R1 / T04 | Offer includes known effect and cost; acceptance whitelist; unknown offers skipped with reason |
| D07 | Final normal/rare chests, luck and rewards | P | R1 / T04,T14 | Explicit opening permission; exact chest decrement/reward correlation; observed luck labeled without drop guarantees |
| D08 | Dungeon Info: rooms/items/effects/costs/curse tiers | N | R1 / T04,T13 | Searchable bounded data from current loaded definitions with source/version; unknown remains unknown |
| G01 | Vote start | O | R1 / T06 | Once per round, exact VotingFinished transition |
| G02 | Wave skip, wave/type stop rules, persistent auto-skip | N | R2 / T06 | Current offer token and wave readback; persistent game-setting mutation separately authorized and restored |
| G03 | Next/replay/lobby, finish delay and limits | P | R1–4 / T06,T07,T09 | Genuine result plus exact eligible transition; costs and limits survive teleport |
| G04 | Sell farms/all at configured wave; leave at wave | N | R2 / T06 | Known sellability, exact owned model removal/transition; unsellable Bulma skipped explicitly |
| G05 | Event/roguelike cards, priority/caps/ties | N | R2 / T06 | Exact current offer, accepted modifier, bounded counts; all-capped offers use explicit reviewed fallback or stop |
| G06 | Normal active abilities/spells, cooldowns/toggles | N | R1–2 / T05 | Actual equipped model/cooldown and cast/toggle receipt; no repeated cast on timeout |
| G07 | Buff chains, spaced control, meter rotations | N | R2 / T05 | Role/range/stacking/cooldown/bar evidence; scheduler avoids waste and overlap; unknown semantics disable only that strategy |
| G08 | Boss priority and ability conditions | N | R2 / T05 | Observable boss/air/shield/type fields, per-unit compatibility and priority readback |
| G09 | Delete Map, Boost FPS, Black Screen, Performance Mode | N | R1–5 / T13 | Reversible quality/effect/rendering profiles; touch escape remains live. Destructive map deletion is replaced, not claimed as implemented |
| G10 | Place Anywhere | N | R2 / T03 | Show legal candidates/manual override and rejection cause; retain server constraints. Forcing shared can_place=true is explicitly excluded, not counted as equivalent bypass |
| A01 | All equipped units: placement, upgrades, farm focus | O | R1–2 / T03,T05 | Exact equipped-copy/cap/price; affordable legal placement; +1-level receipt; per-slot status |
| A02 | Smart opening; interleaved upgrades | P | R1–2 / T05 | Affordable early defense, optional farm, reserve; avoid losing while waiting for an expensive farm upgrade |
| A03 | Cheapest / DPS-per-cost / slot / custom / round-robin upgrades | P | R2 / T05 | Explicit formula inputs; observed traits/attack coverage/modifiers; fall back to explained deterministic ordering when data is missing |
| A04 | Caps, order, start waves, Balanced/Farm/Damage presets | P | R2 / T05,T13 | Per-slot placement/upgrade caps and gates; presets change settings only and never arm |
| A05 | Path distance, ground/hill search radii, spacing | P | R2 / T03 | Actual multi-lane geometry and unit class; bounded scored search and minimum separation |
| A06 | Manual/saved/learned per-map spots; preview/Show Plan | P | R2 / T03,T12 | Map identity/version binding; projection and legality checks; optional bounded touch-readable preview; specific no-spot reason |
| A07 | Normal and boss targeting modes | P | R2 / T05 | First/last/strongest/weakest/closest/farthest only when observable current priority is supported |
| M01 | Create/select/rename/delete macros; stage assignments | N | R5 / T12 | Versioned data files, bounded names/size and account-safe assignments |
| M02 | Record place/upgrade/sell/target/ability/skip | N | R5 / T12 | Hook-free controller receipts and explicit manual capture; exact ordered action/observation records |
| M03 | Playback, timing/ignore timing, sell timing, unit replacement | N | R5 / T12 | Preconditions and exact feedback per step; verified copy replacement; bounded deadline/retries, no blind resend |
| M04 | Import/export/share and supported format migration | N | R5 / T12 | Strict data-only validation; known reference action formats mapped explicitly; unknown records rejected, never executed |
| W01 | Webhook URL/test/match/chest and aggregate totals | N | R5 / T14 | Separate explicit send opt-in; redacted bounded payload, response status, rate limits; URL excluded from reports/shares |
| R01 | Run log, wins/losses, unit/item/currency/reward summary | P | R1–5 / T14 | Round-ID dedup; typed outcomes; deltas distinct from attributed rewards; bounded local retention |
| X01 | Anti-AFK and optional walk-around | N | R4 / T07,T13 | Capability-gated opt-in, no interference with placement/manual input, cleanup on stop |
| X02 | Player-join return, friend/host follow | N | R4 / T07,T09 | Exact IDs and explicit transition policy; no display-name prefix matching |
| X03 | Rejoin, ping/freeze detector, loading failsafe | N | R4 / T07 | Multiple stale signals, finite recovery budget and visible countdown; constant ping alone never proves a crash |
| S01 | Compact touch UI, search, themes, scaling, hide/minimize/unload | P | R0–5 / T13 | Seven primary tabs retained; advanced feature search; clamped window, reachable Stop/escape and cleanup |
| S02 | Per-account profiles, reset/backup/import/export | P | R5 / T13 | Versioned migration; validate before atomic replacement; imports unarmed and without spending grants/secrets |
| S03 | Follow through lobby/story/room; authorized auto-resume | O | R1–5 / T07 | Exact self-loader; account/universe/job/destination/expiry checks; budgets persist; manual route changes disarm |
| K01 | Current Rukia ownership/variant/acquisition/pity/resources | H/P | R0–1 / T01,T08 | Exact observed variant and current source; incomplete inventory never proves absence; no invented pity |
| K02 | Best trait and target reroll | H/N | R0, R3 / T08,T11 | Current effects/pool/price; role and placement-cap comparison; target-copy and budget protection |
| K03 | Stat targets, worthiness, selective/all-stat rerolls | H/N | R0, R3 / T08,T11 | Real grades/raw values and current thresholds; target profile; no false perfect or guaranteed cube count |
| K04 | Evolution recipe, stars/material stages and takedowns | H/P | R0, R3 / T08,T09,T11 | Current exact recipe; owned/missing rows; observed useful rewards; per-copy takedowns; no new star system inferred |
| K05 | Explicit evolution and post-evolution inspection | N | R3 / T11 | Selected-copy preview, separate one-action permission, verified consumption and evolved-copy readback |
| K06 | Goal-aware farming efficiency and stop rules | P | R1–3 / T08,T14 | Confirmed progress per entry/time, stage feasibility, stop after actual selected goal; unknown rates stay unknown |

Exclusions are deliberately visible: shared-service placement bypass, disabling game listeners, destructive map deletion and global-hook recording are not copied. Their user-facing purposes receive the replacements above. These rows cannot receive a false “identical feature” checkmark. No CAPTCHA bypass or executor installation/security bypass is in scope. Webhook implementation does not authorize sending any message until separately enabled with a destination.

## Engineering design

### One owner for actions

Retain `src/runtime.lua` as orchestrator and `src/roblox.lua` as the native transport facade. Introduce focused feature modules rather than enlarge the adapter indefinitely. All gameplay actions, including abilities, shops, joiners, macros, wave skips and sales, submit intents to one coordinator. Telemetry/notifications use a separate bounded outbound queue and never compete for game RPC ownership.

An intent carries account/actual-job/round/stage, capability ID, exact target, observed quote/offer token, expected receipt, deadline and budget reservation. Lifecycle: **planned → reserved → sent → confirmed / rejected / uncertain**. An uncertain sent action keeps its fence until exact reconciliation or a proven invalidating lifecycle transition. A stop does not cancel an already-sent request; a new round does not erase account spending uncertainty.

### Current observations and capability gates

Each field has a source, observation time, lifecycle identity and schema version. Mark static definitions separately from dynamic inventory/quotes and server-confirmed receipts. Observed timestamps do not prove server freshness; inconsistent or incomplete observations block the affected action. Keep capabilities independent so missing ability data does not disable an otherwise supported basic combat run.

One explicit **capture test session** collects roster/definitions, supported modes, terrain/lanes, Dungeon offers/phases, whitelisted UI feedback and typed rewards under fixed bounds. Preserve a sanitized snapshot for regression fixtures. Capturing never buys, starts a keyed run, invokes an unknown getter or scans arbitrary Lua globals. Run permitted action probes only through the session's reviewed action list and spending limits.

### Budgets and permission

- Match Yen is separate from account currencies, keys, portals, materials and consumables.
- Default keys, summons, exchanges, rerolls, shop purchases, consumable use and inventory sales are disabled with cap 0.
- Start shows the operations, exact selected copy, current resource identities/quotes and maximum costs it authorizes. Trait/stat rerolls require this spending confirmation; evolution requires its own final one-action confirmation.
- Permissions are session-bound. Settings store preferences only. Spend reservations, confirmed debits and unresolved actions survive authorized hops/replacement; stop/start cannot reset a budget silently.
- Follow authorization lasts at most **7200 seconds**; session duration may not exceed that original window when following is enabled. Repeated rounds stop at their finite session/run/key/loss limits.
- Never overwrite a target trait, achieved protected stat, locked/shiny/protected unit, or the Rukia goal copy through another account action. Recheck identity and inventory before every consequential action.

### Strategy

Use an explainable policy before attempting adaptive learning: role-aware opening, early threat coverage, useful economy, legal multi-lane coverage, support overlap and incremental upgrade value. Read actual enemy/modifier fields; do not infer mechanics from names or icons. Account for air coverage, hit shields, resistances, control immunity, boss presence and ability stacking only when their schemas are known.

Store map/team/modifier-specific measured profiles. Compare confirmed clears, duration, failures and progress; change one policy at a time. A loss may recommend a different preset, team role or easier route. Retrying the same losing strategy indefinitely is not adaptation. Optional loss retry defaults zero and never starts a fresh paid run outside its entry budget.

If no legal spot is found, distinguish absent terrain, wrong unit class, cap reached, occupied space, support-spacing constraint, missing range, truncation and genuine server rejection. Permit one explicitly configured relaxed *strategy* constraint when legality remains intact; otherwise stop that slot or the run according to its critical role. Do not keep emitting “no spot, retrying.”

### Rukia progression

First verify War/Final IDs and current availability through official/current in-game evidence. Record reward source, eligibility, key/currency costs, pity only if exposed, and recipe version. Historical Dungeon recipes and the 0.1% Unique figure remain labeled until revalidated.

Acquisition stops on positive exact ownership. Trait recommendations compare actual effects, placement cap, control coverage, boss role and cost; unknown effects prevent a “best” claim. Stats show raw damage/SPA/range, grade, scope and worthiness. Cost estimates use verified rates and describe probability, not guaranteed attempts. Stat/evolution order must be derived from current evolution stat mechanics before consuming cubes. Each material farm must show a current useful reward and stage feasibility; do not farm unrelated event currency without a verified exchange.

### Mobile, persistence and reports

Keep seven top-level tabs: RUKIA, TRAITS, STATS, EVOLUTION, FARM, REPORTS, SETTINGS. FARM contains Goal, route/preset, team readiness, costs/limits, Start/Pause/Stop and one blocker; advanced groups expose the full ledger's controls. UI uses compact scrolling and touch targets, optional lightweight preview and a viewport-clamped restore button.

Preserve one cooperative observer, initially the existing 0.8-second cadence, inventory refresh 4 seconds and UI refresh 2 seconds. Event signals mark cached fields dirty. Geometry remains bounded at the existing 8 lanes × 96 nodes, 96 candidates per missing slot, 6 slots and 24 proposed placements unless measurements justify a reviewed change. Yield between bounded batches. No startup metamethod hooks, GC scans, full GUI/workspace descendant scans or duplicate workers. Close disconnects listeners, stops new actions and attempts durable continuation revocation with truthful failure reporting.

Performance controls save originals and restore only fields still owned by our changes. Keep terrain, lanes and unit identity intact. Black Screen retains a touch escape/Stop path. Reports record real outcomes, receipts and blockers; inventory deltas are not automatically attributed to a reward. Redact UUIDs, account identifiers where unnecessary, webhook URLs and secrets. Store bounded local logs; COPY COMPLETE REPORT includes feature/evidence status, selected goal and the unfinished-action fence.

## Validation and release rules

1. Each meaningful task adds targeted offline tests before its implementation, retains the existing tests and compiles the generated main.lua. Do not add tests merely for cosmetic text or duplicate the implementation.
2. Run reproducible build/API checks and `git diff --check`; revise the API allowlist deliberately when a formerly forbidden paid endpoint gains a guarded adapter. Do not delete its protection test without replacing it with default-off, capped, receipt and uncertainty tests.
3. One batched supervised free-Story session should cover all equipped units, placements/upgrades, start/result/replay and two authorized hops across three clears. A blocked feature produces its exact fixture and blocker; it does not force another identical injection.
4. Test an existing Dungeon's full room/shop/shrine/final phase flow. New-run testing requires its own explicit key cap, initially at most 1. Record exact item/chest/key receipts. A rare Rukia drop is not required to prove control logic; claim acquisition only on an actual observed drop/ownership receipt.
5. For each additional mode/spending action, certify its own adapter using a minimum bounded live probe. Free-mode success cannot certify Portal consumption, rerolls or evolution.
6. Run a supervised tablet session of at least 20 minutes once the free loop works; record FPS/memory if the environment exposes reliable measurements, otherwise report unavailable and record visible failures. Check listener/task counts, retained logs and repeated load/close behavior. Never invent Android performance numbers.
7. Release status is per feature: **not implemented**, **implemented / offline tested**, **live passed (device/build/mode/date)**, or **blocked (specific evidence missing)**. Planned or source-reviewed does not equal supported.
8. Before publishing code, recheck the remote head, preserve concurrent work, review the entire change, and pin the previous tested bundle for rollback. Preserve the existing loadstring and settings migration. Publish release notes with real validation and unresolved limits.

## How we avoid another long loop

- One feature ledger and one evidence/capability registry; no repeated rediscovery of paths already established.
- One batched capture per missing schema family, followed by replayable offline fixtures; no release for every individual diagnostic button.
- Build complete slices: entry → combat → outcome → reward → continuation → goal stop. A button or an RPC wrapper alone cannot close a feature.
- Preserve passing modules; refactor only a boundary the next task needs. Integrate shared contracts before developing independent domains.
- Run the relevant tests after a change, the full suite at integration, and live checks for behavior the offline harness cannot observe.
- Complete the R1 loop before unrelated parity work; implement Rukia materials/build in R3 before finishing general cosmetics and macros.
- Track remaining tasks and concrete blockers after each release. Estimate elapsed delivery only after R0 identifies the genuinely missing current-game contracts; arbitrary hour estimates would recreate the previous overpromising.

## Next execution checkpoint

Execute T01–T03 as internal foundation work, then the R1 subset of T04–T08 and T13–T15. First deliverable: a complete, bounded, reportable acquisition loop for a verified route. If the current Rukia reward source cannot be established, deliver the tested general Dungeon loop with that exact blocker rather than label it Rukia farming.

This document is a plan for review. No implementation or new live-support claim follows from publishing it. The detailed [implementation checklist](../plans/2026-11-02-complete-hub.md) defines file boundaries, interfaces, tests and release gates.
