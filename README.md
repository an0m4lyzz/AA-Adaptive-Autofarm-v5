# Anime Adventures Adaptive Autofarm v5 (Experimental)

An experimental **mobile-friendly Roblox Lua script** targeting Anime Adventures with Delta. This project is **not affiliated with Roblox or the Anime Adventures developers**.

## Delta loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/an0m4lyzz/AA-Adaptive-Autofarm-v5/main/main.lua"))()
```

## Intended features

- Scans available equipped and owned units to recommend a team for the map.
- Observes enemy types and potential counters, including air, shields, regeneration and bosses.
- Estimates suitable placements, upgrade priorities and map threat history.
- Offers a touch-friendly configuration UI and diagnostic reports.
- Includes experimental event queue learning, card recommendations and replay support.

## Getting started

1. Join Anime Adventures on a mobile device and open Delta.
2. Execute the loadstring above.
3. In an easy Story stage, scan your equipped units and generate a team recommendation.
4. Observe the first placements and upgrades with the autofarm enabled.
5. Use the **COPY MAP / BOSSES / TEAM COUNTERS** button to capture diagnostics if anything fails.

## Limitations and safety

- **Not live-tested** in the current Anime Adventures build or on Delta.
- **Do not assume all modes are fully autonomous.** Certain event tower offers, spells, dungeon branches, matchmaking and card voting still need in-game verification.
- Automatic equipping is **off by default** until an actual equip action is learned and verified.
- Enemy/boss intelligence is restricted to client-visible or previously observed information; unseen future waves cannot be guaranteed.
- A Lua syntax check alone does not confirm game compatibility or successful runs.
- Using an executor can violate Roblox/game rules and may result in account action. Use at your own risk.
- Review remotely loaded code before execution, as changes to `main.lua` can change what the loadstring executes.

## Files

- `main.lua`: autofarm Lua source.
- `loadstring.txt`: one-line loader for easy copying.
- `TESTING.md`: mobile testing checklist and troubleshooting.

Created to be tested incrementally; this is not a guaranteed perfect-run script.
