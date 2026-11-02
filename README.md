# [K] Anime Adventures — Rukia progression v6

**Offline-tested, mobile-oriented controller. Current Roblox / Delta compatibility is UNVERIFIED. Unattended Rukia progression is NOT READY.**

The official experience now displays Update 21 (checked November 1, 2026, Manila date). Current Rukia availability, recipe, rates and protocols could not be verified. Read the [research and progression plan](docs/RUKIA-RESEARCH.md), [audit](docs/AUDIT.md) and [testing guide](TESTING.md).

## Unchanged entry point

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua"))()
```

main.lua bundles local src modules; there is no secondary HTTP loader or external GUI library. Old v5 source and instructions are archived intact in legacy/ and are not loaded. Existing v5 settings remain untouched; the compatible upgrade preference migrates on the first v6 load. Old macros need re-recording.

## Feature status

| Feature | Status | Boundary |
|---|---|---|
| Rukia identity and selected-copy goals | Offline-tested logic | Historical secret IDs rukia_2 / rukia_2_evo; old rukia excluded. Live schema unknown. |
| Inventory, traits, stats, material counts | Experimental observer | Player-replicated Instances or explicit client-cache reader; missing data stays unknown. Partial scans never prove absence. |
| Progression checklist | Implemented, historical data | Acquisition → trait → stats → evolution. No fabricated pity or live price. |
| Seven-tab dark touch GUI | Implemented; live untested | RUKIA, TRAITS, STATS, EVOLUTION, FARM, REPORTS, SETTINGS. |
| Recorded placements/upgrades | Experimental | Exact equipped identity, stage, costs, position and new-model/upgrade feedback required. |
| One-action Story tests | One Bulma upgrade observed; placement untested | Explicit click, visible unit/slot/price, one request and bounded readback. No Rukia route claim. |
| Path observation | Experimental observer | Bounded visible movement samples. Active placement uses recorded coordinates. |
| Results and reports | Offline-tested logic | Exact visible labels, ambiguity remains unknown. Resource deltas are observations, not attributed drops. |
| Replay | Experimental, restricted | Observed Story/Infinite/Challenge only; stage-specific no-cost confirmation, opt-in and run cap. |
| Summons, trait/stat rerolls, evolution | **Unavailable** | No verified current protocol, price or inventory transaction. Budget inputs are planning limits. |
| Dungeon branches, keys, shops, chests | **Unavailable** | Manual play required; no verified adapter. |
| Random event towers, target priority, abilities, auto equip | **Unavailable** | No current verified mode/action adapter. |
| Best current build / secret availability | **Unverified** | Historical candidates and recipe only. |

## Mobile protections

Full Auto is OFF after every load. Target/mode/profile/settings changes disarm it. Close disconnects all GUI/input listeners; minimize keeps the observer alive.

No hooks, GC enumeration, full PlayerGui traversal, speculative remote-name loops or automatic keys/summons. One 0.8-second observer loop, inventory every four seconds, UI every two seconds. Path ≤80 samples; log ≤240 lines; report ≤64 KiB. Tower scans above 120 children block mutation; incomplete result scans cannot confirm victory.

One outstanding remote request, bounded feedback wait, no blind retries. A pending request remains globally locked across replacement until it returns; stopping cannot undo a request already sent. An unclean-session marker reports possible crash/teleport/process exit without claiming which occurred.

Restart Roblox after older hooked builds. These protections do not prove Android crash freedom.

## First test

The user's v6.0.4 report demonstrates combat data reads, and the v6.0.5 report observes one scripted Bulma upgrade **1→2**. Placement remains untested. Bulma is unsellable in the reported build, so use a saved position in a fresh matching stage.

1. With Bulma placed, leave **TEST TARGET: EQUIPPED SLOT 4** and tap **RECORD ONE TEST TARGET**.
2. Tap **SETTINGS → SAVE SETTINGS / RECORDED PROFILE** and wait for **Settings saved** before leaving.
3. Enter a fresh copy of the same Story stage and execute the unchanged loadstring. Confirm v6.0.6; keep Full Auto OFF.
4. Read match data, start waves and keep the saved Bulma spot empty.
5. When affordable, tap **TEST ONE PLACEMENT** at the displayed quote (previously 800 Yen), wait up to eight seconds and paste the automatically copied report.

See [TESTING.md](TESTING.md) for details. These controls do not require claiming Story is a Rukia farming route. Dungeon keys/chests remain manual and unverified.

### v6.0.1: missing data-path diagnostic

If the inventory refresh returns zero exposed records, use **REPORTS → SCAN DATA PATHS + COPY REPORT**. This manual scan adds relevant folder/module paths and attribute types to the report. It never executes modules or reads their source, GUI text or stored field values, and it does not make any previously unknown inventory verified. Its metadata scan is limited to 180 nodes, 48 children per folder, a 2.5-second cooperative deadline and 30 KiB of cached diagnostic text. Unrelated replicated assets and GUI descendants are not expanded. No polling scan is added.

The user's lobby also exposed both _UNITS and wave 0. v6.0.1 checks observed lobby markers before labeling those objects as a match. Selected Dungeon mode still does not prove that the player is in a Dungeon.

### v6.0.2: prioritize the observed client tree

The next live report reached the metadata budget before client services: repeated prompt GUIs, settings and static definitions consumed the scan. The diagnostic now visits observed src/client first, ranks session/profile/collection/service names within a bounded child list, skips prompt GUIs and settings expansion, and lists the observed gui/_R wrapper's immediate children. No GUI text or source is read. It inspects at most 256 child names per eligible folder and queues at most 48; the 180-node, 2.5-second and 30 KiB limits remain.

Observed player/_stats NumberValue fields gold_amount, gem_amount and _resourceSummerPearls are now read into a separate account-balance display. The field resource is displayed with its meaning unverified; it is never silently used as match Yen. No owned/equipped inventory schema or live progression is certified by these additions.

### v6.0.3: explicit client-cache reader

The live v6.0.2 report confirmed the balance reader and opaque numeric client module names. Open the game's Collection once, then use **RUKIA → READ CLIENT CACHE + COPY REPORT**. Full Auto stays OFF. This attempts a different, experimental data path.

The reader checks that the exact Loader appears in getloadedmodules, retrieves its export once, and inspects at most 32 upvalues each of existing init and load_client_service closures. Neither closure is invoked. It looks for existing named cached client-service wrappers structurally, without fixed upvalue indices. No service getter, initializer, arbitrary numeric module, remote, hook or GC enumeration is called. Missing capability/loaded status/schema reports unavailable without a fallback initializer.

After connection, the retained registry entry and current session are read on normal four-second refreshes. UUID and slot aliases must agree; exposed owner mismatches are rejected. The parser reads equipment first and at most 400 additional ownership entries. Missing counts stay unknown; potential multipliers cannot become attack stats. A placed event tower cannot prove permanent collection ownership.

**Native limitation:** Roblox caches require results per Luau environment. Delta cache isolation is unverified; require could execute Loader code despite it being reported loaded. The eight-second deadline rejects late results and preserves pending-operation locks, but cannot interrupt native calls or undo execution. This is a manual experimental action. Observation time does not establish server freshness. Compare returned units and counts with your Collection before testing combat.

See [references and validation](docs/CLIENT-CACHE.md).

### v6.0.4: connect the combat data paths

The previous adapter could read inventory but omitted three combat sources used by primary implementations: player/_stats/resource, Loader.LevelData and static Units definitions. Added match-only typed resource cash, read-only cached level data, and an explicit read of the exact reported-loaded src/Data/Units export. No load_data/service getter/initializer is called. One additional manual attempt permits Units to load after inventory; the retained Loader export is reused. No startup introspection is added.

Definition placement and upgrade prices require an **explicit positive observed player_cost_scale**. Missing modifiers do not silently mean 1; user-recorded fallback prices remain available. Recorded modifier/price changes block automation. Temporary missing level data cannot revive a previous run's stage. Missing map endpoints are checked for up to 30 seconds; completed invalid replies permit at most three actual requests, with the global pending/timeout lock preserved.

The focused combat report includes exact equipped matches (UUIDs omitted), position availability, upgrade levels, current prices, data sources, endpoint presence and readiness blockers. These are implemented adapter fixes with offline regressions; actual placement/upgrade acceptance and Android performance still require the supervised match test.

### v6.0.5: one supervised action

The v6.0.4 live report confirms the missing reads now execute in namek_level_1: Story observed, resource cash 400, cost scale 1, six equipped prices, Bulma position/identity and next quote 1,500. The remaining Full Auto gates are intentional, and this Story test has no confirmed Rukia reward route. A separate single-action controller allows protocol testing without changing those confirmations.

Select an equipped slot and record its single placed copy into a separate test profile. Other defenders may remain placed. Buttons display unit ID, actual slot, upgrade level and match-Yen price; expired or changed quotes cannot spend. Each kind permits one explicit request per observed run in the current controller, followed by an eight-second readback. The observer never emits another action. There is no automatic upgrade chain, replay, selling, route/protocol promotion or premium endpoint.

New-model readback requires exactly one new matching model at the recorded position. Upgrade readback requires the same model with exactly one added level. Ambiguous, late, changed-context and rejected results stay unconfirmed and block further tests/farming for that observed run. Reports copy automatically on completion. Native requests cannot be undone by STOP. Reloading resets in-memory test history; the global pending native-request lock still applies. Live request acceptance and complete Rukia progression remain unverified.

### v6.0.6: correct unsellable-unit guidance

The user's v6.0.5 report observes the scripted Bulma upgrade **1→2**. The user also reports that Bulma cannot be sold, invalidating the previous placement-test instructions. The test already supports a saved target profile in a fresh matching stage: record Bulma, save settings, enter the same stage fresh, load the script, read match data, start waves and test one placement into the saved empty position. See [the exact steps](TESTING.md#placement-with-an-unsellable-unit-v606).

Updated help/blocker text and documented the existing save/restore path. No mutation behavior or new selling endpoint is added. A regression exercises the restored profile in a fresh matching run and rejects a different stage. Placement and complete farming still require live verification.

## Development

```bash
python3 scripts/build.py
python3 scripts/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Tests cover pure state transitions and mocked observer/transport behavior. They cannot establish live server acceptance or device performance. See [validation](docs/VALIDATION.md).
