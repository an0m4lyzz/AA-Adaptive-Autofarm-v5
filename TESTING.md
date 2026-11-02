# Supervised mobile testing — v6

## Clean launch

Restart Roblox after older injections. Execute the unchanged loadstring once in the lobby. Full Auto must show OFF. Check seven tabs, scrolling, keyboard entry, minimize/reopen and close. Record device, Android/Delta version, game place/update and actual errors. No real Android test has been completed here.

Only after a stable observer test, try one re-execution: the old GUI must disappear and one new GUI remain. Closing must stop updates and dragging. If it crashes before the GUI, stop repeated injection; offline syntax tests cannot diagnose that crash.

## Current test: equipped Story team (v6.1.0)

The user's v6.0.7 report observes the exact scripted Bulma placement with RPC true, cash 900→100 and a new matching own tower. Earlier reports observe scripted upgrades. Other units, full clears and replay still need live validation.

1. Join the same free Story stage, run the unchanged loadstring and confirm **6.1.0**. Tap FARM → **READ MATCH DATA + COPY COMBAT REPORT** once. Compare all six current slots and prices with the game.
2. Start waves and manually place at least one copy of every equipped unit where you want it. Tap **RECORD + SAVE TEAM POSITIONS**. You may record partial teams as money arrives; each compatible capture merges and saves. The current captured copies of a unit replace that unit's previous recorded group, so include all copies you intend to keep. Require **Recorded slots 6 / 6** and a saved status before leaving.
3. Enter a fresh copy of the same Story stage, load again and read match data. The saved team restores, but Auto remains OFF. Start waves; leave replay OFF, max runs 1 and a short session timeout. Do not sell Bulma.
4. Tap **CHECK TEAM READINESS**, then **START TEAM AUTO**. An affordable recorded combat unit is preferred; otherwise one farm may open while the controller saves for combat. It fills the recorded team before upgrading by observed level and affordable price. This is a deterministic baseline, not a proven optimal strategy.
5. Observe exact placement/upgrade feedback without making simultaneous manual changes. A rejected request, ambiguous readback or eight-second timeout stops automation. Missing upgrade data stops after a bounded wait rather than claiming maximum level.
6. Tap **COPY TEAM REPORT** after the run or blocker. A team stop also attempts to copy it automatically. Verify its outcome against the actual game. Keep replay OFF until a supervised clear and result detection work.

Every declared equipped slot must resolve from the cache and have a matching profile target. Partial/missing/conflicting equipped records block arming even if the parsed survivors all have recorded positions. A tower cannot satisfy two targets; same-unit recorded spots within three studs are rejected as ambiguous. Profile limit 24; incomplete tower scans, unsupported terrain, changed prices/modifiers/stage and stale equipment also block.

The optional exact game_finished listener starts only when Team Auto arms and disconnects on stop/close. A raw boolean victory must belong to the current run and agree with its finished marker; conflicting or stale evidence stays unknown. A replay must clear the result and recorded towers and show both a changed run and actual native round identity before spending again. Team replay is Story-only, opt-in, stage-confirmed free and capped.

Stopping cannot undo a sent request. An unresolved-action fence survives script close/reload in the same executor after the RPC returns. Only exact controller readback or an actual native reset releases it; reloading, local run counters and newly arriving map metadata do not. Enter a fresh match after unconfirmed feedback. This fence is in memory and does not survive a full Roblox process restart.

## Earlier placement-boundary test (v6.0.7)

The user observed scripted Bulma upgrades, then a placement timeout in a fresh namek_level_1 run with no own tower. The old report does not reveal the RPC return or saved position. v6.0.7 corrects the suspected model-centre/terrain-surface height input and records those missing boundary observations. The actual cause and successful placement still need live confirmation.

1. In an active **same Story stage** with Bulma absent, run the unchanged loadstring and confirm 6.0.7. Keep Full Auto OFF.
2. Tap FARM → READ MATCH DATA + COPY COMBAT REPORT to connect the cache. The existing saved target is reused. This report also performs one read-only terrain check.
3. Start waves and tap TEST ONE PLACEMENT once when the displayed price plus reserve is affordable. No manual placement/upgrading during the following eight seconds.
4. Paste the automatically copied report. Inspect **SURFACE CHECK**, **SENT POSITION**, **RPC RESPONSE** and **SCOPED GAME MESSAGES** alongside the exact tower readback. If the surface is unsupported the request stops before sending; do not bypass the blocker.

The raycast uses only the saved X/Z and observed _terrain, not an enemy path or guessed map spot. It never skips a blocking first hit or searches under it. A source/type/ancestry/height mismatch is unsupported. Missing definitions or raycast capability also stop. Ground/hill flags follow the loaded definition. The three-stud maximum downward projection is conservative, not a claim about all unit heights; surfaces above the recorded sample or farther below require inspection.

