# Audit and behavior changes

Base: be96b3deb80544af4d5bf19fda2c46bd5a768047. Read main.lua, README, TESTING, tree and recent goal-farm/mobile hotfix changes before implementation.

Source-level findings:

- Placement fallback counted any own-tower increase, including unrelated manual placements.
- The latest startup hook hotfix existed, but generic/empty-roster paths could still trigger GC snapshots.
- Card detection still traversed all PlayerGui descendants.
- Many remote workers could overlap; InvokeServer lacked a deadline.
- Input listeners were not fully tracked; each drag added a connection.
- Finished flags could produce “completed run” reports without confirmed Victory.
- Random offered units, missing enemy paths and current schemas remained unresolved.

No device crash dump was available. These hazards do not establish the exact native crash cause.

The new source splits pure logic, native observation/transport, UI and entry into src/ and bundles the original main.lua. v5 and its instructions are preserved byte-for-byte in legacy/. Historical stat/identity aliases, path observation concept and endpoint candidates remain source-labeled.

**Behavior change:** old card clicking/advice, queue/equip hooks and generic coordinate sampling are not active in v6. Their source remains archived. Existing v5 settings are untouched; old macro coordinates are never silently certified. Only the compatible upgrade preference migrates once.

Stage identity is invalidated on observed map/config/wave/started/finished lifecycle changes. Incomplete tower observation blocks all mutation. Placements require a genuinely new own model, exact UUID/ID and position; upgrades require level feedback. Confirmations are scoped to observed stage/mode/place. One global pending request survives replacement until completion.

No unseen client-table schema is guessed. If direct player-replicated inventory is unavailable, roster, stats and automation remain unknown/blocked.
