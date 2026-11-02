# Complete hub execution ledger — v8.0.0

Plan: [implementation checklist](2026-11-02-complete-hub.md). Spec: [master plan](../specs/2026-11-02-complete-hub-design.md). Base: b228d31628c96e6165025b968b6c2efd4935e559. Execution started November 2, 2026, Manila. Original v7 offline baseline: 397 tests.

**This is a substantial implementation increment, not a completed 59-feature hub or a live-certified Rukia farm.** The runtime is original native code and loads no Zeno source. Actual in-game receipts, clear rate and Android performance cannot be certified by the offline harness.

| Task | Work delivered | Remaining gate |
|---|---|---|
| T01 | Shared contexts/evidence validators, registered native capabilities, one bounded/redacted fixture capture in actual UI/entry; source recheck | Current secret reward/recipe/pool facts remain unverified; capture never initializes unknown services |
| T02 | Single dispatch gate for existing controllers, durable account reservations, explicit new coin allowance, exact settlement and uncertain debit protection | Account-sensitive extensions need current quotes/receipts; corrupt ledger freezes spending; free round guard is intentionally volatile |
| T03 | Actual observed multiple lane anchors, bounded terrain/overlap proposals, typed threat observations and unknown-field handling | Scored universal optimum, full enemy modifiers and live placement quality unproven |
| T04 | Current-run phase regressions, room/item info, exact custom shop order, explicit complete-offer shrine whitelist and item-count receipt | No verified new-key quote/eligibility or death-recovery receipt; new runs/life use remain unavailable; shop category optimization not complete |
| T05 | Caps/waves/custom order, affordable upgrade interleaving, farm preference, six priorities/boss override, typed normal casts with same-model cast-marker proof | Complex buff/meter/toggle semantics and trustworthy marginal-DPS previews unavailable; Value uses cheapest fallback |
| T06 | One-off offered skip voting with typed readback, known-sellable wave sale, Bulma exclusion, sold-role suppression, finish delay; pure all-capped card ranking | Native auto-skip account setting/restoration, applied-card receipt and scheduled leave not completed |
| T07 | Original budget identity and shrine grant carried through exact authorized hops; original time/run/shop limits retained | Automatic rejoin/death/freeze recovery remains unavailable; unknown signals cannot authorize a loop |
| T08 | Evidence-aware goal/deficit planner; exact ownership/trait/stat/evolution stopping; current-build catalog gate and measured route ranking | Current Rukia route, recipe, effects/odds and stat/evolution order not independently established |
| T09 | Existing manual-entry combat preserved | General lobby/party/Challenge/Mansion/Portal entry and costs/receipts blocked; no guessed adapter added |
| T10 | Existing account observations preserved | Claims/purchases/summons/exchanges/capsules/sales/codes need current accepted-state/cost/correlation contracts |
| T11 | Existing protected planning fields retained | No current trait/stat/evolution mutation signature, quote or selected-copy receipt; no request is sent |
| T12 | Record exact native actions or explicit single manual changes; validated named data-only files, copy/import/export, rename/delete backup, runtime playback and same-macro continuation signature | Unknown reference formats rejected; automatic unit substitution and multi-stage assignment library not complete |
| T13 | Portable validated profiles/backup/reset, theme/scale/search, viewport clamp, reversible local shadow/effect controls, visual black overlay, optional idle input and native screen opening | Native tablet layout/restore/performance still untested; no destructive map deletion or 3D-rendering claim |
| T14 | 59-group status list, bounded/redacted events, deduplicated/conflicting outcomes, retained totals, report export and separate opt-in notification queue | Reward contents remain unattributed without typed receipt; webhook capability/device behavior untested and OFF by default |
| T15 | Reproducible generated bundle, meaningful new offline regressions, unchanged entrypoint and whole-branch review gate | Live free-Story, Dungeon, paid-action and tablet gates cannot run in this environment |

Each meaningful change was written after observing its missing-behavior test fail; existing regression suites were retained. The actual entry harness covers recording/playback, all dispatch paths through the gate, imported settings remaining unarmed, new fields being applied and persisted account uncertainty.

No implementation is silently labeled live supported. The runtime [feature ledger](../../../src/features.lua) exposes every group as offline, partial or blocked. Excluded reference techniques remain explicitly accounted for in the master plan.

## Evidence required to unblock paid progression