RPC summaries contain at most two returns and whitelisted scalar table fields; unit UUIDs are redacted. Lua callOK means the native call did not throw, not that the game placed a unit. The exact show_message listener is optional, action-scoped, at most eight seconds/four bounded messages and cleaned on replacement/close. A message in the window may have another cause. No response or warning can replace exact own-model/identity/position confirmation.

## Earlier combat-data test (v6.0.4)

The user's v6.0.3 report already recognized 77 owned records and six equipped slots. Do not repeat a broad lobby metadata scan.

1. Join a free Story stage manually, then inject once **inside that match**. Confirm the GUI/report is v6.0.4. Leave Full Auto OFF.
2. Start waves and place one affordable equipped unit manually. Open Collection once if it has not been loaded.
3. Tap **FARM → READ MATCH DATA + COPY COMBAT REPORT**. This stops combat, reads existing client data and copies a focused report; it sends no place/upgrade request.
4. Paste the report. Check that stage, match cash, equipped slot, exact tower match and position are observed. Compare effective placement/next-upgrade prices against the game. If affordable, upgrade that same tower manually once, then use REPORTS → COPY COMBAT REPORT to inspect the changed level.

Missing scale or definitions leaves computed costs unknown. Do not enable combat to bypass a blocker. The focused report names the missing source. Dungeon access, keys and rewards are not part of this free test.

## Earlier one-upgrade test (v6.0.5)

The submitted v6.0.4 report now observes namek_level_1, Story, cash 400, explicit cost scale 1, all six prices and Bulma's exact identity, position and next quote of 1,500 Yen. The read-only adapter boundary is demonstrated for that session. No automated placement or upgrade has been demonstrated yet.

1. Run the unchanged loadstring inside an active free Story stage and confirm **6.0.5**. Keep Full Auto OFF. If the previous match ended, use another free Story attempt.
2. Use FARM → READ MATCH DATA + COPY COMBAT REPORT once to connect this injection. Place Bulma manually if needed. Other defenders may stay placed to protect the base.
3. For the reported team leave **TEST TARGET: EQUIPPED SLOT 4**, then tap **RECORD ONE TEST TARGET**. This records only Bulma's one copy into a separate test profile; the farming profile is preserved.
4. When cash covers the displayed upgrade price plus SETTINGS reserve, inspect the button's unit/slot/level/price and tap **TEST ONE UPGRADE** once. The reported quote was bulma, slot 4, 0→1, 1,500 Yen. A stale/changed quote is blocked; read the refreshed button before another click.
5. Do not manually place or upgrade during the eight-second readback. The report copies automatically when the test observes the exact level change or stops unconfirmed. Paste that report.

This emits one upgrade request, without requiring or setting Rukia-route/protocol confirmations. It does not turn on Full Auto or replay. At most one attempt per action kind is allowed per observed run in this controller. Any unconfirmed attempt blocks further mutation testing/farming for that run. STOP cannot undo a native request already sent. No live test of these new buttons has been performed here.

The user then observed the exact scripted Bulma upgrade **1→2** with a 3,000-Yen quote. The placement request remains untested. Bulma cannot be sold in the reported build, so the previous unconditional selling instruction was incorrect.

### Placement with an unsellable unit (v6.0.6)

1. While Bulma is still placed, select test slot 4 and tap RECORD ONE TEST TARGET if not already recorded.
2. Tap SETTINGS → SAVE SETTINGS / RECORDED PROFILE. Wait for **Settings saved**; this file includes the separate test profile and its position. If saving fails, keep the current match and report that blocker.
3. Enter a fresh copy of the **same Story stage**, run the unchanged loadstring, and leave Full Auto OFF. The saved test profile restores automatically.
4. Read match data, start waves, and leave Bulma's recorded spot empty. When her displayed deployment price plus reserve is affordable, tap TEST ONE PLACEMENT once. The prior reported price was 800 Yen.
5. Leave placement/upgrade controls alone for eight seconds, then paste the automatically copied report.

The profile's stage, mode, place, current equipped identity, costs and modifier must still match. Existing target copies, occupied spots or multiple matching readbacks block the test. Only a unique new own model with exact UUID/ID and position can count as an observed placement after request. No selling action is sent. For another unit, manual removal is an option only when the actual game exposes a working Sell control.

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

Only after reliable supervised clears in observed free Story, enable Team replay, confirm no item cost for that exact stage, and raise max runs to 2. Both switches are required; user-selected mode alone cannot authorize replay. Transition waits up to 15 seconds for fresh matching identity and cleared results. The separate legacy Rukia controller permits observed Story/Infinite/Challenge with its own route gates. Dungeon/Portal/Raid/Event never replay. All key use, dungeon navigation and chests remain manual.

No premium mutation toggle exists because its verified protocol/cost/readback is unavailable. Trait/stat caps are planning limits.

## Offline reproduction

```bash
python3 scripts/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

These tests do not measure FPS, memory, server acceptance, drop probabilities or dungeon completion.
