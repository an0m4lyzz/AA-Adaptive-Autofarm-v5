# Manual client-cache reader — v6.0.4

The user's v6.0.2 report confirms lobby detection, numeric account balances, ReplicatedStorage/src/Loader and opaque numeric client modules. It does not expose an owned/equipped inventory through the four Instance paths. More folder-name traversal cannot establish the collection schema.

The subsequent **v6.0.3 live report recognizes 77 units, six equipped slots, two reroll tokens and fruit counts** through Loader.init.upvalue#12.ItemInventoryServiceClient. This is evidence that this cache shape works in the reported session, not that the inventory is complete, server-fresh or enough for combat. The next test is a free Story match, not another lobby tree scan.

The **v6.0.4 match report** now observes Loader.LevelData stage namek_level_1, Story mode, match cash 400 from resource, Units definitions with cost scale 1 and the exact equipped Bulma tower with position, upgrade 0 and next quote 1,500. Read-only combat observation is demonstrated for that session; actual place/upgrade requests still require the separate v6.0.5 single-action test in TESTING.md.

## Approach and evidence

Historical primary code references show two relevant patterns:

- [Original buff source](https://github.com/annguyen2311/andeptrai/blob/a2f43d6f429a241f558dda2d1b777d7bffecb4ad/buff): ItemInventoryServiceClient session collection, UUID-keyed owned_units, equipped_units.
- [kaitunAA source](https://github.com/TrilhaX/scriptexec/blob/97387f51e572c38dcf058451fe6752807b414446/Testes/kaitunAA.lua): Loader.init closure cache, StatsServiceClient.module.session, normal_items and profile_data.trait_reroll_tokens.
- [Autoplay source](https://github.com/tfooio/zeno-hub-dist/blob/5a3f913c937159078df5c08099ca5f37c58229c1/src/autoplay.lua): GUIService collection shape and traits entries.

These are historical/community-authored source observations, not official game documentation or Update 21 certification. No external source file is executed, imported or downloaded by the runtime. The implementation is new, bounded and read-only with respect to exported tables.

An explicit RUKIA button attempts one loaded-module snapshot. The exact Loader must be present. Its export is retrieved once; only the upvalues of existing init and load_client_service functions are inspected. Those functions are never invoked. At most 32 upvalues per function are examined. Named cached service entries are checked structurally; there is no fixed upvalue index and no getter fallback. No arbitrary numeric modules, remotes, hooks, GC enumeration or currency actions are invoked by this reader.

v6.0.4 also retains that Loader export to read its current LevelData without invoking load_data. The exact observed src/Data/Units ModuleScript is retrieved only if the same bounded loaded-module list includes it. Only raw definitions for equipped/observed IDs are read. If static Units loads later, one additional manual reader action is permitted; it reuses Loader rather than requiring it again. Introspection is never added to the polling loop.

The [primary Game implementation](https://github.com/tfooio/zeno-hub-dist/blob/5a3f913c937159078df5c08099ca5f37c58229c1/src/game.lua) reads Loader.LevelData and player/_stats/resource for match state. Its companion [autoplay implementation](https://github.com/tfooio/zeno-hub-dist/blob/5a3f913c937159078df5c08099ca5f37c58229c1/src/autoplay.lua) reads Units[id].cost, upgrade[level+1].cost, and _DATA/LevelModifiers/player_cost_scale. These are community primary source observations, not live Update 21 verification. This controller requires an explicit finite positive scale before deriving effective costs; it does not use the reference's default-to-1 fallback. Static stats are not substituted for this account's actual unit stats.

The pure parser validates the supported collection shape, exposed owner IDs and every present UUID alias. Conflicting numeric/string slot aliases are rejected. Equipment is read first, then at most 400 additional owned entries. Parsing copies only whitelisted fields and never writes into game tables. Missing resources remain unknown; actual zero stays zero. Potential fields are unclassified and never used as attack stats or grade evidence. Two-trait targets are preserved in the goal/budget policy.

After connecting, four-second refreshes follow the current entry inside the retained cache registry. Entry removal or schema failure clears observations. Native cache inspection is not repeated. A placed tower by itself cannot prove permanent unit acquisition.

## Native limits

[Roblox ModuleScript documentation](https://create.roblox.com/docs/reference/engine/classes/ModuleScript) describes caching per Luau environment. [sUNC getloadedmodules documentation](https://docs.sunc.io/Scripts/getloadedmodules/) describes a list of completed loaded modules. These do not establish how Delta shares the game's cache. Native require may execute Loader or Units code in a different environment despite a reported loaded status. The reader is therefore manual and experimental.

An eight-second global pending guard prevents overlapping requests and rejects late results. It cannot preempt a blocking native API or undo code executed inside require. Closing prevents late results from updating the old instance; a pending lock is retained until return. Unsupported APIs, missing loaded status and unsupported schemas are reported without another initialization attempt.

Observation time is not server freshness. Following a retained registry entry does not prove that Loader has not replaced its entire registry. Actual Android memory/latency, executor API behavior and current inventory semantics still need live comparison against Collection. Full Auto stays OFF; successful cache parsing does not establish placement, costs, dungeon progression or premium transaction compatibility.

## Test

For a new inventory failure, open Collection once and tap **RUKIA → READ CLIENT CACHE + COPY REPORT**. For the already connected v6.0.3 inventory, move to the free match test in TESTING.md and use **FARM → READ MATCH DATA + COPY COMBAT REPORT**. Compare observations with the game before arming combat. Repeated metadata scans are unnecessary.
