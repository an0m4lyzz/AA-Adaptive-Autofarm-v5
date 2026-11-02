# [K] Anime Adventures — Rukia progression v7

**v7.0.0: native Smart Auto, existing-run Dungeon flow and opt-in teleport following. Offline tested; new Roblox/Delta behavior remains EXPERIMENTAL. Complete Rukia progression is not live verified.**

The [complete hub master plan](docs/superpowers/specs/2026-11-02-complete-hub-design.md) accounts for the full reference menu and Rukia workflow, with an [implementation checklist](docs/superpowers/plans/2026-11-02-complete-hub.md). These documents describe future work; the runtime remains v7.0.0.

The official experience now displays Update 21 (checked November 1, 2026, Manila date). Current Rukia availability, recipe, rates and protocols could not be verified. Read the [research and progression plan](docs/RUKIA-RESEARCH.md), [audit](docs/AUDIT.md) and [testing guide](TESTING.md).

## Unchanged entry point

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua"))()
```

main.lua bundles local src modules and uses no external GUI library or Zeno runtime. Explicit teleport following queues only this same entrypoint. Old v5 source and instructions are archived intact in legacy/ and are not loaded. Existing v5 settings remain untouched; the compatible upgrade preference migrates on the first v6 load. Old macros need re-recording.

## Current features

| Feature | Status / boundary |
|---|---|
| Smart Auto placement/upgrades | Experimental native implementation; observed LANES/terrain, equipped identities/caps/prices and exact readback |
| Target priority / opening | Optional target-first, balanced opening, support-space reservation, lowest-level or cheapest upgrades; heuristics, not proven optimal |
| Manual-entry combat modes | Story, Infinite, Challenge, Raid, Legend, Portal, Dungeon when mode/data are supported |
| Story transitions | Opt-in typed start voting, confirmed free replay, verified known next Story and lobby return; caps apply |
| Existing Dungeon run | Experimental safe/reward room priorities, shrine skipping, known-price capped shops and explicit final chests |
| GUI after teleport | Opt-in queue/file-based following; account/universe bound, expiring and revocable |
| Automatic continuation | Only a requested, verified destination can resume within original limits; not an arbitrary new stage |
| Rukia/inventory/build checklist | Existing experimental observations; historical recipe/trait guidance remains labeled |
| New Dungeon keys / premium mutations | Unavailable; no automatic new-run entry, summons, rerolls, evolution or material purchases |
| Event cards / abilities / general lobby joiners | Unavailable until native behavior and readback are established |

The [full Zeno menu audit](docs/ZENO-MENU-AUDIT.md) covers every source menu. [Adaptation details](docs/ZENO-ADAPTATION.md) distinguish implementation, evidence and remaining limits. This is original code using referenced interfaces, not a copied or automatically loaded hub.

## First v7 test

1. Restart Roblox so Zeno and its queued reload are gone. Remove Zeno autoexec if you installed it. Run only this project's unchanged loadstring; confirm **7.0.0**.
2. In FARM tap **READ GAME DATA + COPY REPORT**, then **APPLY CLEAR-FIRST SETUP**. Compare observed equipped slots and costs with the game.
3. Enable **KEEP UI + AUTHORIZED AUTO AFTER TELEPORT** if desired. Queue and file support must succeed; this does not arm combat yet.
4. Enter a free Story stage or an already-started Dungeon manually. Read game data inside that match if not connected, then tap **START SMART AUTO**. No manual placement profile is required.
5. For Dungeon, grant **ALLOW OPENING FINAL DUNGEON CHESTS** before arming if desired. Shop budget defaults 0; new key-consuming starts always remain manual. A settings change pauses Auto, so set options before START.
6. Supervise the first run. On a result/blocker use **COPY SMART AUTO REPORT**. Defeat, unknown results, incomplete observations and unconfirmed actions stop; there is no blind retry.

Clear-first setup uses a single run and replay OFF. For repeated Story clears, open Advanced, confirm the exact stage replay is free, enable replay and set a finite run cap in Settings. NEXT STORY requires an exposed next-level identity and the same run cap. Arbitrary manual stage changes reload the UI but do not automatically authorize spending.

## Mobile and spending protections

No startup hooks, GC enumeration, full PlayerGui scans, third-party source loads or speculative remote loops. One 0.8-second observer, inventory every 4 seconds, bounded lane/geometry/phase reads, tracked listeners and one mutation in flight. Reports/logs remain bounded. Presence of Zeno blocks native mutations.

Exact server-observable tower/level/priority/room/resource changes confirm actions; RPC true does not. A same-server unresolved action stays fenced across replacement, and a real round reset is required to release uncertainty. Following is explicitly enabled, has a maximum 7200-second permission window and preserves original time/run/shop limits across authorized transitions. Close revokes queued continuation; a failed durable write is reported as uncertainty. Already-sent requests cannot be cancelled.

Preferences save locally, but ordinary injection never arms an engine. [TESTING.md](TESTING.md) explains current evidence and [VALIDATION.md](docs/VALIDATION.md) records offline checks. Android stability and complete Rukia farming remain unverified.

## Earlier v6 releases

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

### v6.0.7: terrain projection and request feedback

The failed live placement had correct exposed inventory/cash and no observed own tower. Its report omitted the actual RPC return, game warning and saved/sent coordinates, so it cannot establish a server rejection reason. Code comparison found that the recorder stores the hitbox centre while the referenced placement implementation sends the observed terrain surface. This is a supported hypothesis for the timeout, not a live-verified cause.

Before each placement, one vertical Include-only raycast resolves the saved X/Z against observed _terrain. The first hit must belong to ground/hill and agree with the loaded unit flags. Missing/blocked/truncated ancestry and conflicting height stop the request. A conservative three-stud downward projection window prevents selecting distant floors; it is a support limit, never a placement offset. No hardcoded surface height, coordinate search or retry is used. Existing model-centre coordinates remain the readback target.

Reports retain sanitized first/second RPC returns, recorded/sent/surface coordinates and up to four show_message events during an eight-second mutation window. The optional exact event listener is created only for an action and disconnected on expiry, replacement or close. Messages are time-correlated observations, not proof that every warning belongs to the request. A true/nil return alone never confirms a placement. No hook, startup listener, premium endpoint or broad GUI traversal is added.

## Development

```bash
python3 scripts/build.py
python3 scripts/check.py --luau /path/to/luau --compiler /path/to/luau-compile
```

Tests cover pure state transitions and mocked observer/transport behavior. They cannot establish live server acceptance or device performance. See [validation](docs/VALIDATION.md).