- Current exact War/Final reward table and source/eligibility; recipe and evolution stat behavior from the current build.
- New-entry resource identity/effective quote and run receipt; current remaining lives/recovery state for a separately permitted retry.
- Per-mode unlock/pad/party/destination and cost receipt before enabling auto-entry.
- Current account shop/banner/exchange quote/stock and correlated inventory result; no global unrelated unit_added attribution.
- Trait/stat selected-copy signature, current resource price and fresh before/after result; evolution additionally needs the current recipe and evolved-copy linkage.
- Actual buff/stack/meter/card applied-state data before enabling those policies.

## User validation route

Use the unchanged loadstring and run only this project. First test a free Story stage with spending and replay off; compare all observed slots/costs, then one bounded existing Dungeon run. COPY COMPLETE REPORT includes state, known blockers, pending uncertainty and all feature statuses. CAPTURE GAME DATA ONCE exports sanitized observed fields. Repeating a missing field cannot turn it into verified data.

New Dungeon starts, summons/rerolls/evolution and other unavailable mutations remain manual. Their absence is a real implementation blocker, not a success or a claim that endless Rukia acquisition is ready.

## Independent review and regression pass

One fresh whole-branch review found no Critical issues and six Important issues. The normal wave-start recording failure was regraded from Minor to Important because it prevents the documented record-before-Auto workflow. All seven were reproduced before correction:

- Indeterminate initialization reads now block spending unless a ledger was restored or absence was positively established; the prior unresolved debit file remains untouched after storage recovers.
- Macro precondition time starts when a step becomes eligible, independently of the overall session limit; late first and subsequent waves both execute.
- Macro playback binds the exact equipped UUIDs privately at arm, checks them during playback and carries them in authorized continuation. Portable macro files still omit UUIDs; another copy needs explicit playback approval.
- Actual editable UI controls refresh from loaded/reset settings while preserving active user edits.
- UI scaling fits the real viewport/safe insets before position clamping; portrait/landscape extremes have source-UI harness coverage.
- Macro renaming refuses occupied or indeterminate destinations; failed writes preserve the source.
- Successfully confirmed orchestration actions such as wave start no longer stop a combat-action recording.

The regression pass is green: **479 offline cases across24 suites**, actual-entry/UI seams, Luau compilation, active API constraints, unchanged loader, reproducible bundle and whitespace checks. A second reviewer was not dispatched; covering regressions verified the single fix pass.

One cosmetic minor is deferred: the old configuration-copy button still says it contains unit UUIDs. The actual portable export omits the selected-copy identity and execution grants; its label needs correction in a later UI pass.

### Rulings and limits retained after review

- Native/local workflow work continued while current paid schemas were unavailable. Cost: the whole master plan remains incomplete; source review does not substitute for the missing game contracts.
- Current Rukia availability, recipe, pity, trait effects/prices and stat/evolution ordering remain unverified. Expected behavior: no historical spending authority. Cost if this assessment is incomplete: further in-game verification is needed before targeted progression.
- T09 entry/party/rotation adapters remain unavailable. Expected behavior: manual entry. Cost: those modes do not yet join themselves.
- T10 claims/account shops/summons/exchanges/capsules/sales/codes remain unavailable. Expected behavior: no account mutation. Cost: account actions remain manual.
- T11 trait/stat/evolution adapters remain unavailable. Expected behavior: preserve the selected build/resources. Cost: no automatic perfect-build loop.
- New Dungeon keys, recovery lives and automatic reconnect/freeze loops remain blocked. Expected behavior: stop or manual entry/recovery. Cost: repetition across new paid runs is not autonomous.
- Complex buff/meter/value/card/persistent-autoskip/leave policies remain incomplete. Expected behavior: only the explicitly implemented observed policies run. Cost: full strategic parity is not certified.
- Automatic macro substitutions, multi-stage libraries and foreign formats remain incomplete; unintended within-session copy substitution was fixed. Cost: unsupported strategies/formats require a new supported recording or explicit rearm.
- Live placement, multi-floor success, clears and tablet performance have no device evidence. Expected behavior: experimental status and supervised testing. Cost: crashes/unsupported live schemas remain possible.
- Real webhook delivery was not tested or sent. Expected behavior: OFF by default and separate destination/send consent. Cost: executor HTTP compatibility needs an optional explicit test.
- Full59-feature parity is not claimed. The remaining feature statuses stay partial/blocked until implementation and evidence satisfy their individual gates.
