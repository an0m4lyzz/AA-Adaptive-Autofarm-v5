# Native adaptation — v7.0.0

The user's Zeno screenshots show a working interface in Sky Aircraft Dungeon Room, depth8/wave8, five equipped slots at their listed placement caps, Idol0/1 with a generic retry label, and an expensive Bulby upgrade waiting for cash. They do not prove automated clears, the cause of Idol's refusal or a Rukia drop.

All ten source menus were reviewed at [Zeno commit5a3f913](https://github.com/tfooio/zeno-hub-dist/tree/5a3f913c937159078df5c08099ca5f37c58229c1). See [the complete source/menu audit](ZENO-MENU-AUDIT.md). This repository contains original implementations using observed interfaces; no third-party hub, UI library or source file is loaded by this implementation. No service initializer/getter is explicitly invoked, and no hook or GC scan is installed. Reported-loaded native require still has the executor cache-isolation limitation documented in CLIENT-CACHE.md. Zeno must be closed; its presence blocks native mutations.

## What v7 adds

| Feature | Native behavior | Evidence / limit |
|---|---|---|
| One Smart Auto panel | Read data, apply clear-first setup, start/stop; older tests hidden under Advanced | Implemented; mobile layout still needs live confirmation |
| Automatic placement | Equipped UUID/ID, observed price/cap, actual LANES, first supported ground/hill hit and bounded overlap queries | Offline tested; heuristic positions, not a best-spot guarantee |
| Role-aware space | Reserve support first; income units use the observed team's planning footprint for their search | Does not change actual range/stat values |
| Combat priorities | Balanced opening; one farm while saving for combat; lowest-level or cheapest upgrade; optional target-first | Exact new-model/+1level/priority readback; unknown stats/caps/geometry stop |
| Modes | Manual-entry Story, Infinite, Challenge, Raid, Legend, Portal and Dungeon combat | Requires observed supported mode; no Event/card adapter or paid-mode auto entry |
| Story flow | Opt-in start vote, free confirmed replay, known next Story and return to lobby | Victory, actual identity changes and original limits required |
| Existing Dungeon run | Safe or reward room priorities, shrine skipping, explicit bounded shop spending, explicit final chests | No new Dungeon start or automatic key use; defeat stops |
| Teleport following | User-enabled fixed self-loader, same account/universe, expiry and durable revocation | Executor queue/file support required; ordinary loads stay unarmed |
| Authorized continuation | Only a requested replay/next-stage/next-room transition can resume automatic combat | Exact destination, consumed permission, original time/run/shop limits; unresolved combat never resumes |

## Implementation choices

The new runtime is the sole active mutation controller and reuses the serialized native transport. Native Auto, recorded-team, legacy Rukia and single-action controllers cannot be armed together. A true or nil RPC response alone confirms no action. Missing own-tower identity or position makes the whole battlefield observation incomplete.

The native lane reader inspects at most8 lanes with96 nodes each. Geometry queries use up to96 candidates per missing equipped slot, six slots, at most24 total proposed targets, cooperative yields and no geometry cloning. It uses base definition range as source-labeled planning metadata, not as the unit's actual rolled combat stat. The entry loop reobserves native round identity after planning yields. No known legal position means a specific blocker, not an endless retry or fabricated coordinate.

The explicit client-cache reader also checks existing DungeonServiceClient, DungeonServiceCore and ProgressionServiceCore cache entries. It can inspect up to32 upvalues each of existing Loader.init, load_client_service and load_core_service closures; it invokes none of those functions. Static Units is still required only when reported already loaded. Native cache/environment isolation remains an executor limitation. Opted-in continuation authorizes one cache connection in the destination, with a bounded readiness window, rather than startup introspection for every ordinary load.

Dungeon shop quotes use a directly exposed currentCost when available. When a positive coin budget is enabled, an already-loaded DungeonServiceCore.sum_item_values calculation may supply its shop-price modifier once per observed shop state. Missing/error/invalid calculation leaves price unknown. Exact debit plus +1matching item confirms a purchase; spending is capped across an authorized teleport continuation. Shops default to0 spending. Shrines are skipped. Final chests require their separate session switch; intermediate chest rooms keep stored chests. Unknown phases and delayed outcomes stop or wait within bounded deadlines.

## Persistence and permissions

Ordinary settings restore preferences such as upgrade method, next-stage/start-wave checkboxes and the shop coin cap. They do not arm an engine. Dungeon arm/chest consent, route/protocol confirmation and free-replay acknowledgement reset on ordinary injection. The START button applies the displayed preferences to a new explicit session. Teleport-follow permission is separate from settings, account/universe bound and expires after at most7200seconds.

The follow marker is `K_AA_Rukia_v6_Follow_<UserId>.json`. Queued code can only fetch this repository's existing main.lua. It reads and validates the marker again before executing; arbitrary URLs/code are never loaded from JSON. Only an attested new-job queued replacement preserves existing permission. Manual reload/close disarms/revokes; minimize keeps the observer. Runtime controls retain in-memory uncertainty locks in the same server. Known old-job locks cannot block a verified different server; unknown/same-job locks remain protected.

No native request can be cancelled after it was sent. If a durable file write/revocation fails, the UI/report explicitly says queued reload may remain possible; this must not be described as guaranteed cancellation. If the executor lacks queue/file capabilities, following is unavailable and current-server testing remains possible.

## Features deliberately unavailable in v7

Starting a new key-consuming Dungeon, automatic general lobby joining, Infinity Mansion entry, event modifier/card choices, abilities/spells/buff rotations, selling units, trait/stat rerolls, evolution, summons, capsules and material purchases do not have a current verified price/receipt adapter here. Their source/menu evidence and prerequisites are recorded in ZENO-MENU-AUDIT.md. Webhooks and listener suppression are also not imported. Public source availability does not verify Rukia's current reward table, drop rate, recipe or any perfect build.

Use [TESTING.md](../TESTING.md). Local checks do not establish actual Android latency, FPS, server acceptance, clear rates or successful Rukia progression.


## Review and offline evidence

One fresh whole-change review found four Important gaps, no Critical gaps. Regression fixes bind queue registration to the actual job, require exact active native Dungeon depth/choice for continuation, wait for delayed post-Victory phases/forward offers without re-entering the completed room, and mark missing own-tower identity/position incomplete. All were reproduced before correction. Entry integration also verifies actual source wiring, before-RPC checkpoints, exact acknowledgements, setting/close cancellation, new-job replacement, matching/mismatched continuation budgets and silent-write failure. A durable write now requires exact local readback.

397 tests pass: adapter76, automatic combat35, core45, Dungeon44, actual entry integration10, inventory21, navigation19, placement20, runtime41, session29, recorded team30 and single-action27. Active source/main compilation, reproducible bundle, unchanged loader, API restrictions and whitespace checks pass. No v7 live game run was performed here.
