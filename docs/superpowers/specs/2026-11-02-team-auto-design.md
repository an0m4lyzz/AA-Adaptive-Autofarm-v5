# Recorded team Story controller

## Intent and evidence

The user requested automatic placement and upgrading for all equipped units after the single-action tests. The v6.0.7 report observes a unique Bulma spawn, RPC true, cash 900→100, and recorded centre Y93.086 projected to observed ground Y91.806. Earlier reports observe exact scripted upgrades. This supports building team orchestration; it does not prove other units, victory/replay or unattended Rukia progression.

## Approach

Use recorded positions and current exposed costs/identities. Automatic map-generated positions would require unverified path/collision planning; the existing Rukia engine also requires an unverified reward-route confirmation. Add a separate pure Team controller, retaining those Rukia gates. This is the implementation choice for the already authorized full-team request.

## Behavior

- Story only, observed stage/mode, fresh equipped records, complete bounded tower observation, matching recorded context and prices.
- Capture current exact equipped towers; merge partial captures for the same stage and unchanged cost scale, replace newly captured UUID groups, drop unequipped identities. Auto-save plain JSON after explicit record. No model Instances in saved profiles.
- All current equipped slots require at least one recorded position before arming. Up to 24 placements. Summoned helper IDs do not become controllable equipped units. Missing/ambiguous records block.
- Balanced opening: an affordable recorded combat unit first; otherwise one affordable farm while saving for combat. Once combat exists, fill the remaining recorded team, using actual affordability. Unknown roles use deterministic affordable order without an optimality claim.
- Place all recorded targets before upgrading; upgrades choose the lowest observed upgrade level, then cheapest affordable price. Preserve Yen reserve. Known max-upgrade state is distinct from missing price data.
- One request/readback at a time, 1.5-second action spacing, eight-second exact feedback deadline, no blind retries. Existing units are matched, never counted as automated actions. Unknown/ambiguous results stop.
- Team max runs/session duration use existing settings. Replay remains OFF by default and requires scoped explicit no-item-cost confirmation plus observed Story victory. Never Dungeon/Portal/key/chest automation.
- An optional exact game_finished event listener starts only when Team Auto is explicitly armed; only raw boolean victory plus the current run's finished marker can supplement UI results. Contradictions stay unknown. Disconnect on stop/close.
- Team/trial/Rukia controllers are mutually exclusive. Settings/profile changes disarm. Stopping with an unresolved request prevents same-run rearming. No saved state arms a controller.

## Interface and limits

FARM gains RECORD + SAVE TEAM POSITIONS, CHECK TEAM, START/STOP TEAM AUTO, and COPY TEAM REPORT, with coverage and missing slots. Other tabs and the original loadstring/settings remain compatible. Rukia route status stays truthful. Team placement/upgrading and replay remain experimental until supervised live runs succeed.
