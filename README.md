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

1. Execute once in the lobby; leave Full Auto OFF.
2. Refresh exposed inventory and inspect RUKIA / REPORTS. Missing UUIDs or values are blockers.
3. Manually check the current Dungeon rewards and Evolve recipe before using a key.
4. Follow [TESTING.md](TESTING.md) before attempting recorded combat.

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

## Development

```bash
python3 scripts/build.py
python3 scripts/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Tests cover pure state transitions and mocked observer/transport behavior. They cannot establish live server acceptance or device performance. See [validation](docs/VALIDATION.md).
