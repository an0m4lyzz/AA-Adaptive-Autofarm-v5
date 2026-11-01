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
| Inventory, traits, stats, material counts | Experimental observer | Direct player-replicated Instances; missing data stays unknown. Partial scans never prove absence. |
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

## Development

```bash
python3 scripts/build.py
python3 scripts/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Tests cover pure state transitions and mocked observer/transport behavior. They cannot establish live server acceptance or device performance. See [validation](docs/VALIDATION.md).
