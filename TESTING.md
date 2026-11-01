# Supervised mobile testing — v6

## Clean launch

Restart Roblox after older injections. Execute the unchanged loadstring once in the lobby. Full Auto must show OFF. Check seven tabs, scrolling, keyboard entry, minimize/reopen and close. Record device, Android/Delta version, game place/update and actual errors. No real Android test has been completed here.

Only after a stable observer test, try one re-execution: the old GUI must disappear and one new GUI remain. Closing must stop updates and dragging. If it crashes before the GUI, stop repeated injection; offline syntax tests cannot diagnose that crash.

## Next test: combat data (v6.0.4)

The user's v6.0.3 report already recognized 77 owned records and six equipped slots. Do not repeat a broad lobby metadata scan.

1. Join a free Story stage manually, then inject once **inside that match**. Confirm the GUI/report is v6.0.4. Leave Full Auto OFF.
2. Start waves and place one affordable equipped unit manually. Open Collection once if it has not been loaded.
3. Tap **FARM → READ MATCH DATA + COPY COMBAT REPORT**. This stops combat, reads existing client data and copies a focused report; it sends no place/upgrade request.
4. Paste the report. Check that stage, match cash, equipped slot, exact tower match and position are observed. Compare effective placement/next-upgrade prices against the game. If affordable, upgrade that same tower manually once, then use REPORTS → COPY COMBAT REPORT to inspect the changed level.

Missing scale or definitions leaves computed costs unknown. Do not enable combat to bypass a blocker. The focused report names the missing source. Dungeon access, keys and rewards are not part of this free test.

## Read the client cache

1. Keep Full Auto OFF and open the game's Units/Collection once.
2. In this tool, tap **RUKIA → READ CLIENT CACHE + COPY REPORT** once.
3. Wait for the copied-report status and paste the report. Capability or schema failure is a blocker, not a reason to enable farming.
4. If records appear, compare equipped IDs/slots, Rukia form, traits and quantities with the actual Collection. Unknown raw stats stay unknown. Unit UUIDs remain local and are omitted from the report.

This manual experimental path checks loaded Loader status, retrieves its export and reads existing closure/cache tables. No service getter or initializer is explicitly invoked. Delta may isolate module caches differently; native require can execute module code in a different environment. Timeout rejects late results and blocks duplicates but cannot interrupt a native call. An unsupported attempt is not retried automatically. No summons, rerolls, keys or evolution actions are enabled by connecting the reader.

After a successful connection, REFRESH EXPOSED INVENTORY rereads the known service table without another loaded-module snapshot. If Units was not loaded yet, one additional explicit cache/match read can inspect its reported-loaded export while reusing Loader. Compare updates after changing the equipped team manually. These observations do not certify server freshness or full combat compatibility.

## Verify observations

Compare exact Rukia copy, form, trait, stat scope, raw values and grades with unit details. Plain rukia is the old unit. SETTINGS accepts explicit player/... inventory/resource roots; only a few direct candidates are tried. Table-based inventories require the manual experimental cache reader; unsupported layouts stay unknown. No GC scanning or arbitrary numeric-module loading is used.

Typed player/_stats/resource supplies cash only inside an observed active/stage-identified match. It is never used as lobby match cash. Currency can also be bound to an actual local match Value; never bind account gems/gold or another player's cash. Stage ID comes from current Loader.LevelData or observed GetLevelData. Selected mode stays unverified unless supported mode fields/flags supply it. Unknown counts are not zero.

Inspect current Rukia rewards, key costs/limits and Evolve recipe yourself. Historical wiki data does not certify this patch. Copy the complete report when data is missing.

## Record a small profile

Use a low-stakes stage you can already clear. Historical signatures spawn_unit(uuid,CFrame), upgrade_unit_ingame(model), and set_game_finished_vote("replay") remain experimental. Endpoint existence is not payload verification.

Place one affordable equipped unit manually. Wait for observed roster/stage. Tap RECORD CURRENT OWN PLACEMENTS. All towers must map to exact equipped UUIDs and IDs. Costs can come from loaded Units plus an explicitly observed cost scale, direct native cost fields, or comma-separated fallback values checked in game. Empty positions preserve slots. Prices and modifiers are source-labeled; changed recorded prices/scales block automation.

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
