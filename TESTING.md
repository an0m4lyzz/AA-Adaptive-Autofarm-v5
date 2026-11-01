# Supervised mobile testing — v6

## Clean launch

Restart Roblox after older injections. Execute the unchanged loadstring once in the lobby. Full Auto must show OFF. Check seven tabs, scrolling, keyboard entry, minimize/reopen and close. Record device, Android/Delta version, game place/update and actual errors. No real Android test has been completed here.

Only after a stable observer test, try one re-execution: the old GUI must disappear and one new GUI remain. Closing must stop updates and dragging. If it crashes before the GUI, stop repeated injection; offline syntax tests cannot diagnose that crash.

## Verify observations

Compare exact Rukia copy, form, trait, stat scope, raw values and grades with unit details. Plain rukia is the old unit. SETTINGS accepts explicit player/... inventory/resource roots; only a few direct candidates are tried. Client tables unavailable as Instances remain unknown; no GC scanning or arbitrary client-module execution is used.

Currency may be bound to an actual local match Value (for example player/leaderstats/yen only if it exists). Never bind account gems/gold or another player's cash. Stage ID must come from observed GetLevelData; selected mode stays unverified unless the response supplies it. Unknown counts are not zero.

Inspect current Rukia rewards, key costs/limits and Evolve recipe yourself. Historical wiki data does not certify this patch. Copy the complete report when data is missing.

## Record a small profile

For v6.0.1, first use **REPORTS → SCAN DATA PATHS + COPY REPORT** when all inventory fields remain unknown. The button stops combat, collects a bounded one-shot metadata report and copies the complete report automatically. Paste that result. A supported inventory path is still unknown until evidence identifies one; running the diagnostic does not establish farming readiness. Stage/Yen unknown in a detected lobby is expected. The report now includes observed context and place ID.

In v6.0.2, the same button prioritizes the now-observed src/client tree instead of repeated prompt/settings entries. Compare Gold, Gems and SummerPearls with your on-screen account balances. The raw player/_stats/resource value has unverified meaning and cannot authorize match spending. These balance observations do not establish unit ownership. Leave Full Auto OFF while the inventory adapter remains unavailable.

Use a low-stakes stage you can already clear. Historical signatures spawn_unit(uuid,CFrame), upgrade_unit_ingame(model), and set_game_finished_vote("replay") remain experimental. Endpoint existence is not payload verification.

Place one affordable equipped unit manually. Wait for observed roster/stage. Tap RECORD CURRENT OWN PLACEMENTS. All towers must map to exact equipped UUIDs and IDs. Costs must be visible, or entered by equipped slot as comma-separated fallback values after checking them in game. Empty positions preserve slots. Costs are source-labeled and may differ under modifiers.

Recording stores positions, slots, UUIDs and costs, and clears route/combat/replay confirmations. It orders by slot and coordinate, not an adaptive combat strategy. It does not record unseen upgrade plans, terrain legality, skills or target priority.

## Supervise each action

Confirm the current stage advances Rukia and the current combat signature has been independently verified. Leave replay OFF, max runs 1, session timeout low and a Yen reserve. CHECK READINESS must have no blocker.

In a fresh matching stage, enable experimental combat and start waves manually:

1. The exact unit must appear at the recorded location with correct Yen deduction.
2. Only a new own model with matching UUID, ID and position confirms placement. Another placement must not count.
3. Only an observed level increase confirms an upgrade; next cost and baseline level must be known.
4. Rejection or an eight-second feedback timeout must stop, without repeated or overlapping calls.
5. Map/wave lifecycle changes require fresh stage verification.

If anything differs, stop, close and copy the report. Do not leave it unattended.

## Results and replay

Verify visible Victory and Defeat manually. Ambiguous/incomplete UI stays unknown; reward text and inventory changes are observations requiring inspection.

Only after reliable supervised clears in an observed free Story/Infinite/Challenge mode, enable replay, confirm no item cost for that exact stage, and raise max runs to 2. Both switches are required; user-selected mode alone cannot authorize replay. Transition waits up to 15 seconds for fresh matching identity. Dungeon/Portal/Raid/Event never replay. All key use, dungeon navigation and chests remain manual.

No premium mutation toggle exists because its verified protocol/cost/readback is unavailable. Trait/stat caps are planning limits.

## Offline reproduction

```bash
python3 scripts/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

These tests do not measure FPS, memory, server acceptance, drop probabilities or dungeon completion.
