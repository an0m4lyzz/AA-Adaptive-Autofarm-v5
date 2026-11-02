# Native automatic play and Dungeon adaptation

The user explicitly wants Zeno-like features inside this project, one simple UI, automatic combat and Dungeon navigation, and persistence across Story/lobby teleports. Zeno must not run alongside this implementation. Current baseline is main 335eb63396633bcd26eb8c6a3c000653e1279d7c (202 offline tests). Source reference: tfooio/zeno-hub-dist 5a3f913c937159078df5c08099ca5f37c58229c1. Implement original code from observed interfaces; do not vendor or run that source.

Approaches considered: an external-engine bridge would retain two scripts and was superseded by the user's clarification; wholesale copying would retain mobile/global-hook hazards; native bounded implementations reuse this project's transport/readback/cleanup and are the implementation choice under the user's existing autonomous authorization.

## Behavior and boundaries

- Add automatic play in observed Story, Infinite, Challenge, Raid, Legend, Portal and Dungeon contexts, using actual equipped UUIDs/prices/caps and observed _BASES.pve.LANES plus first supported terrain hits. No fixed map coordinates or fake path. Current readback is exact new UUID/ID/model position within 3 studs, never RPC true alone.
- Balanced opening, one farm while saving for combat, at most24 targets, configurable lowest-level/cheapest upgrades, known maximum distinct from absent price. Slot failures stop with an exact blocker; no silent success. Native target changes/abilities can remain unavailable unless readback is established.
- Dungeon supports an already-started run: safe/reward room preferences, skip shrines, optional bounded shop spending with known price, explicit end-chest opening, confirmed outcome/room transitions. Starting new key-consuming runs remains unavailable without a current verified key cost; no dungeon_start endpoint is exposed.
- Explicit cache connection reads existing named DungeonServiceClient and DungeonServiceCore exports from Loader closure registries; no service initialization/getter calls, hooks or GC scans. Unknown schema stops.
- Teleport following is opt-in, user/account/universe bound, expiring and revocable. Only this project's existing entrypoint is queued. GUI may reload on changed Story/lobby; automatic continuation requires an explicitly armed session and matching expected transition. In-flight unresolved combat actions never resume after reload.
- One mutation controller/transport only. Zeno presence blocks native mutation. Close/settings changes cancel arming and revoke continuation; cannot cancel an already-sent server call.
- All automation/consents default OFF; preserve settings/loadstring and legacy tests. Native automatic play and Dungeon flow remain experimental until live tested; no new proof of Rukia availability, optimal strategy or successful clears is claimed.

## Module interfaces

src/autoplay.lua: factory(C,cfg,log), controller arm(s),tick(s),stop(reason),reject(reason),text(s). Snapshot uses existing observer fields plus roster unit spawnCap, role, cost; s.autoSpots[uuid] list of observed {pos={x,y,z}}. Emits existing place/upgrade actions; exact confirmation counters placements/upgrades. No native APIs. s.externalControllerActive blocks arming/ticking. Dynamic stage change disarms except orchestration explicitly arms a verified new round.

src/navigation.lua: factory(C,WS,RS,log) returns :plan(s,definitions,cfg) -> spotsByUuid or nil,reason; :close(). Read only actual LANES parts (max8 lanes/max96 nodes each); max96 candidate rays per slot/max6 slots, cooperative yields. First terrain hit class, loaded ground/hill rules and bounded road/unit overlap checks; never bypass server placement limits or clone an unbounded tree. Cache only same stage/native round, reject truncated observation. Candidates deterministic; rankings are heuristic, not best-position claims.

src/dungeon.lua: factory(C) returns D.snapshot(service,core,level) -> normalized copied snapshot and D.engine(cfg,log). Engine arm(s),tick(s),stop(reason),reject(reason),text(s). s.dungeon carries valid, started, dead, finished, depth, choice, lives, money, normalChests, rareChests, phase={kind,token,offers}, rooms, observed source. Never invoke getters in parser. Actions kind='dungeon' name in allowlist dungeon_enter_room, dungeon_continue_shop, dungeon_buy_shop, dungeon_open_chest (never start/shrine_accept), args array, expected typed readback. Pending confirmation advances confirmations counter. Timeout8s and no automatic retry; enter transition wait20s. Default shop cap0 and chest permissionfalse. Death/defeat stops; positive exact collection Rukia stops.

src/session.lua: dependency-injected factory(C,io,env,identity,clock), where io JSON read/write and queue(code) are injected by entry. Methods follow(enabled),checkpoint(state),load(),revoke(reason),close(); queue only fixed own loader. Marker includes schema,userId,universeId,expires,nonce,follow,armed,expected,inFlight. Expiry max7200s, actual user/universe match, durable revocation, previous inFlight combat blocks resumption, generated code validates marker before loading. UI-only follow may persist without armed automation. No third-party URL.

Root owns src/roblox.lua native plumbing, src/core.lua settings, src/entry.lua orchestration, src/ui.lua controls, bundler/checker, docs. Keep source parser and transport tests. Review new shared native feedback fences and the restart/transition boundary before publication.


## User scope expansion and integration rulings

The user requested the full menu be learned and useful features improved. The complete menu audit is docs/ZENO-MENU-AUDIT.md; it distinguishes available native implementation from unsupported features. Pure combat now also permits manual-entry Infinite/Challenge/Raid/Legend/Portal with verified native data; Event/cards and automatic entry into paid modes remain unavailable. Exact observed target-first changes are opt-in, with typed priority readback. Known next-Story identity may come from an already-loaded ProgressionServiceCore export; only actual Story, explicit permission, run/time caps and exact expected next stage can authorize next_story. Automatic replay remains Story-only in the new runtime.

The implementation follows executing-plans for root integration with dispatching-parallel-agents for independent owned modules. The user's autonomous scope/anti-confirmation instructions remain in force; no workflow question is required. A single fresh whole-change reviewer will review all source/tests/integration before atomic publication.

Native geometry now reserves support first and uses the observed combat footprint as an income unit's search radius, without overwriting any unit stat. Exact feedback and budgets remain authoritative. Root retries no mutation blindly. A genuine queued new-job replacement preserves explicit follow permission, while ordinary close/reload revokes it; known old-job network/cache locks cannot block a different verified server. Manual settings changes save locally, ordinary settings never restore action consent.
