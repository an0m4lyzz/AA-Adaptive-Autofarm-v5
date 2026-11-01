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


## New: in-game card advice and big rewards (experimental)

The **card controls are at the top of the mobile menu**, immediately after MODE.

1. Keep **MODE: Event** and **START FULL AUTO: OFF** if you want to play Fool's Hunt normally.
2. Keep **CARD ADVISOR: ON** (default). When card choices are visible, a floating green **PICK:** banner recommends a card, even if the menu is minimized.
3. **AUTO CHOOSE BEST CARD** is OFF by default. Turn it ON if you want the script to try clicking a high-confidence card recommendation. It works independently of placement/upgrade autofarming.
4. **CARD STRATEGY** cycles SAFE CLEAR, BALANCED, BIG REWARDS. **SET BIG REWARDS (APRILCOINS)** is a one-tap shortcut.

**Big Rewards** assigns greater weight to visible AprilCoins bonuses; when several cards give the same bonus, it tends to prefer the lower-risk curse. It does **not** guarantee more currency, a clear, or the optimal choice. Aggressive curses can end a run sooner.

**Limitations:** The card detection is based on client-visible GUI labels, and clicking depends on what Delta supports. Auto-clicking is attempted only for a limited number of readable choices with a scoring margin; close calls, high-risk options and target-specific spells are left for manual selection. A reported input attempt is not server confirmation. Verify behavior in a supervised run before relying on it.

## New in v5.1: automatic run reports

You **do not need to start the autofarm** to record a normal Event run.

- **AUTO-LOG RUN** is ON by default. The script records map/mode and equipped units at the start, unit/upgrade snapshots every 5 waves, first sightings of bosses and enemy traits, visible modifier-card choices, and the result screen when detected.
- **AUTO-COPY CARDS / BOSSES / END** is ON by default. A cumulative report is automatically copied to the clipboard when cards appear, bosses are seen, or a run ends. The clipboard holds only the latest copy, so avoid overwriting it before pasting.
- If Delta supports \`writefile\` or \`appendfile\`, it also stores a persistent text file called \`K_AA_AutoReport_<your-user-id>_<place-id>.txt\` in the executor workspace.
- **COPY COMPLETE AUTO REPORT** can be used at any time to recover the current in-memory report. **SHOW AUTO REPORT STATUS** reveals whether local saving succeeded.
- If a match ends via a teleport before the end screen is visible, the last collected file may be incomplete. Some event cards may not be detectable from the client GUI. Recording is best-effort and has not yet been live-tested.

For a safe first test, **leave START FULL AUTO OFF**, set MODE to Event, and play normally. The recorder makes observations without trying to place units, buy upgrades, select cards, or join the next event.

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
